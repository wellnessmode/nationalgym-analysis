import 'package:flutter/material.dart';

/// 내셔널짐 테마 — 딥네이비 베이스
class AppTheme {
  static const primary = Color(0xFF0A1628);
  static const primaryLight = Color(0xFF1F2D44);
  static const accent = Color(0xFFD4AF37);  // 골드 액센트

  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF5F6F8);

  // 우선순위·D-day 색상
  static const dueOverdue = Color(0xFFD32F2F);  // 빨강
  static const dueSoon = Color(0xFFE67E22);     // 주황
  static const dueNormal = Color(0xFF607D8B);   // 회색
  static const statusDone = Color(0xFF388E3C);  // 초록

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: surfaceMuted,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primary.withOpacity(0.1),
      ),
    );
  }
}
