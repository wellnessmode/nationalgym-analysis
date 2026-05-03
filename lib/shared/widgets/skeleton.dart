import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// Subtle shimmer skeleton block for loading states.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              colors: [
                Tokens.surfaceAlt,
                Color.lerp(Tokens.surfaceAlt, Tokens.border, 0.5)!,
                Tokens.surfaceAlt,
              ],
              stops: [0.0, t, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton card matching TaskCard layout.
class TaskCardSkeleton extends StatelessWidget {
  const TaskCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s6),
      padding: const EdgeInsets.all(Tokens.s16),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.r16),
        border: Border.all(color: Tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(children: [
            Skeleton(width: 36, height: 18, radius: 4),
            SizedBox(width: Tokens.s8),
            Expanded(child: Skeleton(width: 80, height: 12)),
            SizedBox(width: Tokens.s8),
            Skeleton(width: 48, height: 18, radius: 999),
          ]),
          SizedBox(height: Tokens.s12),
          Skeleton(height: 16),
          SizedBox(height: Tokens.s8),
          Skeleton(width: 200, height: 14),
        ],
      ),
    );
  }
}
