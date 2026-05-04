import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/note.dart';
import '../../../shared/providers/auth_provider.dart';
import '../providers/note_providers.dart';

/// 노트 에디터 — 자동 저장 (입력 멈춘 후 1.2초). 작성자 본인만 공유 대상 변경 가능.
class NoteEditorScreen extends ConsumerStatefulWidget {
  final String ownerId;
  final String? ownerName; // null = 내 메모

  const NoteEditorScreen({
    super.key,
    required this.ownerId,
    this.ownerName,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  bool _saving = false;
  bool _dirty = false;
  bool _loaded = false;
  Note? _note;
  String _initial = '';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onChange);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final note = await ref.read(noteRepositoryProvider).getMine(widget.ownerId);
      if (!mounted) return;
      setState(() {
        _note = note;
        _initial = note?.content ?? '';
        _ctrl.text = _initial;
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
    if (_ctrl.text == _initial) return;
    if (!_dirty) setState(() => _dirty = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), _save);
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    setState(() => _saving = true);
    try {
      final saved = await ref.read(noteRepositoryProvider).saveContent(
            ownerId: widget.ownerId,
            content: _ctrl.text,
          );
      _initial = saved.content;
      _note = saved;
      ref.invalidate(myNoteProvider);
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

  Future<void> _openSharePicker() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    final users = ref.read(allUsersProvider).valueOrNull ?? [];
    if (me == null) return;

    // 작성자만 공유 변경 가능
    if (widget.ownerId != me.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 설정은 작성자만 변경할 수 있어요')),
      );
      return;
    }

    final candidates = users.where((u) => u.id != me.id).toList();
    final current = _note?.sharedWithUserId;

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
            ownerId: widget.ownerId,
            sharedWithUserId: picked.userId,
          );
      ref.invalidate(myNoteProvider);
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

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];
    final isMine = me != null && widget.ownerId == me.id;

    final shareTargetId = _note?.sharedWithUserId;
    final shareTarget = shareTargetId == null
        ? null
        : users.where((u) => u.id == shareTargetId).firstOrNull;

    final title = isMine
        ? '내 메모'
        : '${widget.ownerName ?? '메모'} (공유 받음)';

    final statusText = !_loaded
        ? '불러오는 중...'
        : _saving
            ? '저장 중...'
            : _dirty
                ? '입력 중'
                : (_note?.updatedAt != null
                    ? '저장됨 · ${DateFormat('MM-dd HH:mm').format(_note!.updatedAt.toLocal())}'
                    : '비어있음');

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _flushAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (isMine)
              IconButton(
                tooltip: '공유 설정',
                icon: Icon(
                  shareTarget == null ? Icons.lock_outline : Icons.group,
                  color: shareTarget == null ? Colors.white70 : Tokens.gold500,
                ),
                onPressed: _loaded ? _openSharePicker : null,
              ),
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.s16),
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: Tokens.ts14.copyWith(height: 1.6),
                  decoration: const InputDecoration(
                    hintText: '아무거나 메모하세요. 자동 저장됩니다.',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Tokens.surface,
                    filled: true,
                    contentPadding: EdgeInsets.all(Tokens.s16),
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
      text = '본인만 볼 수 있는 메모입니다 — 우측 상단 자물쇠로 공유';
    } else {
      icon = Icons.group;
      color = Tokens.gold600;
      text = '$shareTargetName님과 공유 중 — 둘 다 편집 가능';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s10),
      color: color == Tokens.textMuted ? Tokens.surfaceAlt : color.withOpacity(0.08),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Tokens.ts12.copyWith(color: color, fontWeight: FontWeight.w600),
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
