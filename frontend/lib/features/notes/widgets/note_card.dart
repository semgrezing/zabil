import 'package:flutter/material.dart';
import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback? onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onArchive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final completedItems = note.checklistItems.where((i) => i.completed).length;
    final totalItems = note.checklistItems.length;
    final hasImages = note.images.isNotEmpty;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                note.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, size: 18),
              onSelected: (value) {
                if (value == 'archive') onArchive?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(note.archived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined),
                      const SizedBox(width: 8),
                      Text(note.archived ? 'Разархивировать' : 'Архивировать'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 8),
                      Text('Удалить'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        if (note.content.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            note.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
          ),
        ],
        if (totalItems > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_box_outlined, size: 14),
              const SizedBox(width: 4),
              Text(
                '$completedItems / $totalItems',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: totalItems > 0 ? completedItems / totalItems : 0,
                    minHeight: 3,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (note.images.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.image_outlined, size: 14),
              const SizedBox(width: 4),
              Text(
                '${note.images.length} фото',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    );

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: hasImages
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NoteImagePreview(images: note.images),
                    const SizedBox(width: 12),
                    Expanded(child: content),
                  ],
                )
              : content,
        ),
      ),
    );
  }
}

class _NoteImagePreview extends StatelessWidget {
  final List<NoteImage> images;

  const _NoteImagePreview({required this.images});

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    const offset = 6.0;
    final radius = BorderRadius.circular(8);
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final outline = Theme.of(context).colorScheme.outlineVariant;
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
                  color: surface,
                  borderRadius: radius,
                  border: Border.all(color: outline),
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
                color: surface,
                alignment: Alignment.center,
                child: const Icon(Icons.image_outlined, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
