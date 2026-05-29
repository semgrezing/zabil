import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../models/note_model.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback? onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onMove;
  final VoidCallback? onTogglePin;
  final ValueChanged<String?>? onColorChanged;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onArchive,
    this.onDelete,
    this.onMove,
    this.onTogglePin,
    this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = _parseColor(note.colorLabel);
    final cardRadius = BorderRadius.circular(AppRadii.sm);

    return Dismissible(
      key: Key('note_dismiss_${note.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right → delete with confirmation
          return await _confirmDelete(context);
        } else {
          // Swipe left → archive
          onArchive?.call();
          return false; // Don't remove the widget; callback handles state
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          onDelete?.call();
        }
      },
      background: _buildDismissBackground(
        alignment: Alignment.centerLeft,
        color: AppColors.negative,
        icon: SolarIconsOutline.trashBinTrash,
        label: 'Удалить',
        borderRadius: cardRadius,
      ),
      secondaryBackground: _buildDismissBackground(
        alignment: Alignment.centerRight,
        color: AppColors.success,
        icon: note.archived
            ? SolarIconsBold.archiveUp
            : SolarIconsOutline.archive,
        label: note.archived ? 'Разархивировать' : 'Архивировать',
        borderRadius: cardRadius,
      ),
      child: _buildCard(context, labelColor, cardRadius),
    );
  }

  Widget _buildDismissBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
    required BorderRadius borderRadius,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: borderRadius,
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Color? labelColor,
    BorderRadius cardRadius,
  ) {
    final theme = Theme.of(context);
    final completedItems =
        note.checklistItems.where((i) => i.completed).length;
    final totalItems = note.checklistItems.length;

    // Card background: bg2 base, optionally tinted by colorLabel
    final cardColor = labelColor != null
        ? Color.lerp(AppColors.bg2, labelColor, 0.06)!
        : AppColors.bg2;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: cardRadius,
        border: Border.all(
          color: labelColor?.withValues(alpha: 0.2) ?? AppColors.borderSubtle,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: cardRadius,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Color label: left border accent
              if (labelColor != null)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: labelColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadii.sm),
                      bottomLeft: Radius.circular(AppRadii.sm),
                    ),
                  ),
                ),
              // Main content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: labelColor != null ? AppSpacing.md : AppSpacing.lg,
                    right: AppSpacing.sm,
                    top: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                  ),
                  child: note.images.isNotEmpty
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildContent(
                                context,
                                theme,
                                completedItems,
                                totalItems,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            _NoteImagePreview(images: note.images),
                          ],
                        )
                      : _buildContent(
                          context,
                          theme,
                          completedItems,
                          totalItems,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    int completedItems,
    int totalItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header row: title + popup menu
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group tag
                  if (!note.isPersonal && note.groupTitle != null) ...[
                    _GroupTag(groupTitle: note.groupTitle!),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  // Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (note.pinned) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 2, right: 4),
                          child: Icon(
                            SolarIconsBold.pin,
                            size: 13,
                            color: AppColors.fgSoft,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          note.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Popup menu
            SizedBox(
              width: 32,
              height: 32,
              child: PopupMenuButton<String>(
                icon: const Icon(
                  SolarIconsOutline.menuDots,
                  size: 16,
                  color: AppColors.fgSoft,
                ),
                padding: EdgeInsets.zero,
                splashRadius: 16,
                position: PopupMenuPosition.under,
                color: AppColors.bg3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                onSelected: (value) {
                  if (value == 'pin') onTogglePin?.call();
                  if (value == 'archive') onArchive?.call();
                  if (value == 'move') onMove?.call();
                  if (value == 'color') _pickColor(context);
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(
                      children: [
                        Icon(
                          note.pinned
                              ? SolarIconsBold.pin
                              : SolarIconsOutline.pin,
                          size: 18,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          note.pinned ? 'Открепить' : 'Закрепить',
                          style: const TextStyle(color: AppColors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(
                          note.archived
                              ? SolarIconsBold.archiveUp
                              : SolarIconsOutline.archive,
                          size: 18,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          note.archived ? 'Разархивировать' : 'Архивировать',
                          style: const TextStyle(color: AppColors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'move',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz,
                            size: 18, color: AppColors.white),
                        SizedBox(width: AppSpacing.sm),
                        Text('Переместить',
                            style: TextStyle(color: AppColors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'color',
                    child: Row(
                      children: [
                        Icon(Icons.palette_outlined,
                            size: 18, color: AppColors.white),
                        SizedBox(width: AppSpacing.sm),
                        Text('Цветовая метка',
                            style: TextStyle(color: AppColors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(SolarIconsOutline.trashBinTrash,
                            size: 18, color: AppColors.negative),
                        SizedBox(width: AppSpacing.sm),
                        Text('Удалить',
                            style: TextStyle(color: AppColors.negative)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Content preview
        if (note.content.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            note.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.fgSoft,
              height: 1.4,
            ),
          ),
        ],

        // Checklist progress
        if (totalItems > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _ChecklistProgress(
            completed: completedItems,
            total: totalItems,
          ),
        ],

        // Updated by info
        const SizedBox(height: AppSpacing.md),
        _UpdatedByRow(
          creator: note.creator,
          updatedAt: note.updatedAt,
        ),
      ],
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        title: const Text(
          'Удалить заметку?',
          style: TextStyle(color: AppColors.white),
        ),
        content: const Text(
          'Это действие нельзя отменить.',
          style: TextStyle(color: AppColors.fgSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _pickColor(BuildContext context) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.bg2,
      builder: (ctx) => _ColorPickerSheet(initial: note.colorLabel),
    );
    final normalized = (picked == null || picked.isEmpty) ? null : picked;
    if (normalized == null && note.colorLabel == null) return;
    if (normalized == note.colorLabel) return;
    onColorChanged?.call(normalized);
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }
}

// ─── Checklist Progress ───────────────────────────────────────────────────────

class _ChecklistProgress extends StatelessWidget {
  final int completed;
  final int total;

  const _ChecklistProgress({
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    final isComplete = completed == total;

    return Row(
      children: [
        Icon(
          isComplete
              ? SolarIconsBold.checkSquare
              : SolarIconsOutline.checkSquare,
          size: 14,
          color: isComplete ? AppColors.success : AppColors.fgSoft,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$completed из $total',
          style: TextStyle(
            fontSize: 12,
            color: isComplete ? AppColors.success : AppColors.fgSoft,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xs),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.bg3,
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? AppColors.success : AppColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Updated By Row ───────────────────────────────────────────────────────────

class _UpdatedByRow extends StatelessWidget {
  final Map<String, String> creator;
  final DateTime updatedAt;

  const _UpdatedByRow({
    required this.creator,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final name = creator['displayName'] ?? creator['username'] ?? '';
    final relativeTime = _formatRelativeTime(updatedAt);

    return Text(
      'Обновлено $name, $relativeTime',
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.fgSoft,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    // Fallback to date
    final d = dateTime;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}

// ─── Group Tag ────────────────────────────────────────────────────────────────

class _GroupTag extends StatelessWidget {
  final String groupTitle;

  const _GroupTag({required this.groupTitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        groupTitle,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.fgSoft,
          letterSpacing: 0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─── Image Preview ────────────────────────────────────────────────────────────

class _NoteImagePreview extends StatelessWidget {
  final List<NoteImage> images;

  const _NoteImagePreview({required this.images});

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    const offset = 5.0;
    final radius = BorderRadius.circular(AppRadii.xs);
    final first = images.first;

    return SizedBox(
      width: size + (images.length > 1 ? offset : 0),
      height: size + (images.length > 1 ? offset : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (images.length > 1)
            Positioned(
              left: offset,
              top: offset,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: radius,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
              ),
            ),
          ClipRRect(
            borderRadius: radius,
            child: Image.network(
              first.url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, _, __) => Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: radius,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  SolarIconsOutline.gallery,
                  size: 18,
                  color: AppColors.fgSoft,
                ),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bg1.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${images.length - 1}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Color Picker Sheet ───────────────────────────────────────────────────────

class _ColorPickerSheet extends StatelessWidget {
  final String? initial;

  const _ColorPickerSheet({required this.initial});

  static const _palette = [
    '#FF6B6B',
    '#F59F00',
    '#FFD43B',
    '#69DB7C',
    '#20C997',
    '#15AABF',
    '#4DABF7',
    '#748FFC',
    '#9775FA',
    '#DA77F2',
    '#F783AC',
    '#ADB5BD',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Цветовая метка',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final hex in _palette)
                  _ColorDot(
                    hex: hex,
                    selected: initial == hex,
                    onTap: () => Navigator.of(context).pop(hex),
                  ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(''),
                  icon: const Icon(SolarIconsOutline.closeCircle, size: 16),
                  label: const Text('Без метки'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.white : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
