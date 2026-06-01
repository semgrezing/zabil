import 'package:flutter/material.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../models/note_block_model.dart';

class ImageBlockWidget extends StatelessWidget {
  final NoteBlockModel block;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const ImageBlockWidget({
    super.key,
    required this.block,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = block.imageData;
    if (data == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.fgSoft),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: Image.network(
            data.url,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => Container(
              height: 120,
              color: AppColors.bg3,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, color: AppColors.fgSoft),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
