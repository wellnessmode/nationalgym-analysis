import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/meeting_note.dart';
import '../../../shared/providers/auth_provider.dart';
import '../providers/meeting_note_providers.dart';
import 'meeting_note_form_screen.dart';

class MeetingNoteDetailScreen extends ConsumerWidget {
  final String meetingNoteId;
  const MeetingNoteDetailScreen({super.key, required this.meetingNoteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(meetingNoteByIdProvider(meetingNoteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('회의록'),
        actions: [
          noteAsync.maybeWhen(
            data: (n) {
              final me = ref.watch(currentUserProvider).valueOrNull;
              if (me != null && (me.isAdmin || me.id == n.authorId)) {
                return IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MeetingNoteFormScreen(existing: n),
                  )),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: noteAsync.when(
        data: (note) => _Body(note: note),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('에러: $e')),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  final MeetingNote note;
  const _Body({required this.note});
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _commentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null || _commentCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(meetingNoteRepositoryProvider).addComment(
            meetingNoteId: widget.note.id,
            userId: me.id,
            content: _commentCtrl.text.trim(),
          );
      _commentCtrl.clear();
      if (mounted) ref.invalidate(meetingCommentsProvider(widget.note.id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('에러: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];
    final branches = ref.watch(allBranchesProvider).valueOrNull ?? [];
    final author = users.where((u) => u.id == n.authorId).firstOrNull;
    final branch = branches.where((b) => b.id == n.branchId).firstOrNull;
    final commentsAsync = ref.watch(meetingCommentsProvider(n.id));
    final isDraft = n.status == MeetingStatus.draft;

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (isDraft)
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('어젠다 — 회의 후 내용을 채워 완료로 전환하세요')),
          ]),
        ),
      Text(n.topic, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      _InfoRow(label: '회의일자', value: DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(n.meetingDate)),
      _InfoRow(label: '지점', value: branch?.name ?? '-'),
      _InfoRow(label: '작성', value: author?.name ?? '?'),
      if (n.attendees != null && n.attendees!.isNotEmpty)
        _InfoRow(label: '참석자', value: n.attendees!),
      const Divider(height: 24),
      if (n.content != null && n.content!.isNotEmpty) ...[
        const Text('내용', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(n.content!),
        const SizedBox(height: 16),
      ],
      if (n.actionItems != null && n.actionItems!.isNotEmpty) ...[
        const Text('후속 조치', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(n.actionItems!),
        const SizedBox(height: 16),
      ],
      const Divider(height: 24),
      const Text('댓글', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      commentsAsync.when(
        data: (comments) {
          if (comments.isEmpty) {
            return const Text('댓글 없음', style: TextStyle(color: Colors.grey));
          }
          return Column(children: [
            for (final c in comments)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(
                      users.where((u) => u.id == c.userId).firstOrNull?.name ?? '?',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MM-dd HH:mm').format(c.createdAt.toLocal()),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(c.content),
                ]),
              ),
          ]);
        },
        loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('에러: $e'),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '댓글 작성...',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(onPressed: _saving ? null : _addComment, icon: const Icon(Icons.send)),
      ]),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(child: Text(value)),
      ]),
    );
  }
}
