import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'table_skin.dart';

/// Paints a wooden table: planks, grain, light, vignette and a frame.
class WoodTablePainter extends CustomPainter {
  const WoodTablePainter({required this.skin});

  final TableSkin skin;

  static const int _planks = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Same seed every time, so the wood looks identical on each repaint.
    final rnd = math.Random(skin.grainSeed);

    _paintBase(canvas, rect);
    _paintPlanks(canvas, size, rnd);
    _paintGrain(canvas, size, rnd);
    _paintLight(canvas, rect);
    _paintVignette(canvas, rect);
    _paintRim(canvas, rect);
  }

  /// Vertical gradient from the light wood to the dark wood.
  void _paintBase(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [skin.woodLight, skin.woodDark],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  /// Vertical planks: each one slightly darker, with a seam between them.
  void _paintPlanks(Canvas canvas, Size size, math.Random rnd) {
    final plankWidth = size.width / _planks;

    for (var i = 0; i < _planks; i++) {
      final plankRect =
          Rect.fromLTWH(i * plankWidth, 0, plankWidth, size.height);
      canvas.drawRect(
        plankRect,
        Paint()..color = Color.fromRGBO(0, 0, 0, rnd.nextDouble() * 0.12),
      );

      if (i == 0) continue;
      final x = i * plankWidth;
      // Dark seam with a thin light line next to it.
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = skin.grainDark.withValues(alpha: 0.9)
          ..strokeWidth = 2.5,
      );
      canvas.drawLine(
        Offset(x + 2, 0),
        Offset(x + 2, size.height),
        Paint()
          ..color = const Color(0x22FFFFFF)
          ..strokeWidth = 1,
      );
    }
  }

  /// Many thin wavy vertical lines that imitate wood grain.
  void _paintGrain(Canvas canvas, Size size, math.Random rnd) {
    final lineCount = (size.width / 3).round();

    for (var i = 0; i < lineCount; i++) {
      final x0 = rnd.nextDouble() * size.width;
      final thickness = 0.6 + rnd.nextDouble() * 1.8;
      final amplitude = 1.5 + rnd.nextDouble() * 7;
      final frequency = 0.004 + rnd.nextDouble() * 0.01;
      final phase = rnd.nextDouble() * 2 * math.pi;
      final alpha = 0.05 + rnd.nextDouble() * 0.16;
      final base = rnd.nextBool() ? skin.grainDark : skin.grainLight;

      final path = Path()..moveTo(x0, 0);
      for (double y = 14; y <= size.height; y += 14) {
        path.lineTo(x0 + math.sin(y * frequency + phase) * amplitude, y);
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round
          ..color = base.withValues(alpha: alpha),
      );
    }
  }

  /// Warm light from above the center of the table.
  void _paintLight(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.35),
        radius: 0.9,
        colors: [Color(0x28FFE2B0), Color(0x00FFE2B0)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  /// Darkens the edges so the eye goes to the center.
  void _paintVignette(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..shader = RadialGradient(
        radius: 1.05,
        colors: [const Color(0x00000000), skin.vignette],
        stops: const [0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  /// Table frame with a thin highlight on its inner edge.
  void _paintRim(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect.deflate(9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = skin.rim,
    );
    canvas.drawRect(
      rect.deflate(18.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x33FFFFFF),
    );
  }

  @override
  bool shouldRepaint(WoodTablePainter oldDelegate) =>
      oldDelegate.skin != skin;
}