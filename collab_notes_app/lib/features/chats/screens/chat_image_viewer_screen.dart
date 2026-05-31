import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ChatImageViewerScreen extends StatefulWidget {
  final String imageUrl;

  const ChatImageViewerScreen({super.key, required this.imageUrl});

  @override
  State<ChatImageViewerScreen> createState() => _ChatImageViewerScreenState();
}

class _ChatImageViewerScreenState extends State<ChatImageViewerScreen> {
  final TransformationController _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_controller.value.isIdentity()) {
      // Zoom in to 2x
      final matrix = Matrix4.identity()..scale(2.0);
      _controller.value = matrix;
    } else {
      // Reset zoom
      _controller.value = Matrix4.identity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: 1,
          maxScale: 4.0,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
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
        ),
      ),
    );
  }
}
