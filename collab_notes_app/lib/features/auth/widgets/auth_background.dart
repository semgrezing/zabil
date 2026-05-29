import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';

/// Full-screen декоративный фон для auth-экранов (mobile).
///
/// Источник истины — Figma `From code` → Login Mobile (node `41:50`),
/// обновлено в Stage 6 (2026-05-27). Структура:
///
/// 1. Solid bg `#161616`.
/// 2. Blurred photo layer (1041 × 1599, centered horizontally, bottom -186):
///    - `image17.png` — основной слой (cover, fills).
///    - `image18.png` — overlay nested внутри overflow-hidden, w=100%, h=108.37%, top=-10.81%.
///    - linear-gradient transparent → black (stops 0.63 → 0.75).
///    - Весь слой wrapped в blur 5.05 px.
/// 3. `Depth` SVG glow — 12-pointed star с radial gradient + 60 px Gaussian blur,
///    позиционирован x=-92, y=-29, size 937, rotated -30°.
///
/// Ассеты скачаны из Figma в Stage 6 → `assets/auth_v2/`.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // Figma reference width was 393. Scale all distances proportionally.
          final scale = w / 393.0;

          // Blurred photo container — 1041 × 1599, centered, bottom: -186
          final imgW = 1041.0 * scale;
          final imgH = 1599.0 * scale;
          final imgLeft = (w - imgW) / 2;
          // bottom: -186 px in Figma => element extends 186*scale below viewport
          final imgTop = h - imgH + 186.0 * scale;

          // image18 — overlay nested with top: -10.81%, h: 108.37%, w: 100%
          final img18Top = -0.1081 * imgH;
          final img18H = 1.0837 * imgH;

          // cacheWidth caps — blurred 5px, low detail needed.
          final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
          final img17Cache = (imgW * dpr).round().clamp(400, 1600);
          final img18Cache = (imgW * dpr).round().clamp(400, 1600);

          // Depth glow — outer 937×937 at left=-92, top=-29 in Figma frame (393×852).
          // Rotated -30° around center (Figma: `-rotate-30`).
          final depthSize = 937.0 * scale;
          final depthLeft = -92.0 * scale;
          final depthTop = -29.0 * scale;

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              // 1. Solid dark base
              const ColoredBox(color: AppColors.bg1),

              // 2. Blurred photo layer
              Positioned(
                left: imgLeft,
                top: imgTop,
                width: imgW,
                height: imgH,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: 5.05,
                    sigmaY: 5.05,
                    tileMode: TileMode.clamp,
                  ),
                  child: ClipRect(
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // image17 — full cover
                        Positioned.fill(
                          child: Image.asset(
                            'assets/auth_v2/image17.png',
                            fit: BoxFit.cover,
                            cacheWidth: img17Cache,
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                        // image18 — overlay with offset
                        Positioned(
                          left: 0,
                          top: img18Top,
                          width: imgW,
                          height: img18H,
                          child: Image.asset(
                            'assets/auth_v2/image18.png',
                            fit: BoxFit.fill,
                            cacheWidth: img18Cache,
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                        // gradient transparent → black inside blur layer
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.0, 0.63111, 0.75053],
                                colors: [
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Depth glow — rotated -30°
              Positioned(
                left: depthLeft,
                top: depthTop,
                width: depthSize,
                height: depthSize,
                child: RepaintBoundary(
                  child: Transform.rotate(
                    angle: -math.pi / 6, // -30°
                    alignment: Alignment.center,
                    child: const CustomPaint(painter: _DepthGlowPainter()),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Paints the Figma "Depth" vector: a 12-pointed star (evenOdd fill) with
/// radial gradient + 60 px Gaussian blur. SVG viewBox = 926 × 926.
///
/// Реализация не меняется со Stage 1 — путь и градиент идентичны исходному
/// SVG. В Stage 6 добавлена внешняя -30° rotation (см. [AuthBackground]).
class _DepthGlowPainter extends CustomPainter {
  const _DepthGlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const svgBox = 926.0;
    final s = size.width / svgBox;

    // 12-pointed star outer path
    final path = Path()
      ..moveTo(806 * s, 291.5 * s)
      ..lineTo(634.5 * s, 120 * s)
      ..lineTo(463 * s, 291.5 * s)
      ..lineTo(291.5 * s, 120 * s)
      ..lineTo(120 * s, 291.5 * s)
      ..lineTo(291.5 * s, 463 * s)
      ..lineTo(120 * s, 634.5 * s)
      ..lineTo(291.5 * s, 806 * s)
      ..lineTo(463 * s, 634.5 * s)
      ..lineTo(634.5 * s, 806 * s)
      ..lineTo(806 * s, 634.5 * s)
      ..lineTo(634.5 * s, 463 * s)
      ..close();
    path.addPolygon([
      Offset(634.5 * s, 463 * s),
      Offset(463 * s, 634.5 * s),
      Offset(291.5 * s, 463 * s),
      Offset(463 * s, 291.5 * s),
    ], true);
    path.fillType = PathFillType.evenOdd;

    const gradient = RadialGradient(
      center: Alignment(-0.642, -0.353),
      radius: 0.634,
      colors: [
        Color(0xFF015C4B),
        Color(0xFFD0EFF3),
        Color(0xFF2A00C0),
      ],
      stops: [0.0, 0.528846, 1.0],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 60 * s);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DepthGlowPainter oldDelegate) => false;
}
