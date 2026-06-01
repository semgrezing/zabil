import 'package:flutter/material.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../models/note_block_model.dart';
import 'text_block_widget.dart';
import 'checklist_block_widget.dart';
import 'image_block_widget.dart';
import 'divider_block_widget.dart';

class BlockRow extends StatelessWidget {
  final NoteBlockModel block;
  final ValueChanged<String> onContentChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onSlashTyped;
  final VoidCallback? onImageTap;
  final FocusNode focusNode;
  final bool isFocused;

  const BlockRow({
    super.key,
    required this.block,
    required this.onContentChanged,
    required this.focusNode,
    this.onDelete,
    this.onSlashTyped,
    this.onImageTap,
    this.isFocused = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ReorderableDragStartListener(
              index: block.position,
              child: Icon(
                Icons.drag_indicator,
                size: 18,
                color: isFocused
                    ? AppColors.fgSoft.withValues(alpha: 0.6)
                    : AppColors.fgSoft.withValues(alpha: 0.25),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: _buildBlock()),
          if (block.type != NoteBlockType.text && onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.fgSoft.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlock() {
    switch (block.type) {
      case NoteBlockType.text:
        return TextBlockWidget(
          key: ValueKey('text_${block.id}'),
          block: block,
          onContentChanged: onContentChanged,
          focusNode: focusNode,
          onSlashTyped: onSlashTyped,
        );
      case NoteBlockType.checklist:
        return ChecklistBlockWidget(
          key: ValueKey('checklist_${block.id}'),
          block: block,
          onContentChanged: onContentChanged,
          focusNode: focusNode,
        );
      case NoteBlockType.image:
        return ImageBlockWidget(
          key: ValueKey('image_${block.id}'),
          block: block,
          onTap: onImageTap,
          onDelete: onDelete,
        );
      case NoteBlockType.divider:
        return const DividerBlockWidget();
    }
  }
}
