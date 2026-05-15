import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/task.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/pill.dart';
import '../../../shared/widgets/section.dart';
import '../../attachments/widgets/attachment_section.dart';
import '../providers/task_providers.dart';
import '../widgets/dday_badge.dart';
import '../widgets/priority_chip.dart';

class TaskDetailScreen extends ConsumerWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Task t) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    final canDelete = me.isAdmin || t.requesterId == me.id;
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업무를 만든 사람만 삭제할 수 있어요')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('업무 삭제'),
        content: Text('"${t.title}" 업무를 삭제할까요? 댓글·첨부파일도 함께 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Tokens.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(taskRepositoryProvider).delete(t.id);
      ref.invalidate(filteredTasksProvider);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제됨')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskByIdProvider(taskId));
    final me = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('업무 상세'),
        actions: [
          taskAsync.maybeWhen(
            data: (t) {
              final canEdit = me != null && t.requesterId == me.id;
              final canDelete = me != null && (me.isAdmin || t.requesterId == me.id);
              return Row(mainAxisSize: MainAxisSize.min, children: [
                if (canEdit)
                  IconButton(
                    tooltip: '편집',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TaskFormScreen(existing: t),
                    )),
                  ),
                if (canDelete)
                  IconButton(
                    tooltip: '삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, t),
                  ),
              ]);
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: taskAsync.when(
        data: (task) => _Body(task: task),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('에러: $e', style: Tokens.ts13)),
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
  bool _saving = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
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
    final isDirective = t.taskType == TaskType.directive;

    return ListView(padding: const EdgeInsets.only(bottom: Tokens.s32), children: [
      // Hero header
      Container(
        margin: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s16, Tokens.s16, 0),
        padding: const EdgeInsets.all(Tokens.s20),
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(Tokens.r16),
          border: Border.all(color: Tokens.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Pill(
              label: isDirective ? '할당 업무' : '자체 업무',
              color: isDirective ? Tokens.navy900 : Tokens.gold600,
            ),
            const SizedBox(width: Tokens.s8),
            DDayBadge(task: t),
            const Spacer(),
            PriorityChip(priority: t.priority),
          ]),
          const SizedBox(height: Tokens.s12),
          Text(t.title, style: Tokens.ts22),
          if (t.content != null && t.content!.isNotEmpty) ...[
            const SizedBox(height: Tokens.s8),
            Text(t.content!, style: Tokens.ts14.copyWith(color: Tokens.textMuted)),
          ],
        ]),
      ),

      // Meta section
      Section(title: '정보', children: [
        _MetaRow(icon: Icons.business_outlined, label: '지점', value: branch?.name ?? '-'),
        _MetaRow(icon: Icons.person_outline, label: '담당', value: assignee?.name ?? '-'),
        _MetaRow(icon: Icons.send_outlined, label: '요청', value: requester?.name ?? '-'),
        _MetaRow(
          icon: Icons.event_outlined,
          label: '마감',
          value: t.dueDate == null ? '없음' : DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(t.dueDate!),
        ),
      ]),

      // Status changer
      Padding(
        padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s24, Tokens.s16, Tokens.s8),
        child: Text(
          '상태 변경',
          style: Tokens.ts11.copyWith(
            color: Tokens.textMuted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
        child: Wrap(spacing: Tokens.s8, runSpacing: Tokens.s8, children: [
          for (final s in TaskStatus.values) _StatusButton(
                status: s,
                selected: t.status == s,
                onTap: _saving || t.status == s ? null : () => _changeStatus(s),
              ),
        ]),
      ),

      // Attachments
      Padding(
        padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s24, Tokens.s16, 0),
        child: AttachmentSection(taskId: t.id),
      ),

      // Comments
      Padding(
        padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s24, Tokens.s16, Tokens.s8),
        child: Text(
          '진행 기록',
          style: Tokens.ts11.copyWith(
            color: Tokens.textMuted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
        child: commentsAsync.when(
          data: (comments) {
            if (comments.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(Tokens.s16),
                decoration: BoxDecoration(
                  color: Tokens.surfaceAlt,
                  borderRadius: BorderRadius.circular(Tokens.r12),
                ),
                child: Center(
                  child: Text(
                    '아직 기록이 없습니다',
                    style: Tokens.ts13.copyWith(color: Tokens.textMuted),
                  ),
                ),
              );
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
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(Tokens.s16), child: CircularProgressIndicator())),
          error: (e, _) => Text('에러: $e', style: Tokens.ts13.copyWith(color: Tokens.danger)),
        ),
      ),
      const SizedBox(height: Tokens.s12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              style: Tokens.ts14,
              decoration: const InputDecoration(
                hintText: '진행 사항 기록...',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: Tokens.s8),
          IconButton.filled(
            onPressed: _saving ? null : _addComment,
            icon: const Icon(Icons.send, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: Tokens.navy900,
              minimumSize: const Size(48, 48),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s12),
      child: Row(children: [
        Icon(icon, size: 18, color: Tokens.textMuted),
        const SizedBox(width: Tokens.s12),
        Text(label, style: Tokens.ts13.copyWith(color: Tokens.textMuted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: Tokens.ts14.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final TaskStatus status;
  final bool selected;
  final VoidCallback? onTap;
  const _StatusButton({required this.status, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      TaskStatus.todo => (Tokens.textMuted, Icons.radio_button_unchecked),
      TaskStatus.inProgress => (Tokens.info, Icons.timelapse),
      TaskStatus.done => (Tokens.success, Icons.check_circle),
      TaskStatus.onHold => (Tokens.warning, Icons.pause_circle),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.r12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s14, vertical: Tokens.s10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.10) : Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.r12),
            border: Border.all(color: selected ? color : Tokens.border, width: selected ? 1.5 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: Tokens.s6),
            Text(
              status.label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final dynamic comment; // TaskComment
  final String authorName;
  const _CommentTile({required this.comment, required this.authorName});
  @override
  Widget build(BuildContext context) {
    final initial = authorName.isNotEmpty ? authorName.characters.first : '?';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Tokens.s4),
      padding: const EdgeInsets.all(Tokens.s12),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.r12),
        border: Border.all(color: Tokens.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: Tokens.navy900, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: Tokens.s10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(authorName, style: Tokens.ts13.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: Tokens.s6),
              Text(
                DateFormat('MM-dd HH:mm').format(comment.createdAt.toLocal()),
                style: Tokens.ts11.copyWith(color: Tokens.textFaint),
              ),
            ]),
            const SizedBox(height: 2),
            Text(comment.content, style: Tokens.ts14),
          ]),
        ),
      ]),
    );
  }
}
