import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

/// Тема приложения.
///
/// Источник стиля — экраны авторизации из Figma (node 12-633).
/// Dark — основной кинематографичный режим.
/// Light — структурная инверсия (те же радиусы, типографика, размеры).
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(_DarkPalette());
  static ThemeData get light => _build(_LightPalette());

  static ThemeData _build(_Palette p) {
    final isDark = p.brightness == Brightness.dark;
    final cs = ColorScheme(
      brightness: p.brightness,
      surface: p.background,
      onSurface: p.text,
      surfaceContainerHighest: p.surfaceGlass,
      surfaceContainerHigh: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerLow: p.background,
      surfaceContainerLowest: p.background,
      primary: p.primaryFill,
      onPrimary: p.primaryText,
      secondary: p.surfaceGlass,
      onSecondary: p.text,
      error: AppColors.negative,
      onError: Colors.white,
      outline: p.border,
      outlineVariant: p.borderSubtle,
    );

    final textTheme = TextTheme(
      displayLarge: AppTypography.display.copyWith(color: p.text),
      displayMedium: AppTypography.display.copyWith(color: p.text, fontSize: 32),
      displaySmall: AppTypography.display.copyWith(color: p.text, fontSize: 28),
      headlineLarge: AppTypography.titleLarge.copyWith(color: p.text, fontSize: 26),
      headlineMedium: AppTypography.titleLarge.copyWith(color: p.text),
      headlineSmall: AppTypography.titleLarge.copyWith(color: p.text, fontSize: 20),
      titleLarge: AppTypography.titleLarge.copyWith(color: p.text),
      titleMedium: AppTypography.titleMedium.copyWith(color: p.text),
      titleSmall: AppTypography.titleSmall.copyWith(color: p.text),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: p.textSecondary),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
      bodySmall: AppTypography.bodySmall.copyWith(color: p.textMuted),
      labelLarge: AppTypography.labelLarge.copyWith(color: p.text),
      labelMedium: AppTypography.labelMedium.copyWith(color: p.textMuted),
      labelSmall: AppTypography.bodySmall.copyWith(color: p.textMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      fontFamily: AppTypography.fontFamily,
      colorScheme: cs,
      scaffoldBackgroundColor: p.background,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: p.textSecondary, size: 22),

      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleMedium.copyWith(color: p.text),
        iconTheme: IconThemeData(color: p.text, size: 22),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceGlass,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 18,
        ),
        hintStyle: AppTypography.bodyLarge.copyWith(color: p.textMuted),
        labelStyle: AppTypography.bodyMedium.copyWith(color: p.textMuted),
        floatingLabelStyle: AppTypography.bodyMedium.copyWith(color: p.text),
        errorStyle: AppTypography.bodySmall.copyWith(color: AppColors.negative),
        border: _outlineBorder(AppRadii.md, Colors.transparent),
        enabledBorder: _outlineBorder(AppRadii.md, Colors.transparent),
        focusedBorder: _outlineBorder(AppRadii.md, p.border, width: 1),
        errorBorder: _outlineBorder(AppRadii.md, AppColors.negative, width: 1),
        focusedErrorBorder: _outlineBorder(AppRadii.md, AppColors.negative, width: 1),
        disabledBorder: _outlineBorder(AppRadii.md, p.borderSubtle),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primaryFill,
          foregroundColor: p.primaryText,
          disabledBackgroundColor: p.primaryFillDisabled,
          disabledForegroundColor: p.primaryText.withValues(alpha: 0.7),
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          elevation: 0,
          textStyle: AppTypography.labelLarge,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primaryFill,
          foregroundColor: p.primaryText,
          disabledBackgroundColor: p.primaryFillDisabled,
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.textMuted,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          textStyle: AppTypography.bodyLarge,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primaryFill,
        foregroundColor: p.primaryText,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        extendedTextStyle: AppTypography.labelLarge,
      ),

      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: p.borderSubtle, width: 1),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: p.borderSubtle,
        space: 1,
        thickness: 1,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.background,
        selectedItemColor: p.text,
        unselectedItemColor: p.textMuted,
        selectedLabelStyle: AppTypography.labelMedium.copyWith(color: p.text),
        unselectedLabelStyle: AppTypography.labelMedium.copyWith(color: p.textMuted),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.bg2 : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.lg),
          ),
        ),
        dragHandleColor: p.textMuted,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceGlass,
        selectedColor: p.primaryFill,
        labelStyle: AppTypography.bodySmall.copyWith(color: p.text),
        secondaryLabelStyle: AppTypography.bodySmall.copyWith(color: p.primaryText),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          side: BorderSide.none,
        ),
        side: BorderSide.none,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.text,
        circularTrackColor: p.borderSubtle,
        linearTrackColor: p.borderSubtle,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFF1A1A1A),
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.bg2 : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.text,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    );
  }

  static OutlineInputBorder _outlineBorder(
    double radius,
    Color color, {
    double width = 0,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: width > 0
          ? BorderSide(color: color, width: width)
          : BorderSide.none,
    );
  }
}

/// Палитра, специфичная для режима темы.
abstract class _Palette {
  Brightness get brightness;
  Color get background;
  Color get surface;
  Color get surfaceGlass;
  Color get border;
  Color get borderSubtle;
  Color get text;
  Color get textSecondary;
  Color get textMuted;
  Color get primaryFill;
  Color get primaryText;
  Color get primaryFillDisabled;
}

class _DarkPalette implements _Palette {
  @override
  final brightness = Brightness.dark;
  @override
  final background = AppColors.bg1;
  @override
  final surface = AppColors.bg2;
  @override
  final surfaceGlass = AppColors.surfaceGlass;
  @override
  final border = AppColors.border;
  @override
  final borderSubtle = AppColors.borderSubtle;
  @override
  final text = AppColors.titleWhite;
  @override
  final textSecondary = AppColors.textSecondary;
  @override
  final textMuted = AppColors.fgSoft;
  @override
  final primaryFill = AppColors.white;
  @override
  final primaryText = AppColors.fgContainer;
  @override
  final primaryFillDisabled = const Color(0x80FFFFFF);
}

class _LightPalette implements _Palette {
  @override
  final brightness = Brightness.light;
  @override
  final background = AppColors.lightBackground;
  @override
  final surface = AppColors.lightSurface;
  @override
  final surfaceGlass = AppColors.lightSurfaceGlass;
  @override
  final border = AppColors.lightBorder;
  @override
  final borderSubtle = AppColors.lightBorderSubtle;
  @override
  final text = AppColors.lightText;
  @override
  final textSecondary = AppColors.lightTextSecondary;
  @override
  final textMuted = AppColors.lightTextMuted;
  @override
  final primaryFill = AppColors.lightPrimaryFill;
  @override
  final primaryText = AppColors.lightPrimaryText;
  @override
  final primaryFillDisabled = AppColors.lightPrimaryFillDisabled;
}
