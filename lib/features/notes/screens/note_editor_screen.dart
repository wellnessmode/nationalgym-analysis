import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/note.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../meeting_notes/widgets/audio_recorder_panel.dart';
import '../providers/note_providers.dart';

/// 메모 에디터 — iOS Notes 스타일 (제목 + 본문 분리). 자동 저장 1.2초.
/// noteId == null 이면 첫 입력 시 createEmpty 후 그 ID 사용.
class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId; // null = 신규 (첫 저장 시 생성)
  final String? ownerName; // 공유 받은 메모일 때 작성자 이름

  const NoteEditorScreen({super.key, this.noteId, this.ownerName});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  final FocusNode _bodyFocus = FocusNode();
  Timer? _debounce;
  bool _saving = false;
  bool _dirty = false;
  bool _loaded = false;
  bool _showAudio = false;
  bool _aiCleaning = false;
  String _voiceBaseline = ''; // 음성 인식 시작 직전 본문 값 (인식 결과를 뒤에 append)
  Note? _note;
  String _initialTitle = '';
  String _initialBody = '';

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_onChange);
    _bodyCtrl.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.noteId == null) {
      setState(() => _loaded = true);
      return;
    }
    try {
      final n = await ref.read(noteRepositoryProvider).getById(widget.noteId!);
      if (!mounted) return;
      setState(() {
        _note = n;
        _initialTitle = n?.title ?? '';
        _initialBody = n?.content ?? '';
        _titleCtrl.text = _initialTitle;
        _bodyCtrl.text = _initialBody;
        _loaded = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('불러오기 실패: $e')));
        setState(() => _loaded = true);
      }
    }
  }

  void _onChange() {
    if (!_loaded) return;
    if (_titleCtrl.text == _initialTitle && _bodyCtrl.text == _initialBody) return;
    if (!_dirty) setState(() => _dirty = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), _save);
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    setState(() => _saving = true);
    try {
      final me = ref.read(currentUserProvider).valueOrNull;
      if (me == null) throw Exception('not signed in');

      // 신규: 첫 입력 시 createEmpty
      if (_note == null) {
        _note = await ref.read(noteRepositoryProvider).createEmpty(ownerId: me.id);
      }

      final saved = await ref.read(noteRepositoryProvider).save(
            id: _note!.id,
            title: _titleCtrl.text,
            content: _bodyCtrl.text,
          );
      _initialTitle = saved.title;
      _initialBody = saved.content;
      _note = saved;
      ref.invalidate(myNotesProvider);
      ref.invalidate(sharedToMeProvider);
      if (mounted) setState(() => _dirty = false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _flushAndPop() async {
    _debounce?.cancel();
    if (_dirty) await _save();
    if (mounted) Navigator.of(context).pop();
  }

  /// 음성 녹음 한 회차의 전사 결과 → 본문 끝에 append.
  void _handleTranscript(String chunk) {
    if (chunk.isEmpty) return;
    final cur = _bodyCtrl.text;
    final sep = cur.isEmpty || cur.endsWith('\n') ? '' : '\n';
    _bodyCtrl.text = '$cur$sep$chunk';
    _bodyCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _bodyCtrl.text.length),
    );
  }

  /// 본문 전체를 Gemini 로 정리하고 결과로 교체 (제목은 그대로 유지)
  Future<void> _aiCleanupBody() async {
    final raw = _bodyCtrl.text.trim();
    if (raw.length < 5) {
      _snack('정리할 내용이 너무 짧습니다');
      return;
    }
    setState(() => _aiCleaning = true);
    try {
      final cleaned = await ref.read(noteRepositoryProvider).aiCleanup(raw);
      if (cleaned == null || cleaned.isEmpty) {
        _snack('AI 정리 실패. GEMINI_API_KEY 또는 네트워크 확인');
        return;
      }
      _bodyCtrl.text = cleaned;
      _bodyCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _bodyCtrl.text.length),
      );
      _voiceBaseline = cleaned;
      _snack('AI 정리 완료');
    } catch (e) {
      _snack('AI 정리 오류: $e');
    } finally {
      if (mounted) setState(() => _aiCleaning = false);
    }
  }

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _openSharePicker() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    final users = ref.read(allUsersProvider).valueOrNull ?? [];
    if (me == null || _note == null) return;

    if (_note!.ownerId != me.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 설정은 작성자만 변경할 수 있어요')),
      );
      return;
    }

    final candidates = users.where((u) => u.id != me.id).toList();
    final current = _note!.sharedWithUserId;

    final picked = await showModalBottomSheet<_SharePick>(
      context: context,
      backgroundColor: Tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.r16)),
      ),
      builder: (ctx) => _SharePickerSheet(
        currentTargetId: current,
        candidates: candidates,
      ),
    );
    if (picked == null) return;

    try {
      final updated = await ref.read(noteRepositoryProvider).updateSharing(
            id: _note!.id,
            sharedWithUserId: picked.userId,
          );
      ref.invalidate(myNotesProvider);
      ref.invalidate(sharedToMeProvider);
      if (mounted) {
        setState(() => _note = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(picked.userId == null ? '공유를 해제했어요' : '공유를 업데이트했어요'),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('공유 변경 실패: $e')));
    }
  }

  Future<void> _confirmDelete() async {
    if (_note == null) {
      Navigator.of(context).pop();
      return;
    }
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null || _note!.ownerId != me.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작성자만 삭제할 수 있어요')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('메모 삭제'),
        content: const Text('이 메모를 삭제할까요? 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Tokens.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      _debounce?.cancel();
      await ref.read(noteRepositoryProvider).delete(_note!.id);
      ref.invalidate(myNotesProvider);
      ref.invalidate(sharedToMeProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제됨')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];
    final isMine = me != null && (_note == null || _note!.ownerId == me.id);

    final shareTargetId = _note?.sharedWithUserId;
    final shareTarget = shareTargetId == null
        ? null
        : users.where((u) => u.id == shareTargetId).firstOrNull;

    final title = isMine
        ? '메모'
        : '${widget.ownerName ?? '메모'} (공유받음)';

    final statusText = !_loaded
        ? '...'
        : _saving
            ? '저장 중'
            : _dirty
                ? '입력 중'
                : (_note?.updatedAt != null
                    ? DateFormat('MM-dd HH:mm').format(_note!.updatedAt.toLocal())
                    : '');

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _flushAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              tooltip: _showAudio ? '음성 패널 닫기' : '음성으로 입력',
              icon: Icon(
                _showAudio ? Icons.mic : Icons.mic_none,
                color: _showAudio ? Tokens.gold500 : Colors.white70,
              ),
              onPressed: _loaded
                  ? () {
                      setState(() {
                        _showAudio = !_showAudio;
                        if (_showAudio) {
                          _voiceBaseline = _bodyCtrl.text;
                        }
                      });
                    }
                  : null,
            ),
            if (isMine && _note != null)
              IconButton(
                tooltip: '공유 설정',
                icon: Icon(
                  shareTarget == null ? Icons.lock_outline : Icons.group,
                  color: shareTarget == null ? Colors.white70 : Tokens.gold500,
                ),
                onPressed: _loaded ? _openSharePicker : null,
              ),
            if (isMine && _note != null)
              IconButton(
                tooltip: '삭제',
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                onPressed: _loaded ? _confirmDelete : null,
              ),
            if (statusText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: Tokens.s12),
                child: Center(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            _StatusBanner(
              isMine: isMine,
              shareTargetName: shareTarget?.name,
              ownerName: widget.ownerName,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s12, Tokens.s16, 0),
              child: TextField(
                controller: _titleCtrl,
                style: Tokens.ts18.copyWith(fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  hintText: '제목',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _bodyFocus.requestFocus(),
              ),
            ),
            const Divider(height: 1, indent: Tokens.s16, endIndent: Tokens.s16),

            // 음성 입력 + AI 정리 (상단 마이크 아이콘 토글)
            if (_showAudio) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s12, Tokens.s16, 0),
                child: AudioRecorderPanel(
                  onTranscriptChunk: _handleTranscript,
                  disabled: _saving || _aiCleaning,
                  idleTitle: '음성으로 메모',
                  idleSubtitle: '버튼을 누르고 말하면 메모 본문에 자동 입력됩니다',
                  onClose: () => setState(() => _showAudio = false),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s8, Tokens.s16, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: (_saving || _aiCleaning) ? null : _aiCleanupBody,
                    icon: _aiCleaning
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 16, color: Tokens.gold600),
                    label: Text(_aiCleaning ? 'AI 정리 중...' : 'AI로 메모 정리'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Tokens.gold600,
                      side: const BorderSide(color: Tokens.gold500),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Tokens.s8),
              const Divider(height: 1, indent: Tokens.s16, endIndent: Tokens.s16),
            ],

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.s16),
                child: TextField(
                  controller: _bodyCtrl,
                  focusNode: _bodyFocus,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: Tokens.ts14.copyWith(height: 1.6),
                  decoration: const InputDecoration(
                    hintText: '메모를 입력하세요. 자동 저장됩니다.',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool isMine;
  final String? shareTargetName;
  final String? ownerName;
  const _StatusBanner({
    required this.isMine,
    required this.shareTargetName,
    required this.ownerName,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String text;

    if (!isMine) {
      icon = Icons.group_outlined;
      color = Tokens.gold600;
      text = '${ownerName ?? '작성자'}님이 공유한 메모 — 함께 편집할 수 있어요';
    } else if (shareTargetName == null) {
      icon = Icons.lock_outline;
      color = Tokens.textMuted;
      text = '본인만 볼 수 있는 메모';
    } else {
      icon = Icons.group;
      color = Tokens.gold600;
      text = '$shareTargetName님과 공유 중 — 둘 다 편집 가능';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s8),
      color: color == Tokens.textMuted ? Tokens.surfaceAlt : color.withOpacity(0.08),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Tokens.ts11.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

class _SharePick {
  final String? userId; // null = 공유 해제
  _SharePick(this.userId);
}

class _SharePickerSheet extends StatelessWidget {
  final String? currentTargetId;
  final List<AppUser> candidates;
  const _SharePickerSheet({
    required this.currentTargetId,
    required this.candidates,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: Tokens.s12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Tokens.textFaint.withOpacity(0.4),
              borderRadius: BorderRadius.circular(Tokens.r999),
            ),
          ),
          const SizedBox(height: Tokens.s12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
            child: Row(children: [
              Text(
                '공유 대상 선택',
                style: Tokens.ts15.copyWith(fontWeight: FontWeight.w800),
              ),
            ]),
          ),
          const SizedBox(height: Tokens.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
            child: Row(children: [
              Expanded(
                child: Text(
                  '선택한 사람만 이 메모를 보고 함께 편집할 수 있어요',
                  style: Tokens.ts12.copyWith(color: Tokens.textMuted),
                ),
              ),
            ]),
          ),
          const SizedBox(height: Tokens.s8),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Tokens.textMuted),
            title: const Text('공유 안 함 (본인만)'),
            trailing: currentTargetId == null
                ? const Icon(Icons.check, color: Tokens.gold600)
                : null,
            onTap: () => Navigator.of(context).pop(_SharePick(null)),
          ),
          const Divider(height: 1),
          ...candidates.map((u) => ListTile(
                leading: const Icon(Icons.person_outline, color: Tokens.navy900),
                title: Text(u.name),
                subtitle: Text(
                  u.role == UserRole.admin ? '대표' : '매니저',
                  style: Tokens.ts11.copyWith(color: Tokens.textMuted),
                ),
                trailing: currentTargetId == u.id
                    ? const Icon(Icons.check, color: Tokens.gold600)
                    : null,
                onTap: () => Navigator.of(context).pop(_SharePick(u.id)),
              )),
          const SizedBox(height: Tokens.s8),
        ],
      ),
    );
  }
}
