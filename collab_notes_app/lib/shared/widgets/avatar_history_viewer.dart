import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AvatarHistoryEntry {
  final String id;
  final String imageUrl;
  final DateTime? createdAt;

  const AvatarHistoryEntry({
    required this.id,
    required this.imageUrl,
    this.createdAt,
  });
}

class AvatarHistoryViewer extends StatefulWidget {
  final String title;
  final List<AvatarHistoryEntry> entries;
  final bool canDelete;
  final Future<void> Function(AvatarHistoryEntry entry)? onDelete;

  const AvatarHistoryViewer({
    super.key,
    required this.title,
    required this.entries,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  State<AvatarHistoryViewer> createState() => _AvatarHistoryViewerState();
}

class _AvatarHistoryViewerState extends State<AvatarHistoryViewer> {
  late final PageController _controller;
  int _index = 0;
  late final List<AvatarHistoryEntry> _items;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _items = [...widget.entries];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _deleteCurrent() async {
    if (!widget.canDelete || widget.onDelete == null || _items.isEmpty) return;
    final entry = _items[_index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аватар?'),
        content: const Text('Вы можете удалить любой элемент из истории.'),
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
    if (ok != true) return;

    await widget.onDelete!(entry);
    if (!mounted) return;

    setState(() {
      _items.removeAt(_index);
      if (_index >= _items.length && _index > 0) {
        _index -= 1;
      }
    });

    if (_items.isEmpty && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('История пуста')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.title} ${_index + 1}/${_items.length}'),
        actions: [
          if (widget.canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteCurrent,
            ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _items.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (_, i) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: _items[i].imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
