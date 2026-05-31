import 'package:flutter/material.dart';

/// An image widget that tries multiple URL candidates in order.
///
/// When loading from the first URL fails, it automatically falls back
/// to the next candidate. If all URLs fail (or the list is empty),
/// [errorBuilder] is used.
class ResilientImage extends StatefulWidget {
  const ResilientImage({
    super.key,
    required this.urls,
    required this.fit,
    required this.errorBuilder,
  });

  final List<String> urls;
  final BoxFit fit;
  final WidgetBuilder errorBuilder;

  @override
  State<ResilientImage> createState() => _ResilientImageState();
}

class _ResilientImageState extends State<ResilientImage> {
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
