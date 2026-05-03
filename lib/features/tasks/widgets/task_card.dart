import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/task.dart';
import '../../../shared/providers/auth_provider.dart';
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _TypeBadge(type: task.taskType),
              const SizedBox(width: 6),
              if (branch != null)
                Text(branch.name, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const Spacer(),
              DDayBadge(task: task),
            ]),
            const SizedBox(height: 6),
            Text(
              task.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(children: [
              if (assignee != null) ...[
                Icon(Icons.person, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 2),
                Text(assignee.name, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(width: 8),
              ],
              PriorityChip(priority: task.priority),
              const Spacer(),
              if (task.status != TaskStatus.todo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: switch (task.status) {
                      TaskStatus.inProgress => Colors.blue.shade50,
                      TaskStatus.done => Colors.green.shade50,
                      TaskStatus.onHold => Colors.grey.shade200,
                      _ => Colors.transparent,
                    },
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(task.status.label, style: const TextStyle(fontSize: 11)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final TaskType type;
  const _TypeBadge({required this.type});
  @override
  Widget build(BuildContext context) {
    final isDirective = type == TaskType.directive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDirective ? Colors.deepPurple.shade50 : Colors.teal.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDirective ? Colors.deepPurple.shade700 : Colors.teal.shade700,
        ),
      ),
    );
  }
}
