import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models/task.dart';

class DDayBadge extends StatelessWidget {
  final Task task;
  const DDayBadge({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final d = task.dDay;
    if (d == null) {
      return const _Pill(label: '기한없음', color: AppTheme.dueNormal);
    }
    if (task.isOverdue) {
      return _Pill(label: 'D+${-d}', color: AppTheme.dueOverdue);
    }
    if (task.isDueSoon) {
      final lbl = d == 0 ? 'D-day' : 'D-$d';
      return _Pill(label: lbl, color: AppTheme.dueSoon);
    }
    return _Pill(label: 'D-$d', color: AppTheme.dueNormal);
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
