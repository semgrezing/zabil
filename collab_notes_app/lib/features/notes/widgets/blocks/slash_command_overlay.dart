import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../models/note_block_model.dart';

class SlashCommandMenu extends StatelessWidget {
  final void Function(NoteBlockType type) onSelect;

  const SlashCommandMenu({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg2,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SlashOption(
              icon: SolarIconsOutline.textFieldFocus,
              label: 'Текст',
              onTap: () => onSelect(NoteBlockType.text),
            ),
            _SlashOption(
              icon: SolarIconsOutline.checkSquare,
              label: 'Чеклист',
              onTap: () => onSelect(NoteBlockType.checklist),
            ),
            _SlashOption(
              icon: SolarIconsOutline.gallery,
              label: 'Изображение',
              onTap: () => onSelect(NoteBlockType.image),
            ),
            _SlashOption(
              icon: SolarIconsOutline.minusCircle,
              label: 'Разделитель',
              onTap: () => onSelect(NoteBlockType.divider),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlashOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SlashOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.fgSoft),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}
