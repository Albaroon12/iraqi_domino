import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/constants/app_colors.dart';

/// The playing surface with authentic Iraqi café craftsmanship:
/// a carved walnut wooden frame inlaid with Arabic geometric & arabesque gold
/// ornaments, and a clean, realistic baize cloth whose center shows natural
/// faded wear from countless domino games. Game content goes in [child].
///
/// It only decorates: it fills whatever size its parent gives it, so the
/// game screen decides the board's size. Colors are constructor values so
/// a future "table skin" can restyle it without touching the layout.
class BoardFrame extends StatelessWidget {
  const BoardFrame({
    super.key,
    required this.child,
    this.frameWidth = 13,
    this.feltLight = const Color(0xFF235C3D),
    this.feltDark = const Color(0xFF0E2C1C),
    this.frameLight = const Color(0xFF7B4E2D),
    this.frameDark = const Color(0xFF28150A),
  });

  final Widget child;

  /// Thickness of the wooden frame, in pixels.
  final double frameWidth;

  /// Felt colors: center and edge.
  final Color feltLight;
  final Color feltDark;

  /// Frame wood colors: top-left and bottom-right.
  final Color frameLight;
  final Color frameDark;

  @override
  Widget build(BuildContext context) {
    final innerRadius = BorderRadius.circular(8);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [frameLight, const Color(0xFF4A2B16), frameDark],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: Border.all(color: const Color(0xFF140A05), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _IraqiFramePainter(frameWidth: frameWidth),
        child: Padding(
          padding: EdgeInsets.all(frameWidth),
          // Thin gold line between the carved wood and the felt.
          child: Container(
            decoration: BoxDecoration(
              borderRadius: innerRadius,
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.85),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: innerRadius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cached felt + Iraqi geometric heritage watermark.
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _IraqiFeltPainter(
                        feltLight: feltLight,
                        feltDark: feltDark,
                      ),
                    ),
                  ),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints authentic Arabic geometric & arabesque gold inlays on the carved
/// walnut wooden frame (corners and running side motifs).
class _IraqiFramePainter extends CustomPainter {
  const _IraqiFramePainter({required this.frameWidth});

  final double frameWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final mid = frameWidth * 0.5;

    final goldStroke = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final goldFaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;
    final goldFill = Paint()..color = AppColors.gold.withValues(alpha: 0.72);
    final brassShadow = Paint()..color = const Color(0x99120804);

    // Outer & inner hairline inlays framing the carved band.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2.4), const Radius.circular(16)),
      goldFaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(frameWidth - 2.2),
        const Radius.circular(9),
      ),
      goldFaint,
    );

    // Running Arabic chain motif (interlaced ogee arcs & diamonds) along top/bottom.
    const step = 18.0;
    final startX = frameWidth + 10;
    final endX = size.width - frameWidth - 10;
    for (var x = startX; x <= endX; x += step) {
      _drawEdgeMotif(canvas, Offset(x, mid), 0, goldStroke, goldFill);
      _drawEdgeMotif(
        canvas,
        Offset(x, size.height - mid),
        math.pi,
        goldStroke,
        goldFill,
      );
    }

    // Running Arabic chain motif along left/right frame rails.
    final startY = frameWidth + 10;
    final endY = size.height - frameWidth - 10;
    for (var y = startY; y <= endY; y += step) {
      _drawEdgeMotif(
        canvas,
        Offset(mid, y),
        -math.pi / 2,
        goldStroke,
        goldFill,
      );
      _drawEdgeMotif(
        canvas,
        Offset(size.width - mid, y),
        math.pi / 2,
        goldStroke,
        goldFill,
      );
    }

    // Ornate Arabic 8-point brass corner rosettes on all 4 corners.
    final corners = [
      Offset(mid + 1, mid + 1),
      Offset(size.width - mid - 1, mid + 1),
      Offset(mid + 1, size.height - mid - 1),
      Offset(size.width - mid - 1, size.height - mid - 1),
    ];
    for (final c in corners) {
      _drawCornerRosette(canvas, c, brassShadow, goldStroke, goldFill);
    }
  }

  void _drawEdgeMotif(
    Canvas canvas,
    Offset center,
    double rotation,
    Paint stroke,
    Paint fill,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Interlaced Arabic ogee wave + central diamond pearl.
    final wave = Path()
      ..moveTo(-8, 0)
      ..quadraticBezierTo(-4, -3.2, 0, 0)
      ..quadraticBezierTo(4, 3.2, 8, 0);
    canvas.drawPath(wave, stroke);

    final waveMirror = Path()
      ..moveTo(-8, 0)
      ..quadraticBezierTo(-4, 3.2, 0, 0)
      ..quadraticBezierTo(4, -3.2, 8, 0);
    canvas.drawPath(waveMirror, stroke);

    final d = Path()
      ..moveTo(0, -2.0)
      ..lineTo(2.0, 0)
      ..lineTo(0, 2.0)
      ..lineTo(-2.0, 0)
      ..close();
    canvas.drawPath(d, fill);

    canvas.restore();
  }

