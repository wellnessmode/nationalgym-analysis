import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/tokens.dart';

/// 실시간 음성 인식 패널 (Web Speech API 기반, 무료).
/// - 시작: 마이크 권한 요청 + 인식 시작
/// - 사용자가 말하면 인식된 텍스트가 onTranscriptChunk로 흘러감 (interim + final)
/// - 정지: 누적된 최종 텍스트 반환
///
/// 제약 (무료 Web Speech API):
/// - 브라우저 탭이 활성 상태여야 함 (백그라운드 안 됨)
/// - iOS Safari 14.5+ 지원, 일부 환경에서 길이 제한 있음
class AudioRecorderPanel extends StatefulWidget {
  /// 인식된 텍스트 청크 (interim 포함). 부모가 본문에 반영.
  final void Function(String fullTranscript) onTranscriptChunk;

  /// 부모가 외부에서 비활성화 (저장 중 등)
  final bool disabled;

  /// 패널 헤더 라벨 (idle 상태). 컨텍스트별 커스터마이즈.
  final String idleTitle;
  final String idleSubtitle;

  /// 사용자가 패널 우상단 X 를 눌렀을 때 (선택). null 이면 X 미표시.
  final VoidCallback? onClose;

  const AudioRecorderPanel({
    super.key,
    required this.onTranscriptChunk,
    this.disabled = false,
    this.idleTitle = '음성 인식',
    this.idleSubtitle = '버튼을 누르고 말씀하면 본문에 자동 입력됩니다',
    this.onClose,
  });

  @override
  State<AudioRecorderPanel> createState() => _AudioRecorderPanelState();
}

class _AudioRecorderPanelState extends State<AudioRecorderPanel> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _available = false;
  bool _listening = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  /// 이전 세션까지 누적된 최종 텍스트
  String _committed = '';

  /// 현재 세션의 임시(interim) 텍스트
  String _pending = '';

  String? _error;

  @override
  void dispose() {
    _ticker?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _ensureInit() async {
    // 매번 _ensureInit 시 잔여 세션 강제 cancel 시도 (이전 부팅의 좀비 마이크 제거)
    try { await _speech.cancel(); } catch (_) {}
    if (_initialized) return;
    final ok = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_listening && mounted) {
            setState(() => _listening = false);
            _ticker?.cancel();
          }
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _error = err.errorMsg;
          _listening = false;
        });
        _ticker?.cancel();
      },
      debugLogging: false,
    );
    _initialized = true;
    _available = ok;
  }

  Future<void> _start() async {
    if (widget.disabled) return;
    setState(() => _error = null);
    await _ensureInit();
    if (!_available) {
      setState(() => _error = '이 기기에서 음성 인식 사용 불가 (Safari 14.5+ 또는 Chrome 권장)');
      return;
    }

    setState(() {
      _pending = '';
      _listening = true;
      _elapsed = Duration.zero;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });

    await _speech.listen(
      localeId: 'ko_KR',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
      ),
      pauseFor: const Duration(seconds: 30),
      listenFor: const Duration(minutes: 60),
      onResult: (result) {
        if (!mounted) return;
        if (result.finalResult) {
          _committed = (_committed.isEmpty
                  ? result.recognizedWords
                  : '$_committed ${result.recognizedWords}')
              .trim();
          _pending = '';
        } else {
          _pending = result.recognizedWords;
        }
        widget.onTranscriptChunk(_currentFullText());
        setState(() {});
      },
    );
  }

  String _currentFullText() {
    if (_pending.isEmpty) return _committed;
    if (_committed.isEmpty) return _pending;
    return '$_committed $_pending';
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    await _speech.stop();
    if (mounted) setState(() => _listening = false);
    if (_pending.isNotEmpty) {
      _committed = (_committed.isEmpty ? _pending : '$_committed $_pending').trim();
      _pending = '';
      widget.onTranscriptChunk(_committed);
    }
  }

  Future<void> _reset() async {
    if (_listening) await _stop();
    setState(() {
      _committed = '';
      _pending = '';
      _elapsed = Duration.zero;
      _error = null;
    });
    widget.onTranscriptChunk('');
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
        color: _listening ? Tokens.danger.withOpacity(0.06) : Tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(Tokens.r12),
        border: Border.all(
          color: _listening ? Tokens.danger.withOpacity(0.30) : Tokens.border,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _listening ? Tokens.danger : Tokens.navy900,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _listening ? Icons.graphic_eq : Icons.mic,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: Tokens.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _listening ? '음성 인식 중' : widget.idleTitle,
                style: Tokens.ts14.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _listening
                    ? _fmt(_elapsed)
                    : (_error != null ? _error! : widget.idleSubtitle),
                style: Tokens.ts12.copyWith(
                  color: _listening
                      ? Tokens.danger
                      : (_error != null ? Tokens.danger : Tokens.textMuted),
                  fontWeight: _listening ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ]),
          ),
          // 녹음 중에는 항상 명시적 정지 버튼 (사용자가 못 찾는 경우 방지)
          if (_listening)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Tokens.danger, size: 28),
              tooltip: '정지',
              onPressed: _stop,
            )
          else if (_committed.isNotEmpty || _pending.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: '초기화',
              onPressed: widget.disabled ? null : _reset,
            ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: '음성 패널 닫기',
              onPressed: () async {
                if (_listening) await _stop();
                widget.onClose!();
              },
            ),
        ]),
        const SizedBox(height: Tokens.s12),
        SizedBox(
          height: 44,
          child: !_listening
              ? FilledButton.icon(
                  onPressed: widget.disabled ? null : _start,
                  icon: const Icon(Icons.mic, size: 18),
                  label: Text(_committed.isEmpty ? '인식 시작' : '이어서 인식'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Tokens.surface,
                    foregroundColor: Tokens.text,
                    side: const BorderSide(color: Tokens.borderStrong),
                  ),
                )
              : FilledButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('정지'),
                  style: FilledButton.styleFrom(backgroundColor: Tokens.danger),
                ),
        ),
      ]),
    );
  }
}
