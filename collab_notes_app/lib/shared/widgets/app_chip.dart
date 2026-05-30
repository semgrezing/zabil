import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// Размер чипа из Figma-компонента Chip.
enum AppChipSize { s, m }

/// Чип/тег — контекстный фильтр в списках (Notes, Search и т.п.).
///
/// Карта вариантов из Figma (page «From code», секция «ui kit», Chip):
/// - size=s — 29h, body extra-l 14px
/// - size=m — 44h, body 16px regular
/// - state=default — `surfaceGlass` bg, `white` текст
/// - state=hover — `bg2` bg
/// - state=active — `white` bg, `fgContainer` текст
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final AppChipSize size;
  final Widget? leading;
  final Color? inactiveBackgroundColor;

  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onPressed,
    this.size = AppChipSize.s,
    this.leading,
    this.inactiveBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isS = size == AppChipSize.s;
    final height = isS ? 29.0 : 44.0;
    final fg = selected ? Colors.black : AppColors.white;
    final textStyle = (isS ? AppTypography.extraL : AppTypography.body).copyWith(
      color: fg,
    );
    final bg = selected
        ? AppColors.white
      : (inactiveBackgroundColor ?? AppColors.surfaceGlass);
    final hoverBg = selected
        ? AppColors.whiteHover
        : AppColors.bg2;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        hoverColor: hoverBg,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: isS ? 12 : 16),
          alignment: Alignment.center,
          child: IconTheme(
            data: IconThemeData(color: fg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                Text(label, style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
