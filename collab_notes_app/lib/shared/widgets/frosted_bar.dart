import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Frosted-glass container optimised for always-on-screen bars (nav, composer).
///
/// Sigma 10 is visually indistinguishable from 24 on a dark bg at 0.85 alpha
/// but ~4× cheaper to rasterise per frame.
class FrostedBar extends StatelessWidget {
  const FrostedBar({
    super.key,
    required this.child,
    this.borderRadius = 16,
  });

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10,
            sigmaY: 10,
            tileMode: TileMode.decal,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.bg2.withValues(alpha: 0.85),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
