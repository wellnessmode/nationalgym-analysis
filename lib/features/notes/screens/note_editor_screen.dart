import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/note.dart';
import '../providers/note_providers.dart';

/// 노트 에디터 — 자동 저장 (입력 멈춘 후 1.2초 후).
/// 새 노트면 첫 입력 시 upsert로 생성.
class NoteEditorScreen extends ConsumerStatefulWidget {
  final String ownerId;
  final NoteScope scope;
  final String? ownerLabel; // admin이 매니저 노트 볼 때 누구 노트인지 표시
  final String initialContent;
  final DateTime? initialUpdatedAt;
  final bool readOnly;

  const NoteEditorScreen({
    super.key,
    required this.ownerId,
    required this.scope,
    required this.initialContent,
    this.initialUpdatedAt,
    this.ownerLabel,
    this.readOnly = false,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _ctrl;
  Timer? _debounce;
  bool _saving = false;
  bool _dirty = false;
  DateTime? _lastSavedAt;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialContent);
    _lastSavedAt = widget.initialUpdatedAt;
    _ctrl.addListener(_onChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onChange);
    _ctrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (widget.readOnly) return;
    if (_ctrl.text == widget.initialContent && _lastSavedAt == widget.initialUpdatedAt) return;
    setState(() => _dirty = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), _save);
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    setState(() => _saving = true);
    try {
      final saved = await ref.read(noteRepositoryProvider).upsert(
            ownerId: widget.ownerId,
            scope: widget.scope,
            content: _ctrl.text,
          );
      _lastSavedAt = saved.updatedAt;
      ref.invalidate(notesProvider);
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

  @override
  Widget build(BuildContext context) {
    final isPrivate = widget.scope == NoteScope.private;
    final title = widget.ownerLabel != null
        ? '${widget.ownerLabel} · 공유 메모'
        : (isPrivate ? '개인 메모' : '공유 메모');

    final statusText = widget.readOnly
        ? '읽기 전용'
        : _saving
            ? '저장 중...'
            : _dirty
                ? '입력 중'
                : (_lastSavedAt != null
                    ? '저장됨 · ${DateFormat('MM-dd HH:mm').format(_lastSavedAt!.toLocal())}'
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s10),
              color: isPrivate ? Tokens.surfaceAlt : Tokens.gold500.withOpacity(0.08),
              child: Row(children: [
                Icon(
                  isPrivate ? Icons.lock_outline : Icons.group_outlined,
                  size: 14,
                  color: isPrivate ? Tokens.textMuted : Tokens.gold600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isPrivate
                        ? '본인만 볼 수 있는 메모입니다'
                        : '대표와 공유되는 메모입니다',
                    style: Tokens.ts12.copyWith(
                      color: isPrivate ? Tokens.textMuted : Tokens.gold600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.s16),
                child: TextField(
                  controller: _ctrl,
                  readOnly: widget.readOnly,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: Tokens.ts14.copyWith(height: 1.6),
                  decoration: InputDecoration(
                    hintText: widget.readOnly
                        ? ''
                        : '아무거나 메모하세요. 자동 저장됩니다.',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Tokens.surface,
                    filled: true,
                    contentPadding: const EdgeInsets.all(Tokens.s16),
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
