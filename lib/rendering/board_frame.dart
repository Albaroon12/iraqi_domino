import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/constants/app_colors.dart';
import 'board_theme.dart';

/// The playing surface of **المقهى** (`Al-Maqha`):
/// a carved wooden frame inlaid with Arabic geometric & arabesque gold
/// ornaments, surrounding customizable cloth, carpet, mosaic, marble, or
/// country-flag table themes.
class BoardFrame extends StatelessWidget {
  const BoardFrame({
    super.key,
    required this.child,
    this.theme,
    this.frameWidth = 13,
    this.feltLight = const Color(0xFF235C3D),
    this.feltDark = const Color(0xFF0E2C1C),
    this.frameLight = const Color(0xFF7B4E2D),
    this.frameDark = const Color(0xFF28150A),
  });

  final Widget child;
  final BoardTheme? theme;

  /// Thickness of the wooden frame, in pixels.
  final double frameWidth;

  /// Fallback felt colors when [theme] is omitted.
  final Color feltLight;
  final Color feltDark;

  /// Fallback frame wood colors when [theme] is omitted.
  final Color frameLight;
  final Color frameDark;

  @override
  Widget build(BuildContext context) {
    final activeTheme = theme;
    final effectiveFeltLight = activeTheme?.feltLight ?? feltLight;
    final effectiveFeltDark = activeTheme?.feltDark ?? feltDark;
    final effectiveFrameLight = activeTheme?.frameLight ?? frameLight;
    final effectiveFrameDark = activeTheme?.frameDark ?? frameDark;
    final motif = activeTheme?.motif ?? BoardMotifKind.classic;

    final innerRadius = BorderRadius.circular(8);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            effectiveFrameLight,
            Color.lerp(effectiveFrameLight, effectiveFrameDark, 0.5)!,
            effectiveFrameDark,
          ],
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
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _IraqiFeltPainter(
                        feltLight: effectiveFeltLight,
                        feltDark: effectiveFeltDark,
                        motif: motif,
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
/// wooden frame (corners and running side motifs).
class _IraqiFramePainter extends CustomPainter {
  const _IraqiFramePainter({required this.frameWidth});

  final double frameWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (frameWidth < 6) return;
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

/// Paints woven baize cloth, theme ornaments / country flag emblems, and
/// recessed 3D inner shadows.
class _IraqiFeltPainter extends CustomPainter {
  const _IraqiFeltPainter({
    required this.feltLight,
    required this.feltDark,
    required this.motif,
  });

  final Color feltLight;
  final Color feltDark;
  final BoardMotifKind motif;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Base baize cloth radial gradient.
    final feltPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.98,
        colors: [feltLight, Color.lerp(feltLight, feltDark, 0.55)!, feltDark],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, feltPaint);

    // 2. Soft patina center highlight.
    final wornCenter = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.58,
        colors: const [
          Color(0x2EFFFFFF),
          Color(0x14FFFFFF),
          Color(0x00000000),
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, wornCenter);

    // 3. Theme-specific ornament or country flag centerpiece.
    _paintCenterpiece(canvas, size);

    // 4. Woven cloth texture + micro-fibers.
    _paintClothTexture(canvas, size);

    // 5. Recessed 3D inner shadow under the wooden frame rails.
    _paintRailShadows(canvas, rect);
  }

  void _paintCenterpiece(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = math.min(size.width, size.height);

    switch (motif) {
      case BoardMotifKind.classic:
        break;
      case BoardMotifKind.damascusStar:
        _paintOctagram(canvas, center, minDim * 0.28);
      case BoardMotifKind.heritageCarpet:
        _paintHeritageCarpet(canvas, size, center, minDim);
      case BoardMotifKind.abbasidMosaic:
        _paintAbbasidMosaic(canvas, size, center, minDim);
      case BoardMotifKind.obsidianGold:
        _paintObsidianGoldVeins(canvas, size, center, minDim);
      case BoardMotifKind.flagIraq:
      case BoardMotifKind.flagSaudi:
      case BoardMotifKind.flagKuwait:
      case BoardMotifKind.flagUae:
      case BoardMotifKind.flagQatar:
      case BoardMotifKind.flagJordan:
      case BoardMotifKind.flagEgypt:
      case BoardMotifKind.flagPalestine:
      case BoardMotifKind.flagSyria:
      case BoardMotifKind.flagTurkey:
        _paintCountryFlagMedallion(canvas, center, minDim);
    }
  }

  void _paintOctagram(Canvas canvas, Offset center, double radius) {
    final stroke = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, radius, stroke);
    canvas.drawCircle(center, radius * 0.68, stroke);
    for (final angle in [0.0, math.pi / 4]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 1.32,
          height: radius * 1.32,
        ),
        stroke,
      );
      canvas.restore();
    }
  }

  void _paintHeritageCarpet(
    Canvas canvas,
    Size size,
    Offset center,
    double minDim,
  ) {
    final borderPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final innerFill = Paint()
      ..color = const Color(0x33D4AF37)
      ..style = PaintingStyle.fill;

    final inset = math.max(8.0, minDim * 0.07);
    canvas.drawRect(
      Rect.fromLTWH(
        inset,
        inset,
        math.max(0, size.width - inset * 2),
        math.max(0, size.height - inset * 2),
      ),
      borderPaint,
    );

    final r = minDim * 0.26;
    final diamond = Path()
      ..moveTo(center.dx, center.dy - r * 1.25)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx, center.dy + r * 1.25)
      ..lineTo(center.dx - r, center.dy)
      ..close();
    canvas.drawPath(diamond, innerFill);
    canvas.drawPath(diamond, borderPaint);
    _paintOctagram(canvas, center, r * 0.62);
  }

  void _paintAbbasidMosaic(
    Canvas canvas,
    Size size,
    Offset center,
    double minDim,
  ) {
    final gold = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final r = minDim * 0.25;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p = center + Offset(math.cos(a) * r * 0.55, math.sin(a) * r * 0.55);
      canvas.drawCircle(p, r * 0.55, gold);
    }
    canvas.drawCircle(center, r * 1.12, gold);
  }

  void _paintObsidianGoldVeins(
    Canvas canvas,
    Size size,
    Offset center,
    double minDim,
  ) {
    final vein = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final rnd = math.Random(77);
    for (var i = 0; i < 6; i++) {
      final path = Path()..moveTo(0, size.height * (0.12 + i * 0.15));
      var x = 0.0;
      var y = size.height * (0.12 + i * 0.15);
      while (x < size.width) {
        x += size.width / 5;
        y += (rnd.nextDouble() - 0.5) * minDim * 0.14;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, vein);
    }
    _paintOctagram(canvas, center, minDim * 0.24);
  }

  void _paintCountryFlagMedallion(
    Canvas canvas,
    Offset center,
    double minDim,
  ) {
    final flagW = (minDim * 0.58).clamp(36.0, 210.0);
    final flagH = flagW * 0.64;
    final flagRect = Rect.fromCenter(
      center: center,
      width: flagW,
      height: flagH,
    );
    final rrect = RRect.fromRectAndRadius(
      flagRect,
      Radius.circular(flagW * 0.08),
    );

    canvas.save();
    canvas.clipRRect(rrect);

    // Subtle cloth-blended alpha (0.58) so domino tiles on top remain crisp!
    const alpha = 0.58;
    Color c(int hex) => Color(hex).withValues(alpha: alpha);

    void drawTriHorizontal(Color top, Color mid, Color bot) {
      final h3 = flagRect.height / 3;
      canvas.drawRect(
        Rect.fromLTWH(flagRect.left, flagRect.top, flagRect.width, h3 + 0.5),
        Paint()..color = top,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          flagRect.left,
          flagRect.top + h3,
          flagRect.width,
          h3 + 0.5,
        ),
        Paint()..color = mid,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          flagRect.left,
          flagRect.top + 2 * h3,
          flagRect.width,
          h3,
        ),
        Paint()..color = bot,
      );
    }

    switch (motif) {
      case BoardMotifKind.flagIraq:
        drawTriHorizontal(c(0xFFCE1126), c(0xFFF7F7F7), c(0xFF0A0A0A));
        // Stylized emerald Takbir / central band strokes
        final green = Paint()
          ..color = c(0xFF007A3D)
          ..strokeWidth = (flagH * 0.055).clamp(1.4, 4.0)
          ..strokeCap = StrokeCap.round;
        final cy = center.dy;
        canvas.drawLine(
          Offset(center.dx - flagW * 0.20, cy + flagH * 0.05),
          Offset(center.dx + flagW * 0.20, cy + flagH * 0.05),
          green,
        );
        for (final dx in [-0.15, -0.05, 0.06, 0.16]) {
          canvas.drawLine(
            Offset(center.dx + flagW * dx, cy - flagH * 0.08),
            Offset(center.dx + flagW * dx, cy + flagH * 0.05),
            green,
          );
        }

      case BoardMotifKind.flagSaudi:
        canvas.drawRect(flagRect, Paint()..color = c(0xFF006C35));
        final white = Paint()
          ..color = c(0xFFFFFFFF)
          ..strokeWidth = (flagH * 0.048).clamp(1.2, 3.5)
          ..strokeCap = StrokeCap.round;
        // Sword + stylized creed line above it
        canvas.drawLine(
          Offset(center.dx - flagW * 0.22, center.dy + flagH * 0.12),
          Offset(center.dx + flagW * 0.22, center.dy + flagH * 0.12),
          white,
        );
        canvas.drawLine(
          Offset(center.dx - flagW * 0.24, center.dy - flagH * 0.04),
          Offset(center.dx + flagW * 0.24, center.dy - flagH * 0.04),
          white,
        );

      case BoardMotifKind.flagKuwait:
        drawTriHorizontal(c(0xFF007A3D), c(0xFFF7F7F7), c(0xFFCE1126));
        final trap = Path()
          ..moveTo(flagRect.left, flagRect.top)
          ..lineTo(flagRect.left + flagW * 0.26, flagRect.top + flagH / 3)
          ..lineTo(flagRect.left + flagW * 0.26, flagRect.bottom - flagH / 3)
          ..lineTo(flagRect.left, flagRect.bottom)
          ..close();
        canvas.drawPath(trap, Paint()..color = c(0xFF0A0A0A));

      case BoardMotifKind.flagUae:
        drawTriHorizontal(c(0xFF00732F), c(0xFFF7F7F7), c(0xFF0A0A0A));
        canvas.drawRect(
          Rect.fromLTWH(flagRect.left, flagRect.top, flagW * 0.25, flagH),
          Paint()..color = c(0xFFFF0000),
        );

      case BoardMotifKind.flagQatar:
        canvas.drawRect(flagRect, Paint()..color = c(0xFF8A1538));
        final serration = Path()
          ..moveTo(flagRect.left, flagRect.top)
          ..lineTo(flagRect.left + flagW * 0.28, flagRect.top);
        const teeth = 9;
        final stepY = flagH / teeth;
        for (var i = 0; i < teeth; i++) {
          serration.lineTo(
            flagRect.left + flagW * 0.36,
            flagRect.top + (i + 0.5) * stepY,
          );
          serration.lineTo(
            flagRect.left + flagW * 0.28,
            flagRect.top + (i + 1) * stepY,
          );
        }
        serration
          ..lineTo(flagRect.left, flagRect.bottom)
          ..close();
        canvas.drawPath(serration, Paint()..color = c(0xFFF7F7F7));

      case BoardMotifKind.flagJordan:
        drawTriHorizontal(c(0xFF0A0A0A), c(0xFFF7F7F7), c(0xFF007A3D));
        final tri = Path()
          ..moveTo(flagRect.left, flagRect.top)
          ..lineTo(flagRect.left + flagW * 0.44, center.dy)
          ..lineTo(flagRect.left, flagRect.bottom)
          ..close();
        canvas.drawPath(tri, Paint()..color = c(0xFFCE1126));
        canvas.drawCircle(
          Offset(flagRect.left + flagW * 0.14, center.dy),
          flagH * 0.055,
          Paint()..color = c(0xFFFFFFFF),
        );

      case BoardMotifKind.flagEgypt:
        drawTriHorizontal(c(0xFFCE1126), c(0xFFF7F7F7), c(0xFF0A0A0A));
        // Golden Eagle of Saladin silhouette
        canvas.drawCircle(
          center,
          flagH * 0.10,
          Paint()..color = c(0xFFC09300),
        );

      case BoardMotifKind.flagPalestine:
        drawTriHorizontal(c(0xFF0A0A0A), c(0xFFF7F7F7), c(0xFF007A3D));
        final tri = Path()
          ..moveTo(flagRect.left, flagRect.top)
          ..lineTo(flagRect.left + flagW * 0.42, center.dy)
          ..lineTo(flagRect.left, flagRect.bottom)
          ..close();
        canvas.drawPath(tri, Paint()..color = c(0xFFCE1126));

      case BoardMotifKind.flagSyria:
        drawTriHorizontal(c(0xFFCE1126), c(0xFFF7F7F7), c(0xFF0A0A0A));
        for (final dx in [-0.14, 0.14]) {
          canvas.drawCircle(
            Offset(center.dx + flagW * dx, center.dy),
            flagH * 0.06,
            Paint()..color = c(0xFF007A3D),
          );
        }

      case BoardMotifKind.flagTurkey:
        canvas.drawRect(flagRect, Paint()..color = c(0xFFE30A17));
        final cCenter = Offset(center.dx - flagW * 0.06, center.dy);
        canvas.drawCircle(
          cCenter,
          flagH * 0.22,
          Paint()..color = c(0xFFFFFFFF),
        );
        canvas.drawCircle(
          cCenter + Offset(flagH * 0.06, 0),
          flagH * 0.175,
          Paint()..color = c(0xFFE30A17),
        );
        canvas.drawCircle(
          Offset(center.dx + flagW * 0.12, center.dy),
          flagH * 0.065,
          Paint()..color = c(0xFFFFFFFF),
        );

      default:
        break;
    }

    canvas.restore();

    // Ornate double-gold border around the woven flag emblem.
    final goldBorder = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRRect(rrect, goldBorder);
    canvas.drawRRect(
      rrect.inflate(3.5),
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  void _paintClothTexture(Canvas canvas, Size size) {
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

    final rnd = math.Random(1958);
    final fiberDark = Paint()
      ..color = const Color(0x15000000)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    final fiberLight = Paint()
      ..color = const Color(0x10FFF6DC)
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;

    final fiberCount =
        ((size.width * size.height) / 130).clamp(120, 850).toInt();
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
      oldDelegate.feltLight != feltLight ||
      oldDelegate.feltDark != feltDark ||
      oldDelegate.motif != motif;
}
