import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// 모바일 우선 PWA — 와이드 viewport에서는 모바일 폭으로 가운데 정렬.
/// 좌우 빈 공간은 어두운 네이비로 채워 앱 카드처럼 보이게 함.
class MobileContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const MobileContainer({super.key, required this.child, this.maxWidth = 480});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w <= maxWidth + 16) return child;
    return Container(
      color: Tokens.navy900,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: Container(color: Tokens.bg, child: child),
        ),
      ),
    );
  }
}
