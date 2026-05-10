import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/note.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../notes/providers/note_providers.dart';

/// 대표 전용 — 매니저들의 메모 모아보기 (인사평가 목적).
/// RLS는 admin에게 모든 메모 SELECT 권한을 부여함.
class ManagerNotesAuditScreen extends ConsumerStatefulWidget {
  const ManagerNotesAuditScreen({super.key});

  @override
  ConsumerState<ManagerNotesAuditScreen> createState() =>
      _ManagerNotesAuditScreenState();
}

class _ManagerNotesAuditScreenState extends ConsumerState<ManagerNotesAuditScreen> {
  String? _filterUserId; // null = 전체

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];
    final allAsync = ref.watch(allNotesAdminProvider);

    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!me.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('대표만 접근할 수 있습니다')),
      );
    }

    final managers = users.where((u) => u.isManager).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('매니저 기록 열람')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allNotesAdminProvider);
          await ref.read(allNotesAdminProvider.future);
        },
        child: allAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('에러: $e')),
          data: (all) {
            // 본인(대표) 메모는 제외 — 매니저 메모만
            final managerNotes = all.where((n) => n.ownerId != me.id).toList();
            final filtered = _filterUserId == null
                ? managerNotes
                : managerNotes.where((n) => n.ownerId == _filterUserId).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s12, Tokens.s16, Tokens.s32),
              children: [
                // 안내문
                Container(
                  padding: const EdgeInsets.all(Tokens.s12),
                  decoration: BoxDecoration(
                    color: Tokens.gold500.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(Tokens.r12),
                    border: Border.all(color: Tokens.gold500.withOpacity(0.25)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, size: 16, color: Tokens.gold600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '매니저들이 작성한 모든 메모가 표시됩니다.',
                        style: Tokens.ts11.copyWith(color: Tokens.text, height: 1.5),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: Tokens.s12),

                // 매니저 필터
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: '전체 (${managerNotes.length})',
                        selected: _filterUserId == null,
                        onTap: () => setState(() => _filterUserId = null),
                      ),
                      for (final m in managers)
                        Builder(builder: (_) {
                          final count = managerNotes.where((n) => n.ownerId == m.id).length;
                          return _FilterChip(
                            label: '${m.name} ($count)',
                            selected: _filterUserId == m.id,
                            onTap: () => setState(() => _filterUserId = m.id),
                          );
                        }),
                    ],
                  ),
                ),

                const SizedBox(height: Tokens.s8),

                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Tokens.s40),
                    child: Center(
                      child: Text(
                        '표시할 메모가 없습니다',
                        style: Tokens.ts13.copyWith(color: Tokens.textMuted),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Tokens.surface,
                      borderRadius: BorderRadius.circular(Tokens.r16),
                      border: Border.all(color: Tokens.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < filtered.length; i++) ...[
                          _AuditNoteTile(
                            note: filtered[i],
                            authorName: users
                                    .where((u) => u.id == filtered[i].ownerId)
                                    .firstOrNull
                                    ?.name ??
                                '?',
                            sharedWithName: filtered[i].sharedWithUserId == null
                                ? null
                                : users
                                    .where((u) => u.id == filtered[i].sharedWithUserId)
                                    .firstOrNull
                                    ?.name,
                          ),
                          if (i < filtered.length - 1)
                            const Divider(height: 1, indent: Tokens.s16, endIndent: Tokens.s16),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Tokens.navy900,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Tokens.text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        showCheckmark: false,
      ),
    );
  }
}

class _AuditNoteTile extends StatelessWidget {
  final Note note;
  final String authorName;
  final String? sharedWithName;
  const _AuditNoteTile({
    required this.note,
    required this.authorName,
    required this.sharedWithName,
  });

  @override
  Widget build(BuildContext context) {
    final title = note.displayTitle.isEmpty ? '(제목 없음)' : note.displayTitle;
    final preview = note.bodyPreview;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s4),
      childrenPadding: const EdgeInsets.fromLTRB(Tokens.s16, 0, Tokens.s16, Tokens.s14),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Tokens.navy900.withOpacity(0.08),
            borderRadius: BorderRadius.circular(Tokens.r999),
          ),
          child: Text(
            authorName,
            style: Tokens.ts11.copyWith(fontWeight: FontWeight.w800, color: Tokens.navy900),
          ),
        ),
        if (note.isDeleted) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Tokens.danger.withOpacity(0.13),
              borderRadius: BorderRadius.circular(Tokens.r999),
            ),
            child: Text(
              '삭제됨',
              style: Tokens.ts11.copyWith(fontWeight: FontWeight.w800, color: Tokens.danger),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Tokens.ts14.copyWith(
              fontWeight: FontWeight.w700,
              color: note.isDeleted ? Tokens.textMuted : Tokens.text,
              decoration: note.isDeleted ? TextDecoration.lineThrough : null,
              decorationColor: Tokens.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Text(
            note.isDeleted && note.deletedAt != null
                ? '삭제 ${DateFormat('MM-dd HH:mm').format(note.deletedAt!.toLocal())}'
                : DateFormat('MM-dd HH:mm').format(note.updatedAt.toLocal()),
            style: Tokens.ts11.copyWith(
              color: note.isDeleted ? Tokens.danger : Tokens.textFaint,
              fontWeight: note.isDeleted ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          if (sharedWithName != null) ...[
            const SizedBox(width: 6),
            Text('· $sharedWithName와 공유',
                style: Tokens.ts11.copyWith(color: Tokens.gold600, fontWeight: FontWeight.w600)),
          ],
          if (preview.isNotEmpty) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                preview,
                style: Tokens.ts11.copyWith(color: Tokens.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ]),
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Tokens.s12),
          decoration: BoxDecoration(
            color: Tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(Tokens.r8),
          ),
          child: Text(
            note.content.isEmpty ? '(빈 메모)' : note.content,
            style: Tokens.ts13.copyWith(
              height: 1.6,
              color: note.content.isEmpty ? Tokens.textFaint : Tokens.text,
            ),
          ),
        ),
      ],
    );
  }
}
