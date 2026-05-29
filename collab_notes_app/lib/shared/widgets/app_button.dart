import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// Варианты кнопки приложения.
///
/// Точная карта Figma → код (page «From code», секция «ui kit», Button):
/// - [primary]   — default: `white` fg+`fgContainer` text; hover: `whiteHover`; pressed: `whiteHover` высота 54
/// - [secondary] — default: `bg3` bg + `white` text; hover: `bg2`; pressed: `bg3` высота 54
/// - [text]      — ghost-кнопка без фона (для inline-link типа authButton)
enum AppButtonVariant { primary, secondary, text }

/// Кнопка приложения. Реализует Figma-компонент Button точно по вариантам.
///
/// Использование:
/// ```dart
/// AppButton(label: 'войти', onPressed: _submit)                            // primary
/// AppButton(label: 'отменить', variant: AppButtonVariant.secondary, ...)  // bg3
/// AppButton(label: 'зарегистрироваться', variant: AppButtonVariant.text)  // ghost
/// ```
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool expanded;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final spinnerColor = switch (variant) {
      AppButtonVariant.primary => AppColors.fgContainer,
      AppButtonVariant.secondary => AppColors.white,
      AppButtonVariant.text => AppColors.fgSoft,
    };

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            ),
          )
        : icon == null
            ? Text(
                label,
                style: AppTypography.bodyS,
                textAlign: TextAlign.center,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon!,
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      style: AppTypography.bodyS,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => _PrimaryStyledButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      AppButtonVariant.secondary => _SecondaryStyledButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.fgSoft,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            textStyle: AppTypography.body,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          child: child,
        ),
    };

    if (expanded && variant != AppButtonVariant.text) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Primary: white bg, fgContainer text. hover → whiteHover. pressed → 54h.
class _PrimaryStyledButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _PrimaryStyledButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.white.withValues(alpha: 0.5);
          }
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)) {
            return AppColors.whiteHover;
          }
          return AppColors.white;
        }),
        foregroundColor: WidgetStateProperty.all(AppColors.fgContainer),
        elevation: WidgetStateProperty.all(0),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        minimumSize: WidgetStateProperty.resolveWith((states) {
          // pressed = 54h; иначе 56h
          if (states.contains(WidgetState.pressed)) {
            return const Size(0, 54);
          }
          return const Size(0, AppSizes.buttonHeight);
        }),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// Secondary: bg3 bg, white text. hover → bg2. pressed → 54h.
class _SecondaryStyledButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _SecondaryStyledButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.bg3.withValues(alpha: 0.5);
          }
          if (states.contains(WidgetState.hovered)) {
            return AppColors.bg2;
          }
          return AppColors.bg3;
        }),
        foregroundColor: WidgetStateProperty.all(AppColors.white),
        elevation: WidgetStateProperty.all(0),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        minimumSize: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return const Size(0, 54);
          }
          return const Size(0, AppSizes.buttonHeight);
        }),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      child: child,
    );
  }
}
