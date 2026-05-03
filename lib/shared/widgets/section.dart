import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// Settings-style sectioned card group: header + grouped tiles in a card.
class Section extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const Section({
    super.key,
    this.title,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s24, Tokens.s16, 0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: Tokens.s4, bottom: Tokens.s8),
              child: Text(
                title!.toUpperCase(),
                style: Tokens.ts11.copyWith(
                  color: Tokens.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              color: Tokens.surface,
              borderRadius: BorderRadius.circular(Tokens.r16),
              border: Border.all(color: Tokens.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    const Divider(height: 1, indent: Tokens.s16, endIndent: Tokens.s16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
