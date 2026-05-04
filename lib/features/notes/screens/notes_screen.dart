import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/note.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/section.dart';
import '../providers/note_providers.dart';
import 'note_editor_screen.dart';

/// iOS Notes 스타일: 메모 목록 + 공유된 메모 섹션 + 추가 FAB
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final myAsync = ref.watch(myNotesProvider);
    final sharedAsync = ref.watch(sharedToMeProvider);
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];

    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Future<void> openEditor({String? noteId, String? ownerName}) async {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NoteEditorScreen(noteId: noteId, ownerName: ownerName),
      ));
      ref.invalidate(myNotesProvider);
      ref.invalidate(sharedToMeProvider);
    }

    Future<void> createNew() async {
      try {
        final note = await ref
            .read(noteRepositoryProvider)
            .createEmpty(ownerId: me.id);
        await openEditor(noteId: note.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('생성 실패: $e')));
        }
      }
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myNotesProvider);
          ref.invalidate(sharedToMeProvider);
          await ref.read(myNotesProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // 내 메모
            myAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Tokens.s24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(Tokens.s16),
                child: Text('에러: $e', style: Tokens.ts13.copyWith(color: Tokens.danger)),
              ),
              data: (notes) {
                if (notes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s40, Tokens.s16, 0),
                    child: Column(children: [
                      const Icon(Icons.sticky_note_2_outlined, size: 48, color: Tokens.textFaint),
                      const SizedBox(height: Tokens.s12),
                      Text('아직 메모가 없습니다',
                          style: Tokens.ts14.copyWith(color: Tokens.textMuted)),
                      const SizedBox(height: Tokens.s4),
                      Text('우하단 + 버튼으로 첫 메모를 만들어보세요',
                          style: Tokens.ts12.copyWith(color: Tokens.textFaint)),
                    ]),
                  );
                }
                return Section(
                  title: '내 메모  ·  ${notes.length}',
                  children: [
                    for (final n in notes)
                      _NoteTile(
                        note: n,
                        shareTargetName: n.sharedWithUserId == null
                            ? null
                            : users.where((u) => u.id == n.sharedWithUserId).firstOrNull?.name,
                        onTap: () => openEditor(noteId: n.id),
                      ),
                  ],
                );
              },
            ),

            // 공유된 메모
            sharedAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (shared) {
                if (shared.isEmpty) return const SizedBox.shrink();
                return Section(
                  title: '공유된 메모  ·  ${shared.length}',
                  children: [
                    for (final n in shared)
                      Builder(builder: (_) {
                        final author = users.where((u) => u.id == n.ownerId).firstOrNull;
                        return _NoteTile(
                          note: n,
                          fromAuthor: author?.name,
                          onTap: () => openEditor(
                            noteId: n.id,
                            ownerName: author?.name,
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createNew,
        backgroundColor: Tokens.navy900,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_note),
        label: const Text('새 메모'),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final Note note;
  final String? shareTargetName; // 내가 공유한 대상
  final String? fromAuthor;      // 공유받은 메모의 작성자
  final VoidCallback onTap;

  const _NoteTile({
    required this.note,
    required this.onTap,
    this.shareTargetName,
    this.fromAuthor,
  });

  @override
  Widget build(BuildContext context) {
    final title = note.displayTitle.isEmpty ? '(제목 없음)' : note.displayTitle;
    final preview = note.bodyPreview;
    final isEmpty = note.displayTitle.isEmpty && preview.isEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      isEmpty ? '(빈 메모)' : title,
                      style: Tokens.ts14.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isEmpty ? Tokens.textFaint : Tokens.text,
                        fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (shareTargetName != null) _Pill(
                    label: '$shareTargetName 공유 중',
                    color: Tokens.gold600,
                  ),
                  if (fromAuthor != null) _Pill(
                    label: '$fromAuthor 공유',
                    color: Tokens.gold600,
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Text(
                    DateFormat('MM-dd HH:mm').format(note.updatedAt.toLocal()),
                    style: Tokens.ts11.copyWith(color: Tokens.textFaint),
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        preview,
                        style: Tokens.ts12.copyWith(color: Tokens.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Tokens.textFaint, size: 18),
          ]),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(Tokens.r999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
