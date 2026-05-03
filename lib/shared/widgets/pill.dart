import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// Pill / badge with subtle tinted background + colored label.
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool filled; // true = solid bg, false = tinted

  const Pill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color : color.withOpacity(0.10);
    final fg = filled ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Tokens.r999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
