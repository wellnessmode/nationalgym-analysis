import 'package:flutter/material.dart';
import '../../core/tokens.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Tokens.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: Tokens.textMuted),
            ),
            const SizedBox(height: Tokens.s16),
            Text(title, style: Tokens.ts15.copyWith(color: Tokens.text, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: Tokens.s4),
              Text(
                subtitle!,
                style: Tokens.ts13.copyWith(color: Tokens.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Tokens.s20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
