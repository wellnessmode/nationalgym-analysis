import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../core/tokens.dart';
import '../../../services/supabase_client.dart';
import '../../../shared/providers/auth_provider.dart';

/// 고품질 음성 녹음 + Gemini 전사 패널.
///
/// 흐름:
///   1. '녹음 시작' → MediaRecorder (브라우저 AGC / 노이즈 억제 / echo cancel 활성)
///   2. '정지' → blob 받아 Supabase Storage 'recordings' 버킷에 업로드
///   3. Edge Function transcribe-audio (Gemini 1.5 Flash audio) 호출
///   4. 전사 결과를 [onTranscriptChunk] 콜백으로 전달 (부모가 본문에 append)
///
/// 시작 효과음 없음 (Web Speech API 미사용).
class AudioRecorderPanel extends ConsumerStatefulWidget {
  /// 한 세션의 전사 결과 (이 회차에 새로 전사된 텍스트만). 부모가 본문에 append.
  final void Function(String chunk) onTranscriptChunk;
  final bool disabled;
  final String idleTitle;
  final String idleSubtitle;
  final VoidCallback? onClose;

  const AudioRecorderPanel({
    super.key,
    required this.onTranscriptChunk,
    this.disabled = false,
    this.idleTitle = '음성 녹음',
    this.idleSubtitle = '버튼을 누르고 말씀하면 녹음 후 자동 전사됩니다',
    this.onClose,
  });

  @override
  ConsumerState<AudioRecorderPanel> createState() => _AudioRecorderPanelState();
}

