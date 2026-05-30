import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Three dots that pulse in sequence to indicate someone is typing.
class TypingIndicator extends StatefulWidget {
  final Color color;
  final double dotSize;
  final Duration duration;

  const TypingIndicator({
    super.key,
    this.color = AppColors.fgSoft,
    this.dotSize = 6.0,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    // Staggered intervals for each dot.
    const intervals = [
      [0.0, 0.3],
      [0.15, 0.45],
      [0.3, 0.6],
    ];

    _dotAnimations = intervals.map((iv) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 50),
      ]).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(iv[0], iv[1], curve: Curves.easeInOut),
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _buildDot(i),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDot(int index) {
    final animValue = _dotAnimations[index].value;
    return Transform.translate(
      offset: Offset(0, -2 * (animValue - 1.0)),
      child: Transform.scale(
        scale: animValue,
        child: Container(
          width: widget.dotSize,
          height: widget.dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
