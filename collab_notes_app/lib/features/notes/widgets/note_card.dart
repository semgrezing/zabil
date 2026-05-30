import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../models/note_model.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';

class NoteCard extends StatefulWidget {
  final NoteModel note;
  final VoidCallback? onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onMove;
  final VoidCallback? onTogglePin;
  final ValueChanged<String?>? onColorChanged;
  final bool compactMode;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onArchive,
    this.onDelete,
    this.onMove,
    this.onTogglePin,
    this.onColorChanged,
    this.compactMode = false,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  double _dragProgress = 0.0;
  double _dragSign = 0.0;

  NoteModel get note => widget.note;
  VoidCallback? get onTap => widget.onTap;
  VoidCallback? get onArchive => widget.onArchive;
  VoidCallback? get onDelete => widget.onDelete;
  VoidCallback? get onMove => widget.onMove;
  VoidCallback? get onTogglePin => widget.onTogglePin;
  ValueChanged<String?>? get onColorChanged => widget.onColorChanged;

  @override
  Widget build(BuildContext context) {
    final cardRadius = BorderRadius.circular(AppRadii.md);

    final double clampedProgress = _dragProgress.clamp(0.0, 1.0);
    final double tiltAngle = clampedProgress * 3.0 * (math.pi / 180) * _dragSign;
    final double extraElevation = clampedProgress * 8.0;

    if (widget.compactMode) {
      return _buildCard(context, cardRadius);
    }

    return Dismissible(
      key: Key('note_dismiss_${note.id}'),
      direction: DismissDirection.horizontal,
      onUpdate: (details) {
        setState(() {
          _dragProgress = details.progress;
          _dragSign =
              details.direction == DismissDirection.startToEnd ? 1.0 : -1.0;
        });
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          return await _confirmDelete(context);
        } else {
          onArchive?.call();
          return false;
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
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateZ(tiltAngle),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: clampedProgress > 0.01
              ? BoxDecoration(
                  borderRadius: cardRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.2 + clampedProgress * 0.15,
                      ),
                      blurRadius: 8 + extraElevation * 2,
                      spreadRadius: extraElevation * 0.3,
                      offset: Offset(0, 4 + extraElevation),
                    ),
                  ],
                )
              : null,
          child: _buildCard(context, cardRadius),
        ),
      ),
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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
    BorderRadius cardRadius,
  ) {
    final theme = Theme.of(context);
    final labelColor = _parseColor(note.colorLabel);
    final completedItems =
        note.checklistItems.where((i) => i.completed).length;
    final totalItems = note.checklistItems.length;

    return ClipRRect(
      borderRadius: cardRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: labelColor != null
                  ? [
                      labelColor.withValues(alpha: 0.10),
                      labelColor.withValues(alpha: 0.04),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.07),
                      Colors.white.withValues(alpha: 0.03),
                    ],
            ),
            borderRadius: cardRadius,
            border: Border.all(
              color: labelColor?.withValues(alpha: 0.25) ??
                  Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: cardRadius,
              splashColor: Colors.white.withValues(alpha: 0.05),
              highlightColor: Colors.white.withValues(alpha: 0.03),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header: color dot + group tag + menu
                    Row(
                      children: [
                        if (labelColor != null) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: labelColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: labelColor.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        if (!note.isPersonal && note.groupTitle != null) ...[
                          _GroupTag(groupTitle: note.groupTitle!),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        if (note.pinned)
                          TweenAnimationBuilder<double>(
                            key: ValueKey(note.pinned),
                            tween: Tween<double>(begin: 1.4, end: 1.0),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.elasticOut,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: const Icon(
                              SolarIconsBold.pin,
                              size: 12,
                              color: AppColors.fgSoft,
                            ),
                          ),
                        const Spacer(),
                        if (!widget.compactMode)
                          _buildPopupMenu(),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Title + optional image
                    if (note.images.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTitleAndContent(theme)),
                          const SizedBox(width: AppSpacing.md),
                          _NoteImagePreview(images: note.images),
                        ],
                      )
                    else
                      _buildTitleAndContent(theme),

                    // Checklist progress
                    if (totalItems > 0) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ChecklistProgress(
                        completed: completedItems,
                        total: totalItems,
                      ),
                    ],

                    // Footer
                    const SizedBox(height: AppSpacing.md),
                    _UpdatedByRow(
                      creator: note.creator,
                      updatedAt: note.updatedAt,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleAndContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          note.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
            height: 1.3,
          ),
          maxLines: widget.compactMode ? 2 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (note.content.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            note.content,
            maxLines: widget.compactMode ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.fgSoft,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPopupMenu() {
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<String>(
        icon: const Icon(
          SolarIconsOutline.menuDots,
          size: 14,
          color: AppColors.fgSoft,
        ),
        padding: EdgeInsets.zero,
        splashRadius: 14,
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
          '$completed / $total',
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
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
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

    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.fgSoft,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: Text(
            '$name  $relativeTime',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.fgSoft,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин.';
    if (diff.inHours < 24) return '${diff.inHours} ч.';
    if (diff.inDays < 7) return '${diff.inDays} дн.';
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
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        groupTitle,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.fgSoft,
          letterSpacing: 0.3,
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
    const size = 48.0;
    final radius = BorderRadius.circular(AppRadii.sm);
    final first = images.first;

    return Stack(
      children: [
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
                color: Colors.white.withValues(alpha: 0.06),
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
            right: 3,
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
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
