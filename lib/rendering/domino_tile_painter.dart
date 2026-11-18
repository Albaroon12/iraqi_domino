import 'package:flutter/widgets.dart';

import 'tile_skin.dart';

/// Paints one domino tile (always vertical, aspect ratio 1:2).
/// [top] and [bottom] are the pip counts of the two halves (0 to 6).
/// All colors come from [skin].
class DominoTilePainter extends CustomPainter {
  const DominoTilePainter({
    required this.top,
    required this.bottom,
    required this.skin,
  });

  final int top;
  final int bottom;
  final TileSkin skin;

  /// Pip positions on a 3x3 grid inside one half: Offset(column, row).
  /// Column and row are 0 (start), 1 (middle) or 2 (end).
  static const Map<int, List<Offset>> _pipLayouts = {
    0: [],
    1: [Offset(1, 1)],
    2: [Offset(0, 0), Offset(2, 2)],
    3: [Offset(0, 0), Offset(1, 1), Offset(2, 2)],
    4: [Offset(0, 0), Offset(2, 0), Offset(0, 2), Offset(2, 2)],
    5: [Offset(0, 0), Offset(2, 0), Offset(1, 1), Offset(0, 2), Offset(2, 2)],
    6: [
      Offset(0, 0),
      Offset(2, 0),
      Offset(0, 1),
      Offset(2, 1),
      Offset(0, 2),
      Offset(2, 2),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyRect = Rect.fromLTWH(0, 0, w, h);
    final body = RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.14));

    _paintShadow(canvas, body, w);
    _paintBody(canvas, body, bodyRect);
    _paintBevel(canvas, body, bodyRect, w);
    _paintDivider(canvas, w, h);
    _paintPips(canvas, top, yOffset: 0, w: w, halfHeight: h / 2);
    _paintPips(canvas, bottom, yOffset: h / 2, w: w, halfHeight: h / 2);
  }

  /// Soft blurred shadow under the tile, shifted down and right.
  void _paintShadow(Canvas canvas, RRect body, double w) {
    final paint = Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.09);
    canvas.drawRRect(body.shift(Offset(w * 0.04, w * 0.07)), paint);
  }

  /// Tile body with a diagonal gradient taken from the skin.
  void _paintBody(Canvas canvas, RRect body, Rect rect) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [skin.bodyLight, skin.bodyDark],
      ).createShader(rect);
    canvas.drawRRect(body, paint);
  }

  /// Thin inner edge: bright on the top-left, dark on the bottom-right.
  void _paintBevel(Canvas canvas, RRect body, Rect rect, double w) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [skin.bevelLight, skin.bevelDark],
      ).createShader(rect);
    canvas.drawRRect(body.deflate(w * 0.03), paint);
  }

  /// Engraved center line: a dark groove with a light edge under it.
  void _paintDivider(Canvas canvas, double w, double h) {
    final y = h / 2;
    final groove = Paint()
      ..color = skin.grooveColor
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;
    final edge = Paint()
      ..color = skin.grooveEdge
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.14, y), Offset(w * 0.86, y), groove);
    canvas.drawLine(
      Offset(w * 0.14, y + w * 0.025),
      Offset(w * 0.86, y + w * 0.025),
      edge,
    );
  }

  /// Draws the pips of one half (a square of size w x halfHeight).
  void _paintPips(
    Canvas canvas,
    int count, {
    required double yOffset,
    required double w,
    required double halfHeight,
  }) {
    final padX = w * 0.24;
    final padY = halfHeight * 0.24;
    final stepX = (w - 2 * padX) / 2;
    final stepY = (halfHeight - 2 * padY) / 2;
    final radius = w * 0.085;

    for (final cell in _pipLayouts[count]!) {
      final center = Offset(
        padX + cell.dx * stepX,
        yOffset + padY + cell.dy * stepY,
      );

      // Ring just below the pip makes it look engraved.
      canvas.drawCircle(
        center.translate(0, radius * 0.3),
        radius,
        Paint()..color = skin.pipRim,
      );

      // The pip itself: radial gradient from the skin.
      final pipRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: [skin.pipHighlight, skin.pipDark],
          ).createShader(pipRect),
      );
    }
  }

  @override
  bool shouldRepaint(DominoTilePainter oldDelegate) =>
      oldDelegate.top != top ||
      oldDelegate.bottom != bottom ||
      oldDelegate.skin != skin;
}
