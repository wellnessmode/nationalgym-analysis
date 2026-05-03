import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/task.dart';
import '../../../shared/providers/auth_provider.dart';
import '../providers/task_providers.dart';
import '../widgets/dday_badge.dart';
import '../widgets/priority_chip.dart';

class TaskDetailScreen extends ConsumerWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskByIdProvider(taskId));

    return Scaffold(
      appBar: AppBar(title: const Text('업무 상세')),
      body: taskAsync.when(
        data: (task) => _Body(task: task),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('에러: $e')),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  final Task task;
  const _Body({required this.task});

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _commentCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _memoCtrl.text = widget.task.memo ?? '';
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeStatus(TaskStatus s) async {
    setState(() => _saving = true);
    try {
      await ref.read(taskRepositoryProvider).updateStatus(widget.task.id, s);
      if (!mounted) return;
      ref.invalidate(taskByIdProvider(widget.task.id));
      ref.invalidate(filteredTasksProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('상태: ${s.label}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('에러: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveMemo() async {
    setState(() => _saving = true);
    try {
      await ref.read(taskRepositoryProvider).updateMemo(widget.task.id, _memoCtrl.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('메모 저장됨')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('에러: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addComment() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null || _commentCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(taskRepositoryProvider).addComment(
            taskId: widget.task.id,
            userId: me.id,
            content: _commentCtrl.text.trim(),
          );
      _commentCtrl.clear();
      if (mounted) ref.invalidate(taskCommentsProvider(widget.task.id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('에러: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];
    final branches = ref.watch(allBranchesProvider).valueOrNull ?? [];
    final assignee = users.where((u) => u.id == t.assigneeId).firstOrNull;
    final requester = users.where((u) => u.id == t.requesterId).firstOrNull;
    final branch = branches.where((b) => b.id == t.branchId).firstOrNull;
    final commentsAsync = ref.watch(taskCommentsProvider(t.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          PriorityChip(priority: t.priority),
          const SizedBox(width: 8),
          DDayBadge(task: t),
          const Spacer(),
          Text(t.taskType.label, style: const TextStyle(color: Colors.grey)),
        ]),
        const SizedBox(height: 8),
        Text(t.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (t.content != null && t.content!.isNotEmpty)
          Text(t.content!, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 16),
        _InfoRow(label: '지점', value: branch?.name ?? '-'),
        _InfoRow(label: '담당', value: assignee?.name ?? '-'),
        _InfoRow(label: '요청', value: requester?.name ?? '-'),
        _InfoRow(
          label: '마감',
          value: t.dueDate == null ? '없음' : DateFormat('yyyy-MM-dd').format(t.dueDate!),
        ),
        _InfoRow(label: '현재 상태', value: t.status.label),
        const Divider(height: 32),

        // 상태 변경 버튼
        Wrap(spacing: 8, children: [
          for (final s in TaskStatus.values)
            ActionChip(
              avatar: t.status == s ? const Icon(Icons.check, size: 16) : null,
              label: Text(s.label),
              onPressed: _saving ? null : () => _changeStatus(s),
            ),
        ]),
        const SizedBox(height: 24),

        // 메모
        const Text('메모', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _memoCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '메모 입력...',
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _saving ? null : _saveMemo, child: const Text('메모 저장')),
        ),
        const SizedBox(height: 24),

        // 댓글
        const Text('진행 기록 (댓글)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        commentsAsync.when(
          data: (comments) {
            if (comments.isEmpty) {
              return const Text('아직 댓글 없음', style: TextStyle(color: Colors.grey));
            }
            return Column(
              children: [
                for (final c in comments)
                  _CommentTile(
                    comment: c,
                    authorName: users.where((u) => u.id == c.userId).firstOrNull?.name ?? '?',
                  ),
              ],
            );
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
      ],
    );
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

class _CommentTile extends StatelessWidget {
  final TaskComment comment;
  final String authorName;
  const _CommentTile({required this.comment, required this.authorName});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            DateFormat('MM-dd HH:mm').format(comment.createdAt.toLocal()),
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ]),
        const SizedBox(height: 4),
        Text(comment.content),
      ]),
    );
  }
}
