import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';

/// Wraps any circular avatar widget with a custom-painted Shop Avatar Frame
/// (`ShopCategory.frames`).
class CafeAvatarFrame extends StatelessWidget {
  const CafeAvatarFrame({
    super.key,
    required this.frameId,
    required this.size,
    required this.child,
  });

  final String frameId;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ringPad = (size * 0.10).clamp(3.0, 7.0);
    final total = size + ringPad * 2;

    return SizedBox(
      width: total,
      height: total,
      child: CustomPaint(
        foregroundPainter: _AvatarFramePainter(frameId: frameId),
        child: Center(
          child: SizedBox(
            width: size,
            height: size,
            child: ClipOval(child: child),
          ),
        ),
      ),
    );
  }
}

class _AvatarFramePainter extends CustomPainter {
  const _AvatarFramePainter({required this.frameId});

  final String frameId;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2.0;
    final rect = Rect.fromCircle(center: center, radius: r);

    switch (frameId) {
      case 'frame_silver_engraved':
        final ring = Paint()
          ..shader = const SweepGradient(
            colors: [
              Color(0xFFE8EEF5),
              Color(0xFF8C9AA8),
              Color(0xFFFFFFFF),
              Color(0xFF7B8896),
              Color(0xFFE8EEF5),
            ],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (size.width * 0.065).clamp(2.2, 4.5);
        canvas.drawCircle(center, r, ring);
        _drawBeadDots(canvas, center, r, 12, const Color(0xFFFFFFFF), 1.4);

      case 'frame_iraq_pride':
        final strokeW = (size.width * 0.07).clamp(2.4, 4.6);
        canvas.drawArc(
          rect,
          -math.pi * 0.85,
          math.pi * 0.70,
          false,
          Paint()
            ..color = const Color(0xFFCE1126)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW,
        );
        canvas.drawArc(
          rect,
          -math.pi * 0.15,
          math.pi * 0.30,
          false,
          Paint()
            ..color = const Color(0xFFF5F5F5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW,
        );
        canvas.drawArc(
          rect,
          math.pi * 0.85,
          math.pi * 0.30,
          false,
          Paint()
            ..color = const Color(0xFFF5F5F5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW,
        );
        canvas.drawArc(
          rect,
          math.pi * 0.15,
          math.pi * 0.70,
          false,
          Paint()
            ..color = const Color(0xFF141414)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW,
        );
        _drawBeadDots(canvas, center, r, 3, const Color(0xFF009B4D), 2.1);

      case 'frame_royal_gold':
        final ring = Paint()
          ..shader = const SweepGradient(
            colors: [
              Color(0xFFFFE57F),
              Color(0xFFB8860B),
              Color(0xFFFFF8DC),
              Color(0xFFD4AF37),
              Color(0xFFFFE57F),
            ],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (size.width * 0.075).clamp(2.5, 5.0);
        canvas.drawCircle(center, r, ring);
        _drawCrownCrest(canvas, center, r, const Color(0xFFFFD54F));

      case 'frame_amber_fire':
        final glow = Paint()
          ..color = const Color(0x55FF9800)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (size.width * 0.12).clamp(4.0, 8.0);
        canvas.drawCircle(center, r, glow);
        final ring = Paint()
          ..color = const Color(0xFFFFB300)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (size.width * 0.06).clamp(2.0, 4.0);
        canvas.drawCircle(center, r, ring);
        _drawBeadDots(canvas, center, r, 10, const Color(0xFFFFE082), 2.4);

      case 'frame_emerald_sultan':
        final ring = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2ECC71), Color(0xFF0B5345)],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (size.width * 0.075).clamp(2.5, 5.0);
        canvas.drawCircle(center, r, ring);
        _drawBeadDots(canvas, center, r, 4, AppColors.gold, 2.8);

      case 'frame_diamond_sheikh':
        final halo = Paint()
          ..color = const Color(0x6680D8FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (size.width * 0.13).clamp(4.5, 8.5);
        canvas.drawCircle(center, r, halo);
        final ring = Paint()
          ..shader = const SweepGradient(
            colors: [
              Color(0xFFE1F5FE),
              Color(0xFF4FC3F7),
              Color(0xFFFFFFFF),
              Color(0xFFFFD54F),
              Color(0xFFE1F5FE),
            ],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (size.width * 0.075).clamp(2.6, 5.2);
        canvas.drawCircle(center, r, ring);
        _drawBeadDots(canvas, center, r, 8, const Color(0xFFFFFFFF), 2.2);
        _drawCrownCrest(canvas, center, r, const Color(0xFF80D8FF));

      case 'frame_none':
      default:
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = AppColors.gold.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
    }
  }

  void _drawBeadDots(
    Canvas canvas,
    Offset center,
    double radius,
    int count,
    Color color,
    double dotRadius,
  ) {
    final paint = Paint()..color = color;
    for (var i = 0; i < count; i++) {
      final a = -math.pi / 2 + (2 * math.pi * i / count);
      final p = center + Offset(math.cos(a) * radius, math.sin(a) * radius);
      canvas.drawCircle(p, dotRadius, paint);
    }
  }

  void _drawCrownCrest(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final top = Offset(center.dx, center.dy - radius);
    final w = (radius * 0.36).clamp(5.0, 13.0);
    final h = (radius * 0.24).clamp(4.0, 9.0);
    final crown = Path()
      ..moveTo(top.dx - w, top.dy + 1.5)
      ..lineTo(top.dx - w * 0.75, top.dy - h * 0.7)
      ..lineTo(top.dx - w * 0.25, top.dy - h * 0.2)
      ..lineTo(top.dx, top.dy - h)
      ..lineTo(top.dx + w * 0.25, top.dy - h * 0.2)
      ..lineTo(top.dx + w * 0.75, top.dy - h * 0.7)
      ..lineTo(top.dx + w, top.dy + 1.5)
      ..close();
    canvas.drawPath(crown, Paint()..color = color);
    canvas.drawPath(
      crown,
      Paint()
        ..color = const Color(0xFF241409)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_AvatarFramePainter oldDelegate) =>
      oldDelegate.frameId != frameId;
}
