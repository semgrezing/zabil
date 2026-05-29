import 'package:flutter/material.dart';

/// Цветовые токены приложения.
///
/// Каноническая точка истины — Figma-переменные из файла FG0OQ2LcuJob7QCMbtAYVX,
/// page «From code», секция «ui kit» (Stage 6, 2026-05-27).
///
/// Имена констант ниже совпадают с именами Figma-переменных (`fgContainer`,
/// `bg1`/`bg2`/`bg3`, `whiteHover`, `negative`, `fgSoft`).
/// Старые имена `darkBackground` и т.д. сохранены как **deprecated-алиасы**
/// для обратной совместимости — постепенно мигрируются.
class AppColors {
  AppColors._();

  // ═══ Figma variables (canonical) ════════════════════════════════════════════
  // Backgrounds
  static const bg1 = Color(0xFF161616); // основной фон приложения
  static const bg2 = Color(0xFF1F1F1F); // sheet/dialog фон + secondary-hover
  static const bg3 = Color(0xFF393939); // secondary-кнопка default

  // Foregrounds / text
  static const white = Color(0xFFFFFFFF); // primary CTA fill, иконки active
  static const whiteHover = Color(0xFFF0F0F0); // primary CTA hover/pressed
  static const fgContainer = Color(0xFF333333); // текст на белой CTA
  static const fgSoft = Color(0xFFA8A8A8); // подсказки, неактивный текст

  // Semantics
  static const negative = Color(0xFFFC502C); // error/destructive (Figma)

  // ═══ Glass / overlay (не покрыты Figma-переменными, но устойчивые) ══════════
  static const surfaceGlass = Color(0x26FFFFFF); // white 15%
  static const surfaceGlassStrong = Color(0x40FFFFFF); // white 25% (pressed)
  static const border = Color(0x4DFFFFFF); // white 30% (focus)
  static const borderSubtle = Color(0x1AFFFFFF); // white 10%
  static const textSecondary = Color(0xB3FFFFFF); // white 70%
  static const titleWhite = Color(0xFFFCFFFF); // не чистый white — холодный

  // ═══ Light theme (структурная инверсия) ════════════════════════════════════
  static const lightBackground = Color(0xFFFAFAF9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceGlass = Color(0x0F000000); // black 6%
  static const lightSurfaceGlassStrong = Color(0x1F000000); // black 12%
  static const lightBorder = Color(0x33000000); // black 20%
  static const lightBorderSubtle = Color(0x14000000); // black 8%
  static const lightText = Color(0xFF161616);
  static const lightTextSecondary = Color(0xB3000000); // black 70%
  static const lightTextMuted = Color(0xFF6F6F6F);
  static const lightPrimaryFill = Color(0xFF161616);
  static const lightPrimaryText = Color(0xFFFFFFFF);
  static const lightPrimaryFillDisabled = Color(0x80161616);

  // ═══ Прочая семантика ══════════════════════════════════════════════════════
  static const success = Color(0xFF4FAE82);
  static const warning = Color(0xFFDFAB01);

  // ═══ DEPRECATED — алиасы для обратной совместимости ════════════════════════
  /// Use [bg1] instead.
  @Deprecated('Use AppColors.bg1')
  static const darkBackground = bg1;

  /// Use [bg2] instead (sheets/dialogs).
  @Deprecated('Use AppColors.bg2')
  static const darkSurface = Color(0xFF1C1C1C); // legacy intermediate

  /// Use [surfaceGlass] instead.
  @Deprecated('Use AppColors.surfaceGlass')
  static const darkSurfaceGlass = surfaceGlass;

  @Deprecated('Use AppColors.surfaceGlassStrong')
  static const darkSurfaceGlassStrong = surfaceGlassStrong;

  @Deprecated('Use AppColors.border')
  static const darkBorder = border;

  @Deprecated('Use AppColors.borderSubtle')
  static const darkBorderSubtle = borderSubtle;

  @Deprecated('Use AppColors.titleWhite')
  static const darkText = titleWhite;

  @Deprecated('Use AppColors.textSecondary')
  static const darkTextSecondary = textSecondary;

  /// Use [fgSoft] instead.
  @Deprecated('Use AppColors.fgSoft')
  static const darkTextMuted = fgSoft;

  /// Use [white] instead.
  @Deprecated('Use AppColors.white')
  static const darkPrimaryFill = white;

  /// Use [fgContainer] instead.
  @Deprecated('Use AppColors.fgContainer')
  static const darkPrimaryText = fgContainer;

  @Deprecated('Use AppColors.white with 50% opacity')
  static const darkPrimaryFillDisabled = Color(0x80FFFFFF);

  /// Use [negative] instead. Figma updated #C93838 → #FC502C in Stage 6.
  @Deprecated('Use AppColors.negative')
  static const error = negative;
}
