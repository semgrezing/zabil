import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../models/note_model.dart';
import '../screens/image_viewer_screen.dart';
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
  final bool highlightText;
  final bool highlightChecklist;

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
    this.highlightText = false,
    this.highlightChecklist = false,
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
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.4,
        DismissDirection.endToStart: 0.4,
      },
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
    final labelColor = _parseColor(note.colorLabel);
    final completedItems =
        note.checklistItems.where((i) => i.completed).length;
    final totalItems = note.checklistItems.length;

    return GestureDetector(
      onLongPressStart: (details) => _showContextMenu(context, details.globalPosition),
      onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
      child: Material(
        color: const Color(0xFF1A1A1A),
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
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
                // Title + pin icon
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (note.pinned) ...[
                      const SizedBox(width: 4),
                      TweenAnimationBuilder<double>(
                        key: ValueKey(note.pinned),
                        tween: Tween<double>(begin: 1.4, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: const Icon(
                          SolarIconsBold.pin,
                          size: 14,
                          color: AppColors.fgSoft,
                        ),
                      ),
                    ],
                  ],
                ),

                // Content
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    padding: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: widget.highlightText
                          ? AppColors.white.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      note.content,
                      maxLines: widget.compactMode ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.fgSoft,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],

                // Images
                if (note.images.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _NoteImagesRow(
                    images: note.images,
                    noteId: note.id,
                  ),
                ],

                // Checklist progress
                if (totalItems > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    padding: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: widget.highlightChecklist
                          ? AppColors.success.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _ChecklistProgress(
                      completed: completedItems,
                      total: totalItems,
                    ),
                  ),
                ],

                // Footer: author + time, color dot
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _UpdatedByRow(
                        groupTitle: note.groupTitle,
                        isPersonal: note.isPersonal,
                        creator: note.creator,
                        updatedAt: note.updatedAt,
                      ),
                    ),
                    if (labelColor != null) ...[
                      const SizedBox(width: AppSpacing.sm),
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
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: AppColors.bg3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      items: [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(
                note.pinned ? SolarIconsBold.pin : SolarIconsOutline.pin,
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
              Icon(Icons.swap_horiz, size: 18, color: AppColors.white),
              SizedBox(width: AppSpacing.sm),
              Text('Переместить', style: TextStyle(color: AppColors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'color',
          child: Row(
            children: [
              Icon(Icons.palette_outlined, size: 18, color: AppColors.white),
              SizedBox(width: AppSpacing.sm),
              Text('Цветовая метка', style: TextStyle(color: AppColors.white)),
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
              Text('Удалить', style: TextStyle(color: AppColors.negative)),
            ],
          ),
        ),
      ],
    );

    if (value == null || !mounted) return;
    _handleMenuAction(value);
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'pin':
        onTogglePin?.call();
      case 'archive':
        onArchive?.call();
      case 'move':
        onMove?.call();
      case 'color':
        _pickColor(context);
      case 'delete':
        onDelete?.call();
    }
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
      useRootNavigator: true,
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

// ─── Images Row ──────────────────────────────────────────────────────────────

class _NoteImagesRow extends StatelessWidget {
  final List<NoteImage> images;
  final String noteId;

  const _NoteImagesRow({required this.images, required this.noteId});

  static const double _imageHeight = 64.0;
  static const double _imageGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.sm);
    final needsFade = images.length >= 3;

    Widget row = SizedBox(
      height: _imageHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        physics: images.length >= 3
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, __) => const SizedBox(width: _imageGap),
        itemBuilder: (context, index) {
          final img = images[index];
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(
                    noteId: noteId,
                    images: List.of(images),
                    initialIndex: index,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: radius,
              child: SizedBox(
                width: _imageHeight,
                height: _imageHeight,
                child: _ResilientNoteImage(
                  urls: img.urlCandidates,
                  fit: BoxFit.cover,
                  errorBuilder: (context) => Container(
                  width: _imageHeight,
                  height: _imageHeight,
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
            ),
          );
        },
      ),
    );

    if (needsFade) {
      row = ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.black, Colors.black, Colors.transparent],
          stops: [0.0, 0.75, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: row,
      );
    }

    return row;
  }
}

class _ResilientNoteImage extends StatefulWidget {
  const _ResilientNoteImage({
    required this.urls,
    required this.fit,
    required this.errorBuilder,
  });

  final List<String> urls;
  final BoxFit fit;
  final WidgetBuilder errorBuilder;

  @override
  State<_ResilientNoteImage> createState() => _ResilientNoteImageState();
}

class _ResilientNoteImageState extends State<_ResilientNoteImage> {
  int _urlIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty || _urlIndex >= widget.urls.length) {
      return widget.errorBuilder(context);
    }

    return Image.network(
      widget.urls[_urlIndex],
      fit: widget.fit,
      errorBuilder: (_, __, ___) {
        if (_urlIndex + 1 < widget.urls.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _urlIndex += 1;
            });
          });
          return const SizedBox.shrink();
        }
        return widget.errorBuilder(context);
      },
    );
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
          '$completed/$total',
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
  final String? groupTitle;
  final bool isPersonal;
  final Map<String, String> creator;
  final DateTime updatedAt;

  const _UpdatedByRow({
    required this.groupTitle,
    required this.isPersonal,
    required this.creator,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final name = creator['displayName'] ?? creator['username'] ?? '';
    final relativeTime = _formatRelativeTime(updatedAt);
    final groupPart = !isPersonal && (groupTitle?.trim().isNotEmpty ?? false)
        ? '#${groupTitle!.trim()}, '
        : '';

    return Text(
      '$groupPart$name, $relativeTime',
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
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин.';
    if (diff.inHours < 24) return '${diff.inHours}ч';
    if (diff.inDays < 7) return '${diff.inDays}дн.';
    final d = dateTime;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
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