class _AudioRecorderPanelState extends ConsumerState<AudioRecorderPanel> {
  final _recorder = AudioRecorder();
  bool _listening = false;
  bool _transcribing = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  int _sessionCount = 0; // 성공한 전사 횟수 — UI 라벨용
  String? _error;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.disabled || _listening || _transcribing) return;
    setState(() => _error = null);
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        setState(() => _error = '마이크 권한을 허용해주세요');
        return;
      }
      // 가까이 안 있어도 인식되도록 브라우저 오디오 처리 적극 활성화.
      // 결과: 자동 게인 / 노이즈 억제 / 에코 캔슬 ON.
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.opus,
          bitRate: 96000,
          sampleRate: 48000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: 'recording.webm',
      );
      setState(() {
        _listening = true;
        _elapsed = Duration.zero;
      });
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      setState(() => _error = '녹음 시작 실패: $e');
    }
  }

  Future<void> _stop() async {
    if (!_listening) return;
    _ticker?.cancel();
    setState(() => _listening = false);

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (path == null) {
      setState(() => _error = '녹음 데이터를 받지 못했어요');
      return;
    }

    // 웹: path 가 blob URL. 바이트 받아오기.
    Uint8List? bytes;
    try {
      if (kIsWeb || path.startsWith('blob:')) {
        final res = await http.get(Uri.parse(path));
        bytes = res.bodyBytes;
      } else {
        // 모바일 네이티브 경로 케이스 — 지금은 미지원
        setState(() => _error = '이 플랫폼에선 아직 미지원');
        return;
      }
    } catch (e) {
      setState(() => _error = '데이터 수집 실패: $e');
      return;
    }
    if (bytes.isEmpty) {
      setState(() => _error = '녹음 길이가 너무 짧습니다');
      return;
    }

    await _uploadAndTranscribe(bytes);
  }

  Future<void> _uploadAndTranscribe(Uint8List bytes) async {
    setState(() => _transcribing = true);
    final me = ref.read(currentUserProvider).valueOrNull;
    final uploaderId = me?.id ?? 'anon';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'live/$uploaderId/$ts.webm';

    try {
      // 1) 업로드
      await supabase.storage
          .from('recordings')
          .uploadBinary(storagePath, bytes,
              fileOptions: const FileOptions(upsert: false, contentType: 'audio/webm'));

      // 2) Edge Function 호출 (Gemini 전사)
      final res = await supabase.functions.invoke(
        'transcribe-audio',
        body: {'storage_path': storagePath, 'mime_type': 'audio/webm'},
      );
      final data = res.data;
      if (data is! Map || data['ok'] != true) {
        final err = (data is Map ? data['error']?.toString() : null) ?? '전사 실패';
        setState(() => _error = err);
        return;
      }
      final text = (data['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) {
        setState(() => _error = '음성에서 인식된 내용이 없습니다');
        return;
      }

      // 3) 이번 회차의 텍스트만 부모에게 전달 (부모가 append 책임)
      _sessionCount++;
      widget.onTranscriptChunk(text);

      // 4) 보관 정책: storage 의 파일은 둠 (백업 + 감사용). 자동 삭제는 별도 정책.
    } catch (e) {
      setState(() => _error = '처리 실패: $e');
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<void> _reset() async {
    if (_listening) await _stop();
    setState(() {
      _sessionCount = 0;
      _elapsed = Duration.zero;
      _error = null;
    });
    // 부모 본문은 건드리지 않음 — 사용자가 직접 지울지 결정.
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Tokens.s14),
      decoration: BoxDecoration(
        color: _listening
            ? Tokens.danger.withOpacity(0.06)
            : (_transcribing ? Tokens.gold500.withOpacity(0.06) : Tokens.surfaceAlt),
        borderRadius: BorderRadius.circular(Tokens.r12),
        border: Border.all(
          color: _listening
              ? Tokens.danger.withOpacity(0.30)
              : (_transcribing ? Tokens.gold500.withOpacity(0.30) : Tokens.border),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _listening
                  ? Tokens.danger
                  : (_transcribing ? Tokens.gold600 : Tokens.navy900),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _listening
                  ? Icons.graphic_eq
                  : (_transcribing ? Icons.auto_awesome : Icons.mic),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: Tokens.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _listening
                    ? '녹음 중'
                    : (_transcribing ? '전사 처리 중...' : widget.idleTitle),
                style: Tokens.ts14.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _listening
                    ? _fmt(_elapsed)
                    : (_transcribing
                        ? 'Gemini 가 음성 분석 중'
                        : (_error != null ? _error! : widget.idleSubtitle)),
                style: Tokens.ts12.copyWith(
                  color: _listening
                      ? Tokens.danger
                      : (_transcribing
                          ? Tokens.gold600
                          : (_error != null ? Tokens.danger : Tokens.textMuted)),
                  fontWeight: (_listening || _transcribing)
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ]),
          ),
          if (_listening)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Tokens.danger, size: 28),
              tooltip: '정지',
              onPressed: _stop,
              enableFeedback: false,
            )
          else if (_sessionCount > 0)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: '초기화',
              onPressed: widget.disabled || _transcribing ? null : _reset,
              enableFeedback: false,
            ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: '음성 패널 닫기',
              onPressed: () async {
                if (_listening) await _stop();
                widget.onClose!();
              },
              enableFeedback: false,
            ),
        ]),
        const SizedBox(height: Tokens.s12),
        SizedBox(
          height: 44,
          child: !_listening
              ? FilledButton.icon(
                  onPressed: (widget.disabled || _transcribing) ? null : () {
                    HapticFeedback.lightImpact();
                    _start();
                  },
                  icon: _transcribing
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.mic, size: 18),
                  label: Text(_transcribing
                      ? '처리 중...'
                      : (_sessionCount == 0 ? '녹음 시작' : '이어서 녹음')),
                  style: FilledButton.styleFrom(
                    backgroundColor: Tokens.surface,
                    foregroundColor: Tokens.text,
                    side: const BorderSide(color: Tokens.borderStrong),
                    enableFeedback: false,
                  ),
                )
              : FilledButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('정지'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Tokens.danger,
                    enableFeedback: false,
                  ),
                ),
        ),
      ]),
    );
  }

}
