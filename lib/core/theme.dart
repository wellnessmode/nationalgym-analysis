import 'package:flutter/material.dart';
import 'tokens.dart';

/// Premium theme — navy + warm gold, M3 token-driven.
class AppTheme {
  // Backwards-compat aliases (older code references)
  static const primary = Tokens.navy900;
  static const accent = Tokens.gold500;
  static const dueOverdue = Tokens.danger;
  static const dueSoon = Tokens.warning;
  static const dueNormal = Tokens.textMuted;
  static const statusDone = Tokens.success;
  static const surfaceLight = Tokens.surface;
  static const surfaceMuted = Tokens.bg;

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: Tokens.navy900,
      primary: Tokens.navy900,
      secondary: Tokens.gold500,
      surface: Tokens.surface,
      error: Tokens.danger,
      brightness: Brightness.light,
    ).copyWith(
      surfaceContainerHighest: Tokens.surfaceAlt,
      outline: Tokens.border,
      outlineVariant: Tokens.border,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Tokens.bg,

      // Typography — Pretendard (한국어 본문체, pubspec 에서 번들).
      textTheme: base.textTheme.apply(
        bodyColor: Tokens.text,
        displayColor: Tokens.text,
        fontFamily: 'Pretendard',
      ),

      // AppBar — flat, dark navy on top
      appBarTheme: const AppBarTheme(
        backgroundColor: Tokens.navy900,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 22),
        actionsIconTheme: IconThemeData(color: Colors.white, size: 22),
        surfaceTintColor: Colors.transparent,
      ),

      // Cards — clean white, hairline border, no shadow by default
      cardTheme: CardTheme(
        color: Tokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.r16),
          side: const BorderSide(color: Tokens.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Tokens.navy900,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.r12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1),
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s20, vertical: Tokens.s12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Tokens.text,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.r12)),
          side: const BorderSide(color: Tokens.borderStrong, width: 1),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Tokens.navy900,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Tokens.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.r12),
          borderSide: const BorderSide(color: Tokens.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.r12),
          borderSide: const BorderSide(color: Tokens.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.r12),
          borderSide: const BorderSide(color: Tokens.navy900, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.r12),
          borderSide: const BorderSide(color: Tokens.danger, width: 1),
        ),
        labelStyle: const TextStyle(color: Tokens.textMuted, fontSize: 13),
        hintStyle: const TextStyle(color: Tokens.textFaint, fontSize: 14),
      ),

      // Chips — used as filter pills
      chipTheme: ChipThemeData(
        backgroundColor: Tokens.surface,
        selectedColor: Tokens.navy900,
        side: const BorderSide(color: Tokens.border, width: 1),
        labelStyle: const TextStyle(color: Tokens.text, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s12, vertical: Tokens.s6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.r999)),
        showCheckmark: false,
      ),

      // Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Tokens.surface,
        elevation: 0,
        height: 64,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Tokens.navy900.withOpacity(0.06),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Tokens.navy900 : Tokens.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? Tokens.navy900 : Tokens.textMuted,
            size: 22,
          );
        }),
      ),

      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Tokens.navy900,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        highlightElevation: 8,
        extendedTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.1),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Tokens.text,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.r12)),
        elevation: 4,
      ),

      // Divider hairline
      dividerTheme: const DividerThemeData(
        color: Tokens.border,
        thickness: 1,
        space: 1,
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s4),
        iconColor: Tokens.textMuted,
      ),
    );
  }
}
