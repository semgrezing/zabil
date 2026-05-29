import 'package:flutter/material.dart';

/// Типографика приложения.
///
/// Каноническая точка истины — Figma text-стили в page «From code»
/// (Stage 6, 2026-05-27).
///
/// Figma → Flutter mapping:
/// - `h1`  : SF Pro Semibold 40 / lineHeight=1.0 / letterSpacing=-5
/// - `body-s` : SF Pro Semibold 16 / lineHeight=normal / letterSpacing=0
/// - `body` : SF Pro Regular 16 / lineHeight=1.3 / letterSpacing=0
/// - `extra-l` : SF Pro Regular 14 / lineHeight=normal / letterSpacing=0
///
/// Шрифт: SF Pro (как в Figma). Бандлится из `assets/fonts/`.
/// На Apple-системах — используется системный SF Pro. На Android/Windows —
/// нужны .otf файлы в `assets/fonts/` (см. README в той папке). Если файлов
/// нет — Flutter автоматически фолбэкается на системный шрифт.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'SF Pro';

  // ─── Figma text-стили (canonical) ──────────────────────────────────────────
  /// h1 — display heading (login title и т.п.)
  static const TextStyle h1 = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w600,
    letterSpacing: -5, // Figma value (был -2 в Stage 2)
    height: 1.0,
  );

  /// body — основной body-текст (16px regular)
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3, // Figma 1.2999999523162842
  );

  /// bodyS — body small / button label (16px semibold)
  static const TextStyle bodyS = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.0,
  );

  /// extraL — мелкие метки, caption (14px regular)
  static const TextStyle extraL = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.0,
  );

  // ─── Material aliases (для ThemeData.textTheme) ────────────────────────────
  // Эти алиасы используются внутри AppTheme.dart; новый код должен по
  // возможности использовать [h1], [body], [bodyS], [extraL] напрямую.

  static const TextStyle display = h1;

  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle bodyLarge = body;

  static const TextStyle bodyMedium = extraL;

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle labelLarge = bodyS;

  static const TextStyle labelMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}
