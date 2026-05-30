import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../models/note_model.dart';
import '../providers/notes_provider.dart';
import '../../../shared/theme/app_colors.dart';

/// Полноэкранный просмотрщик изображений заметки.
///
/// - Свайп между изображениями (зацикленно, благодаря большому itemCount + modulo).
/// - InteractiveViewer для pinch-zoom / pan.
/// - Удаление текущего изображения с подтверждением.
class ImageViewerScreen extends ConsumerStatefulWidget {
  final String noteId;
  final List<NoteImage> images;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.noteId,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  /// Большое число для имитации зацикленной прокрутки.
  /// Реальный индекс = `_pageIndex % images.length`.
  static const int _virtualPagesMultiplier = 1000;

  late PageController _pageController;
  late int _virtualInitial;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _virtualInitial =
        widget.images.length * (_virtualPagesMultiplier ~/ 2) + _currentIndex;
    _pageController = PageController(initialPage: _virtualInitial);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _realIndex(int virtual) => virtual % widget.images.length;

  Future<void> _confirmDelete() async {
    if (widget.images.isEmpty) return;
    final img = widget.images[_currentIndex];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить изображение?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(noteDetailProvider(widget.noteId).notifier)
          .deleteImage(img.id);
      if (!mounted) return;
      // Если это было последнее изображение — закрываем viewer
      if (widget.images.length <= 1) {
        Navigator.of(context).pop();
      } else {
        // Иначе локально удаляем из списка и шифтуем индекс
        setState(() {
          widget.images.removeAt(_currentIndex);
          if (_currentIndex >= widget.images.length) {
            _currentIndex = widget.images.length - 1;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      // Защита — на пустом списке viewer закрывается мгновенно
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        foregroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(SolarIconsBold.altArrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: AppColors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(SolarIconsBold.trashBinTrash),
            tooltip: 'Удалить',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length * _virtualPagesMultiplier,
        onPageChanged: (page) {
          setState(() {
            _currentIndex = _realIndex(page);
          });
        },
        itemBuilder: (context, virtual) {
          final img = widget.images[_realIndex(virtual)];
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: Center(
              child: _ResilientCachedNoteImage(
                urls: img.urlCandidates,
                fit: BoxFit.contain,
                placeholder: const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  ),
                ),
                errorWidget: const Center(
                  child: Icon(
                    SolarIconsOutline.galleryRemove,
                    color: AppColors.fgSoft,
                    size: 48,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResilientCachedNoteImage extends StatefulWidget {
  const _ResilientCachedNoteImage({
    required this.urls,
    required this.fit,
    required this.placeholder,
    required this.errorWidget,
  });

  final List<String> urls;
  final BoxFit fit;
  final Widget placeholder;
  final Widget errorWidget;

  @override
  State<_ResilientCachedNoteImage> createState() =>
      _ResilientCachedNoteImageState();
}

class _ResilientCachedNoteImageState extends State<_ResilientCachedNoteImage> {
  int _urlIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty || _urlIndex >= widget.urls.length) {
      return widget.errorWidget;
    }

    return CachedNetworkImage(
      imageUrl: widget.urls[_urlIndex],
      fit: widget.fit,
      placeholder: (_, __) => widget.placeholder,
      errorWidget: (_, __, ___) {
        if (_urlIndex + 1 < widget.urls.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _urlIndex += 1;
            });
          });
          return const SizedBox.shrink();
        }
        return widget.errorWidget;
      },
    );
  }
}
