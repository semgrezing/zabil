import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../models/note_block_model.dart';

class InsertBlockButton extends StatelessWidget {
  final void Function(NoteBlockType type) onInsert;

  const InsertBlockButton({super.key, required this.onInsert});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.fgSoft.withValues(alpha: 0.12),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.fgSoft.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.add,
                size: 14,
                color: AppColors.fgSoft.withValues(alpha: 0.5),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.fgSoft.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<NoteBlockType>(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Добавить блок',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BlockOption(
                    icon: SolarIconsOutline.textFieldFocus,
                    label: 'Текст',
                    onTap: () => Navigator.pop(ctx, NoteBlockType.text),
                  ),
                  _BlockOption(
                    icon: SolarIconsOutline.checkSquare,
                    label: 'Чеклист',
                    onTap: () => Navigator.pop(ctx, NoteBlockType.checklist),
                  ),
                  _BlockOption(
                    icon: SolarIconsOutline.gallery,
                    label: 'Фото',
                    onTap: () => Navigator.pop(ctx, NoteBlockType.image),
                  ),
                  _BlockOption(
                    icon: SolarIconsOutline.minusCircle,
                    label: 'Линия',
                    onTap: () => Navigator.pop(ctx, NoteBlockType.divider),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ).then((type) {
      if (type != null) onInsert(type);
    });
  }
}

class _BlockOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BlockOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: AppColors.white),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.fgSoft),
          ),
        ],
      ),
    );
  }
}
