import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/task.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/pill.dart';
import 'dday_badge.dart';
import 'priority_chip.dart';

class TaskCard extends ConsumerWidget {
  final Task task;
  final VoidCallback onTap;
  const TaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];
    final branches = ref.watch(allBranchesProvider).valueOrNull ?? [];

    final assignee = users.where((u) => u.id == task.assigneeId).firstOrNull;
    final branch = branches.where((b) => b.id == task.branchId).firstOrNull;
    final isDirective = task.taskType == TaskType.directive;
    final isDone = task.status == TaskStatus.done;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s5),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.r16),
        border: Border.all(
          color: task.isOverdue ? Tokens.danger.withOpacity(0.3) : Tokens.border,
          width: 1,
        ),
        boxShadow: Tokens.shadowSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Tokens.s16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Top row: type badge + branch + D-day
              Row(children: [
                Pill(
                  label: isDirective ? '대표 지시' : '자체 업무',
                  color: isDirective ? Tokens.navy900 : Tokens.gold600,
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
                DDayBadge(task: task),
              ]),
              const SizedBox(height: Tokens.s10),

              // Title
              Text(
                task.title,
                style: Tokens.ts16.copyWith(
                  color: isDone ? Tokens.textMuted : Tokens.text,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  decorationColor: Tokens.textMuted,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Tokens.s10),

              // Bottom row: assignee + priority + status
              Row(children: [
                if (assignee != null) ...[
                  _Avatar(name: assignee.name, size: 18),
                  const SizedBox(width: Tokens.s6),
                  Text(
                    assignee.name,
                    style: Tokens.ts13.copyWith(color: Tokens.textMuted, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: Tokens.s12),
                ],
                PriorityChip(priority: task.priority),
                const Spacer(),
                _StatusPill(status: task.status),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  String _shortBranch(String full) {
    // "내셔널짐 PT 용산점" → "용산점"
    final parts = full.split(' ');
    return parts.last;
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  const _Avatar({required this.name, required this.size});
  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Tokens.surfaceAlt,
        border: Border.all(color: Tokens.border, width: 0.5),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w700, color: Tokens.text)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final TaskStatus status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      TaskStatus.todo => (Tokens.textMuted, Icons.radio_button_unchecked),
      TaskStatus.inProgress => (Tokens.info, Icons.timelapse),
      TaskStatus.done => (Tokens.success, Icons.check_circle),
      TaskStatus.onHold => (Tokens.warning, Icons.pause_circle),
    };
    return Pill(label: status.label, color: color, icon: icon);
  }
}
