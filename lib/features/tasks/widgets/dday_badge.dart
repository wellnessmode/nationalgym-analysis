import 'package:flutter/material.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/task.dart';
import '../../../shared/widgets/pill.dart';

class DDayBadge extends StatelessWidget {
  final Task task;
  const DDayBadge({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final d = task.dDay;
    if (d == null) {
      return const Pill(label: '기한없음', color: Tokens.textMuted);
    }
    if (task.isOverdue) {
      return Pill(label: 'D+${-d}', color: Tokens.danger, filled: true);
    }
    if (task.isDueSoon) {
      return Pill(label: d == 0 ? 'D-day' : 'D-$d', color: Tokens.warning, filled: true);
    }
    return Pill(label: 'D-$d', color: Tokens.textMuted);
  }
}
