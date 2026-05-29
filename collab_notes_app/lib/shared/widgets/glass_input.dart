import 'package:flutter/material.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// Полупрозрачное поле ввода в стиле auth-экранов (Figma 12-633).
///
/// Использует токены из темы. Не задаёт жёстко цвета — берёт из
/// текущей [ColorScheme]. Подходит для любых экранов.
class GlassInput extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final String? label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final bool autofocus;
  final int maxLines;
  final int? maxLength;
  final bool enabled;

  const GlassInput({
    super.key,
    required this.hint,
    this.controller,
    this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
    this.prefixIcon,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.bodyMedium.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          autofocus: autofocus,
          maxLines: maxLines,
          maxLength: maxLength,
          enabled: enabled,
          style: AppTypography.bodyLarge.copyWith(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            counterText: '',
          ),
        ),
      ],
    );
  }
}

/// Квадратная действие-кнопка в стиле «back» из register-экрана:
/// glass-фон, скруглённые углы, иконка. 56×56 по умолчанию.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = AppSizes.buttonHeight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final button = Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: cs.onSurface, size: 18),
        ),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: button);
    return button;
  }
}