  void _drawCornerRosette(
    Canvas canvas,
    Offset c,
    Paint shadow,
    Paint stroke,
    Paint fill,
  ) {
    canvas.drawCircle(c + const Offset(0, 0.8), 4.2, shadow);
    // Tiny 8-pointed Arabic star in brass.
    for (final angle in [0.0, math.pi / 4]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 5.4, height: 5.4),
        stroke,
      );
      canvas.restore();
    }
    canvas.drawCircle(c, 1.8, fill);
  }

  @override
  bool shouldRepaint(_IraqiFramePainter oldDelegate) =>
      oldDelegate.frameWidth != frameWidth;
}

/// Paints clean, realistic woven baize cloth with natural faded wear in the
/// center (from heavy domino play) and 3D recessed shadows under the frame.
class _IraqiFeltPainter extends CustomPainter {
  const _IraqiFeltPainter({required this.feltLight, required this.feltDark});

  final Color feltLight;
  final Color feltDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Base emerald baize cloth.
    final feltPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.98,
        colors: [feltLight, Color.lerp(feltLight, feltDark, 0.55)!, feltDark],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, feltPaint);

    // 2. Natural worn/faded patina in the center from heavy domino play.
    final wornCenter = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.58,
        colors: const [
          Color(0x46B8C9AE), // soft desaturated pale sage wear at center
          Color(0x289AB08E),
          Color(0x00000000),
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, wornCenter);

    // Secondary slightly off-center organic rub patch for natural realism.
    final wornPatch = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.08, 0.06),
        radius: 0.36,
        colors: const [Color(0x22DCE3C8), Color(0x00000000)],
      ).createShader(rect);
    canvas.drawRect(rect, wornPatch);

    // 3. Realistic woven cloth texture + subtle center play scuff fibers.
    _paintClothTexture(canvas, size);

    // 4. Recessed 3D inner shadow under the wooden frame rails.
    _paintRailShadows(canvas, rect);
  }

  void _paintClothTexture(Canvas canvas, Size size) {
    // Fine horizontal & vertical weave threads.
    final weftDark = Paint()
      ..color = const Color(0x0D000000)
      ..strokeWidth = 0.6;
    final warpLight = Paint()
      ..color = const Color(0x09FFFFFF)
      ..strokeWidth = 0.5;

    for (var y = 0.0; y < size.height; y += 3.2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), weftDark);
    }
    for (var x = 0.0; x < size.width; x += 4.2) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), warpLight);
    }

    // Seeded micro-fibers across the whole cloth.
    final rnd = math.Random(1958);
    final fiberDark = Paint()
      ..color = const Color(0x15000000)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    final fiberLight = Paint()
      ..color = const Color(0x10FFF6DC)
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;

    final fiberCount = ((size.width * size.height) / 130).clamp(300, 950).toInt();
    for (var i = 0; i < fiberCount; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final angle = rnd.nextDouble() * math.pi;
      final len = 1.6 + rnd.nextDouble() * 3.0;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(angle) * len, y + math.sin(angle) * len),
        i.isEven ? fiberDark : fiberLight,
      );
    }

    // Subtle worn micro-scuffs concentrated in the central playing zone.
    final scuffPaint = Paint()
      ..color = const Color(0x12E8E2C8)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width * 0.28;
    final ry = size.height * 0.28;
    for (var i = 0; i < 120; i++) {
      // Triangular distribution concentrates scuffs near the center.
      final ox = (rnd.nextDouble() - rnd.nextDouble()) * rx;
      final oy = (rnd.nextDouble() - rnd.nextDouble()) * ry;
      final angle = rnd.nextDouble() * math.pi;
      final len = 2.0 + rnd.nextDouble() * 4.5;
      final p1 = Offset(cx + ox, cy + oy);
      canvas.drawLine(
        p1,
        p1 + Offset(math.cos(angle) * len, math.sin(angle) * len),
        scuffPaint,
      );
    }
  }

  void _paintRailShadows(Canvas canvas, Rect rect) {
    final vignette = Paint()
      ..shader = RadialGradient(
        radius: 0.94,
        colors: const [Color(0x00000000), Color(0x5A000000)],
        stops: const [0.68, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);

    final topShadow = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x6B000000), Color(0x00000000)],
      ).createShader(Rect.fromLTWH(0, 0, rect.width, 15));
    canvas.drawRect(Rect.fromLTWH(0, 0, rect.width, 15), topShadow);

    final leftShadow = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0x4D000000), Color(0x00000000)],
      ).createShader(Rect.fromLTWH(0, 0, 12, rect.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, 12, rect.height), leftShadow);
  }

  @override
  bool shouldRepaint(_IraqiFeltPainter oldDelegate) =>
      oldDelegate.feltLight != feltLight || oldDelegate.feltDark != feltDark;
}