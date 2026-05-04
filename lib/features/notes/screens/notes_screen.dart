import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/section.dart';
import '../providers/note_providers.dart';
import 'note_editor_screen.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final myNoteAsync = ref.watch(myNoteProvider);
    final sharedAsync = ref.watch(sharedToMeProvider);
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];

    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myNoteProvider);
          ref.invalidate(sharedToMeProvider);
          await ref.read(myNoteProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: Tokens.s32),
          children: [
            Section(
              title: '내 메모장',
              children: [
                myNoteAsync.when(
                  data: (note) {
                    final shareTarget = note?.sharedWithUserId == null
                        ? null
                        : users.where((u) => u.id == note!.sharedWithUserId).firstOrNull;
                    return _NoteTile(
                      icon: Icons.sticky_note_2_outlined,
                      iconColor: Tokens.navy900,
                      title: '내 메모',
                      subtitle: shareTarget == null
                          ? '본인만 볼 수 있음'
                          : '${shareTarget.name}와 공유 중',
                      preview: note?.content ?? '',
                      updatedAt: note?.updatedAt,
                      onTap: () => _open(context, ref, ownerId: me.id, ownerName: null),
                      shareBadge: shareTarget != null,
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(Tokens.s24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(Tokens.s16),
                    child: Text('에러: $e', style: Tokens.ts13.copyWith(color: Tokens.danger)),
                  ),
                ),
              ],
            ),

            // 나에게 공유된 메모들
            sharedAsync.when(
              data: (sharedNotes) {
                if (sharedNotes.isEmpty) return const SizedBox.shrink();
                return Section(
                  title: '나에게 공유된 메모',
                  children: [
                    for (final n in sharedNotes)
                      Builder(builder: (ctx) {
                        final author = users.where((u) => u.id == n.ownerId).firstOrNull;
                        return _NoteTile(
                          icon: Icons.person_outline,
                          iconColor: Tokens.gold600,
                          title: '${author?.name ?? '?'} 메모',
                          subtitle: '${author?.name ?? '?'}이(가) 나에게 공유함',
                          preview: n.content,
                          updatedAt: n.updatedAt,
                          onTap: () => _open(
                            context, ref,
                            ownerId: n.ownerId,
                            ownerName: author?.name,
                          ),
                        );
                      }),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref, {
    required String ownerId,
    String? ownerName,
  }) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NoteEditorScreen(ownerId: ownerId, ownerName: ownerName),
    ));
    ref.invalidate(myNoteProvider);
    ref.invalidate(sharedToMeProvider);
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
  final bool shareBadge;

  const _NoteTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.updatedAt,
    required this.onTap,
    this.shareBadge = false,
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
                  if (shareBadge)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Tokens.gold500.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(Tokens.r999),
                      ),
                      child: Text(
                        '공유',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Tokens.gold600,
                        ),
                      ),
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
