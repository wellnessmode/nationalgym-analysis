import 'package:flutter/material.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/enums.dart';

class PriorityChip extends StatelessWidget {
  final TaskPriority priority;
  const PriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      TaskPriority.urgent => Tokens.danger,
      TaskPriority.high => Tokens.warning,
      TaskPriority.normal => Tokens.info,
      TaskPriority.low => Tokens.textFaint,
    };
    final dot = switch (priority) {
      TaskPriority.urgent || TaskPriority.high => Icons.flag_rounded,
      _ => Icons.fiber_manual_record,
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(dot, size: 12, color: color),
      const SizedBox(width: 3),
      Text(
        priority.label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    ]);
  }
}
