import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/note.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section.dart';
import '../providers/note_providers.dart';
import 'note_editor_screen.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final notesAsync = ref.watch(notesProvider);
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];

    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: notesAsync.when(
        data: (notes) {
          // 본인 private
          final myPrivate = notes.firstWhere(
            (n) => n.ownerId == me.id && n.scope == NoteScope.private,
            orElse: () => _emptyNote(me.id, NoteScope.private),
          );

          // shared 노트들
          final sharedAll = notes.where((n) => n.scope == NoteScope.shared).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          final mySharedSelf = sharedAll
              .where((n) => n.ownerId == me.id)
              .firstOrNull;
          // admin은 다른 매니저들의 shared까지 보임
          final othersShared = me.isAdmin
              ? sharedAll.where((n) => n.ownerId != me.id).toList()
              : <Note>[];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notesProvider);
              await ref.read(notesProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: Tokens.s32),
              children: [
                Section(
                  title: '개인 메모',
                  children: [
                    _NoteTile(
                      icon: Icons.lock_outline,
                      iconColor: Tokens.textMuted,
                      title: '내 메모',
                      subtitle: '본인만 볼 수 있음',
                      preview: myPrivate.content,
                      updatedAt: myPrivate.id.isEmpty ? null : myPrivate.updatedAt,
                      onTap: () => _open(context, ref, myPrivate, ownerLabel: null),
                    ),
                  ],
                ),
                Section(
                  title: '공유 메모',
                  children: [
                    if (me.isManager)
                      _NoteTile(
                        icon: Icons.group_outlined,
                        iconColor: Tokens.gold600,
                        title: '대표와 공유',
                        subtitle: '대표만 볼 수 있음',
                        preview: mySharedSelf?.content ?? '',
                        updatedAt: mySharedSelf?.updatedAt,
                        onTap: () => _open(
                          context, ref,
                          mySharedSelf ?? _emptyNote(me.id, NoteScope.shared),
                          ownerLabel: null,
                        ),
                      ),
                    if (me.isAdmin) ...[
                      // 본인 shared (의미 약함이지만 일관성)
                      _NoteTile(
                        icon: Icons.group_outlined,
                        iconColor: Tokens.gold600,
                        title: '내가 작성한 공유 메모',
                        subtitle: '대표 본인만 사용 (참고용)',
                        preview: mySharedSelf?.content ?? '',
                        updatedAt: mySharedSelf?.updatedAt,
                        onTap: () => _open(
                          context, ref,
                          mySharedSelf ?? _emptyNote(me.id, NoteScope.shared),
                          ownerLabel: null,
                        ),
                      ),
                      // 매니저별 shared
                      ..._adminManagerSharedTiles(context, ref, me, users, othersShared),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: '불러오기 실패',
          subtitle: '$e',
          action: TextButton(
            onPressed: () => ref.invalidate(notesProvider),
            child: const Text('다시 시도'),
          ),
        ),
      ),
    );
  }

  Note _emptyNote(String ownerId, NoteScope scope) {
    final now = DateTime.now();
    return Note(
      id: '',
      ownerId: ownerId,
      scope: scope,
      content: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  List<Widget> _adminManagerSharedTiles(
    BuildContext context,
    WidgetRef ref,
    AppUser admin,
    List<AppUser> users,
    List<Note> othersShared,
  ) {
    final managers = users.where((u) => u.isManager).toList();
    return [
      for (final m in managers)
        _NoteTile(
          icon: Icons.person_outline,
          iconColor: Tokens.navy900,
          title: '${m.name} 매니저 메모',
          subtitle: '${m.name} 매니저와 공유',
          preview: othersShared.firstWhere(
            (n) => n.ownerId == m.id,
            orElse: () => _emptyNote(m.id, NoteScope.shared),
          ).content,
          updatedAt: othersShared.firstWhere(
            (n) => n.ownerId == m.id,
            orElse: () => _emptyNote(m.id, NoteScope.shared),
          ).id.isEmpty ? null : othersShared.firstWhere((n) => n.ownerId == m.id).updatedAt,
          onTap: () {
            final existing = othersShared.firstWhere(
              (n) => n.ownerId == m.id,
              orElse: () => _emptyNote(m.id, NoteScope.shared),
            );
            _open(context, ref, existing, ownerLabel: m.name);
          },
        ),
    ];
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Note n, {String? ownerLabel}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NoteEditorScreen(
        ownerId: n.ownerId,
        scope: n.scope,
        ownerLabel: ownerLabel,
        initialContent: n.content,
        initialUpdatedAt: n.id.isEmpty ? null : n.updatedAt,
      ),
    ));
    ref.invalidate(notesProvider);
  }
}

class _NoteTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String preview;
  final DateTime? updatedAt;
  final VoidCallback onTap;

  const _NoteTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.updatedAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(Tokens.r8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: Tokens.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(title, style: Tokens.ts14.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (updatedAt != null)
                    Text(
                      DateFormat('MM-dd HH:mm').format(updatedAt!.toLocal()),
                      style: Tokens.ts11.copyWith(color: Tokens.textFaint),
                    ),
                ]),
                const SizedBox(height: 2),
                Text(subtitle, style: Tokens.ts11.copyWith(color: Tokens.textMuted)),
                const SizedBox(height: Tokens.s6),
                Text(
                  preview.trim().isEmpty ? '(비어있음 — 탭해서 작성)' : preview,
                  style: Tokens.ts13.copyWith(
                    color: preview.trim().isEmpty ? Tokens.textFaint : Tokens.text,
                    fontStyle: preview.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Tokens.textFaint),
          ]),
        ),
      ),
    );
  }
}
