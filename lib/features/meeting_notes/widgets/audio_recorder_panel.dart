import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import '../../../core/tokens.dart';

/// 회의 음성 녹음 패널.
/// 녹음 시작/정지/취소. 정지 시 onRecorded(audioBytes, mimeType) 콜백.
class AudioRecorderPanel extends StatefulWidget {
  /// 녹음 완료 시 호출. 부모가 업로드·전사 처리.
  final Future<void> Function(List<int> audioBytes, String mimeType) onRecorded;

  /// 부모가 외부에서 비활성화 (저장 중 등)
  final bool disabled;

  const AudioRecorderPanel({super.key, required this.onRecorded, this.disabled = false});

  @override
  State<AudioRecorderPanel> createState() => _AudioRecorderPanelState();
}

class _AudioRecorderPanelState extends State<AudioRecorderPanel> {
  final _recorder = AudioRecorder();
  bool _recording = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  bool _processing = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.disabled || _processing) return;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _snack('마이크 권한이 거부되었습니다');
      return;
    }
    try {
      // Web: 결과는 메모리 또는 blob URL. record 5.x는 stream과 file 둘 다 지원.
      // 단순화 위해 임시 파일 경로(Web에선 blob URL) 사용.
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.opus,
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: 'recording.webm',
      );
      setState(() {
        _recording = true;
        _elapsed = Duration.zero;
      });
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      _snack('녹음 시작 실패: $e');
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    setState(() => _processing = true);
    _ticker?.cancel();
    try {
      final path = await _recorder.stop(); // Web: blob URL, native: file path
      setState(() => _recording = false);
      if (path == null) {
        _snack('녹음 데이터를 받을 수 없습니다');
        return;
      }
      // Web/native 공통: blob URL 또는 file path → bytes 읽기
      final bytes = await _readBytes(path);
      if (bytes == null || bytes.isEmpty) {
        _snack('녹음 파일이 비어있습니다');
        return;
      }
      await widget.onRecorded(bytes, 'audio/webm');
    } catch (e) {
      _snack('녹음 정지 실패: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _cancel() async {
    if (!_recording) return;
    _ticker?.cancel();
    try {
      await _recorder.cancel();
    } catch (_) {}
    setState(() {
      _recording = false;
      _elapsed = Duration.zero;
    });
  }

  Future<List<int>?> _readBytes(String pathOrUrl) async {
    if (pathOrUrl.startsWith('blob:') || pathOrUrl.startsWith('http')) {
      try {
        final res = await http.get(Uri.parse(pathOrUrl));
        if (res.statusCode == 200) return res.bodyBytes;
      } catch (_) {}
    }
    return null;
  }

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
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
        color: _recording ? Tokens.danger.withOpacity(0.06) : Tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(Tokens.r12),
        border: Border.all(
          color: _recording ? Tokens.danger.withOpacity(0.30) : Tokens.border,
        ),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _recording ? Tokens.danger : Tokens.navy900,
              shape: BoxShape.circle,
            ),
            child: Icon(_recording ? Icons.stop : Icons.mic, color: Colors.white, size: 20),
          ),
          const SizedBox(width: Tokens.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _recording ? '녹음 중...' : '회의 녹음',
                style: Tokens.ts14.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _recording
                    ? _fmt(_elapsed)
                    : (_processing
                        ? '처리 중...'
                        : '버튼을 눌러 녹음을 시작하세요. 정지하면 자동 업로드됩니다.'),
                style: Tokens.ts12.copyWith(
                  color: _recording ? Tokens.danger : Tokens.textMuted,
                  fontWeight: _recording ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: Tokens.s12),
        if (!_recording && !_processing)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.disabled ? null : _start,
              icon: const Icon(Icons.fiber_manual_record, size: 16, color: Colors.red),
              label: const Text('녹음 시작'),
              style: FilledButton.styleFrom(
                backgroundColor: Tokens.surface,
                foregroundColor: Tokens.text,
                side: const BorderSide(color: Tokens.borderStrong),
              ),
            ),
          )
        else if (_recording)
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cancel,
                child: const Text('취소'),
              ),
            ),
            const SizedBox(width: Tokens.s8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _stop,
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('정지 + 업로드'),
                style: FilledButton.styleFrom(backgroundColor: Tokens.danger),
              ),
            ),
          ])
        else
          const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ]),
    );
  }
}
