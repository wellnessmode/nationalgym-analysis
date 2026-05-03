import 'package:flutter/material.dart';
import '../../../shared/models/enums.dart';

class PriorityChip extends StatelessWidget {
  final TaskPriority priority;
  const PriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (priority) {
      TaskPriority.urgent => (Colors.red.shade700, Icons.warning_rounded),
      TaskPriority.high => (Colors.orange.shade700, Icons.priority_high),
      TaskPriority.normal => (Colors.blueGrey.shade400, Icons.fiber_manual_record),
      TaskPriority.low => (Colors.grey.shade500, Icons.low_priority),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 2),
      Text(priority.label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}
