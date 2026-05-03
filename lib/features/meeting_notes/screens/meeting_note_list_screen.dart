import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/pill.dart';
import '../../../shared/widgets/skeleton.dart';
import '../providers/meeting_note_providers.dart';
import 'meeting_note_detail_screen.dart';
import 'meeting_note_form_screen.dart';

class MeetingNoteListScreen extends ConsumerWidget {
  const MeetingNoteListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(meetingNotesListProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];
    final branches = ref.watch(allBranchesProvider).valueOrNull ?? [];

    return Scaffold(
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return EmptyState(
              icon: Icons.event_note_outlined,
              title: '회의록이 없습니다',
              subtitle: me?.isManager == true
                  ? '회의 전 어젠다, 회의 후 결과를 정리해 공유하세요'
                  : '매니저가 회의록을 작성하면 여기 표시됩니다',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(meetingNotesListProvider);
              await ref.read(meetingNotesListProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: Tokens.s12, bottom: 100),
              itemCount: notes.length,
              itemBuilder: (_, i) {
                final n = notes[i];
                final author = users.where((u) => u.id == n.authorId).firstOrNull;
                final branch = branches.where((b) => b.id == n.branchId).firstOrNull;
                final isDraft = n.status == MeetingStatus.draft;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s5),
                  decoration: BoxDecoration(
                    color: Tokens.surface,
                    borderRadius: BorderRadius.circular(Tokens.r16),
                    border: Border.all(color: Tokens.border),
                    boxShadow: Tokens.shadowSm,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MeetingNoteDetailScreen(meetingNoteId: n.id),
                      )),
                      child: Padding(
                        padding: const EdgeInsets.all(Tokens.s16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Pill(
                              label: isDraft ? '어젠다' : '완료',
                              color: isDraft ? Tokens.warning : Tokens.success,
                              icon: isDraft ? Icons.edit_note : Icons.check_circle,
                            ),
                            const SizedBox(width: Tokens.s8),
                            if (branch != null)
                              Flexible(
                                child: Text(
                                  _shortBranch(branch.name),
                                  style: Tokens.ts12.copyWith(color: Tokens.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const Spacer(),
                            Text(
                              DateFormat('M/d').format(n.meetingDate),
                              style: Tokens.ts12.copyWith(
                                color: Tokens.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ]),
                          const SizedBox(height: Tokens.s10),
                          Text(
                            n.topic,
                            style: Tokens.ts16.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: Tokens.s10),
                          Row(children: [
                            Icon(Icons.person_outline, size: 14, color: Tokens.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              author?.name ?? '?',
                              style: Tokens.ts13.copyWith(color: Tokens.textMuted, fontWeight: FontWeight.w500),
                            ),
                            if (n.attendees != null && n.attendees!.isNotEmpty) ...[
                              const SizedBox(width: Tokens.s8),
                              Container(width: 3, height: 3, decoration: const BoxDecoration(color: Tokens.textFaint, shape: BoxShape.circle)),
                              const SizedBox(width: Tokens.s8),
                              Flexible(
                                child: Text(
                                  n.attendees!,
                                  style: Tokens.ts13.copyWith(color: Tokens.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ]),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => ListView(
          padding: const EdgeInsets.only(top: Tokens.s12),
          children: const [TaskCardSkeleton(), TaskCardSkeleton(), TaskCardSkeleton()],
        ),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: '불러오기 실패',
          subtitle: '$e',
          action: TextButton(
            onPressed: () => ref.invalidate(meetingNotesListProvider),
            child: const Text('다시 시도'),
          ),
        ),
      ),
      floatingActionButton: me?.isManager == true
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const MeetingNoteFormScreen(),
              )),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('회의록 작성'),
            )
          : null,
    );
  }

  String _shortBranch(String full) {
    final parts = full.split(' ');
    return parts.last;
  }
}
