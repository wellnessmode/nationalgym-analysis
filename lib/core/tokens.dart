import 'package:flutter/material.dart';

/// 디자인 토큰 (Premium dark-navy + warm gold accent)
/// 모든 색·간격·반경·shadow를 한 곳에 통합.
class Tokens {
  // ── Brand & semantic colors ────────────────────────────────────────
  static const navy900 = Color(0xFF0A1628);   // primary
  static const navy800 = Color(0xFF12203A);
  static const navy700 = Color(0xFF1E2D4A);
  static const navy600 = Color(0xFF334059);

  static const gold500 = Color(0xFFC9A35C);   // accent (subtle)
  static const gold600 = Color(0xFFB08940);

  static const bg = Color(0xFFF7F8FA);        // app background
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF1F3F6); // subtle blocks
  static const border = Color(0xFFE5E8EE);
  static const borderStrong = Color(0xFFCFD4DD);

  static const text = Color(0xFF0E1422);       // text primary
  static const textMuted = Color(0xFF5B6478);  // secondary
  static const textFaint = Color(0xFF98A0AE);  // tertiary / disabled

  static const success = Color(0xFF12A66B);
  static const warning = Color(0xFFE08600);
  static const danger = Color(0xFFD93636);
  static const info = Color(0xFF2F6FE0);

  // ── Spacing scale ──────────────────────────────────────────────────
  static const s2 = 2.0;
  static const s4 = 4.0;
  static const s5 = 5.0;
  static const s6 = 6.0;
  static const s8 = 8.0;
  static const s10 = 10.0;
  static const s12 = 12.0;
  static const s14 = 14.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
  static const s48 = 48.0;
  static const s64 = 64.0;

  // ── Radii ──────────────────────────────────────────────────────────
  static const r4 = 4.0;
  static const r8 = 8.0;
  static const r12 = 12.0;
  static const r16 = 16.0;
  static const r20 = 20.0;
  static const r999 = 999.0;

  // ── Elevation (subtle shadows, mostly hairlines) ───────────────────
  static List<BoxShadow> shadowSm = [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 1)),
  ];
  static List<BoxShadow> shadowMd = [
    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> shadowLg = [
    BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 32, offset: const Offset(0, 12)),
  ];

  // ── Type scale ─────────────────────────────────────────────────────
  static const ts10 = TextStyle(fontSize: 10, height: 1.3, color: text);
  static const ts11 = TextStyle(fontSize: 11, height: 1.35, color: text);
  static const ts12 = TextStyle(fontSize: 12, height: 1.4, color: text);
  static const ts13 = TextStyle(fontSize: 13, height: 1.45, color: text);
  static const ts14 = TextStyle(fontSize: 14, height: 1.5, color: text);
  static const ts15 = TextStyle(fontSize: 15, height: 1.45, color: text, fontWeight: FontWeight.w500);
  static const ts16 = TextStyle(fontSize: 16, height: 1.4, color: text, fontWeight: FontWeight.w500);
  static const ts18 = TextStyle(fontSize: 18, height: 1.35, color: text, fontWeight: FontWeight.w600);
  static const ts22 = TextStyle(fontSize: 22, height: 1.3, color: text, fontWeight: FontWeight.w700);
  static const ts28 = TextStyle(fontSize: 28, height: 1.25, color: text, fontWeight: FontWeight.w800, letterSpacing: -0.5);
}
