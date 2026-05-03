import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/auth_provider.dart';
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
            return const Center(
              child: Text('회의록이 없습니다', style: TextStyle(color: Colors.grey)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(meetingNotesListProvider);
              await ref.read(meetingNotesListProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: notes.length,
              itemBuilder: (_, i) {
                final n = notes[i];
                final author = users.where((u) => u.id == n.authorId).firstOrNull;
                final branch = branches.where((b) => b.id == n.branchId).firstOrNull;
                final isDraft = n.status == MeetingStatus.draft;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MeetingNoteDetailScreen(meetingNoteId: n.id),
                    )),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDraft ? Colors.orange.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              n.status.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDraft ? Colors.orange.shade700 : Colors.green.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (branch != null)
                            Text(branch.name, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          const Spacer(),
                          Text(
                            DateFormat('yyyy-MM-dd').format(n.meetingDate),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          n.topic,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.person, size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 2),
                          Text(author?.name ?? '?',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          if (n.attendees != null && n.attendees!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '· ${n.attendees}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ]),
                      ]),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('에러: $e')),
      ),
      floatingActionButton: me?.isManager == true
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const MeetingNoteFormScreen(),
              )),
              icon: const Icon(Icons.add),
              label: const Text('회의록 작성'),
            )
          : null,
    );
  }
}
