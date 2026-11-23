import 'package:material_ui/material_ui.dart';

import '../../ai/ai_persona.dart';

/// Renders a stylized, custom-painted portrait medallion for an [AiPersona].
class AiPersonaAvatar extends StatelessWidget {
  const AiPersonaAvatar({
    super.key,
    required this.persona,
    required this.size,
  });

  final AiPersona persona;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CustomPaint(
          painter: _AiPersonaPainter(persona),
        ),
      ),
    );
  }
}

class _AiPersonaPainter extends CustomPainter {
  const _AiPersonaPainter(this.persona);

  final AiPersona persona;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final primary = Color(persona.primaryColorHex);
    final accent = Color(persona.accentColorHex);

    // 1. Medallion radial background.
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.3),
        radius: 0.95,
        colors: [
          Color.lerp(primary, Colors.white, 0.16)!,
          primary,
          Color.lerp(primary, Colors.black, 0.45)!,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Stylized shoulders.
    final shoulderPaint = Paint()
      ..color = Color.lerp(accent, Colors.black, 0.35)!;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.98),
        width: w * 0.78,
        height: h * 0.52,
      ),
      shoulderPaint,
    );

    // 3. Warm face silhouette.
    final skinPaint = Paint()..color = const Color(0xFFEAD2B5);
    final headCenter = Offset(w * 0.5, h * 0.46);
    final headRadius = w * 0.22;
    canvas.drawCircle(headCenter, headRadius, skinPaint);

    // Subtle eyes.
    final featurePaint = Paint()
      ..color = const Color(0xFF2B1B12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(w * 0.43, h * 0.46),
      w * 0.025,
      featurePaint,
    );
    canvas.drawCircle(
      Offset(w * 0.57, h * 0.46),
      w * 0.025,
      featurePaint,
    );

    // 4. Distinctive character accessory per AiAvatarStyle.
    final accentPaint = Paint()..color = accent;
    final darkPaint = Paint()..color = const Color(0xFF241710);

    switch (persona.avatarStyle) {
      case AiAvatarStyle.sidara:
        // Iconic Iraqi pointed Sidara cap.
        final path = Path()
          ..moveTo(w * 0.27, h * 0.36)
          ..lineTo(w * 0.50, h * 0.16)
          ..lineTo(w * 0.73, h * 0.36)
          ..close();
        canvas.drawPath(path, darkPaint);
      case AiAvatarStyle.glasses:
        final framePaint = Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.045;
        canvas.drawCircle(Offset(w * 0.42, h * 0.46), w * 0.065, framePaint);
        canvas.drawCircle(Offset(w * 0.58, h * 0.46), w * 0.065, framePaint);
        canvas.drawLine(
          Offset(w * 0.485, h * 0.46),
          Offset(w * 0.515, h * 0.46),
          framePaint,
        );
      case AiAvatarStyle.mustache:
        final mPath = Path()
          ..moveTo(w * 0.36, h * 0.55)
          ..quadraticBezierTo(w * 0.50, h * 0.50, w * 0.64, h * 0.55)
          ..quadraticBezierTo(w * 0.50, h * 0.60, w * 0.36, h * 0.55);
        canvas.drawPath(mPath, darkPaint);
      case AiAvatarStyle.keffiyeh:
        // Traditional headscarf + black agal ring.
        canvas.drawArc(
          Rect.fromCircle(center: headCenter, radius: headRadius * 1.18),
          3.14,
          3.14,
          true,
          Paint()..color = const Color(0xFFF5EFE6),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.31),
              width: w * 0.50,
              height: h * 0.065,
            ),
            Radius.circular(w * 0.03),
          ),
          darkPaint,
        );
      case AiAvatarStyle.classic:
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(w * 0.5, h * 0.42),
            radius: headRadius * 1.05,
          ),
          3.2,
          3.0,
          true,
          darkPaint,
        );
      case AiAvatarStyle.beard:
        canvas.drawArc(
          Rect.fromCircle(center: headCenter, radius: headRadius * 0.98),
          0.25,
          2.64,
          false,
          Paint()
            ..color = const Color(0xFF2B1B12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.065
            ..strokeCap = StrokeCap.round,
        );
      case AiAvatarStyle.headband:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.34),
              width: w * 0.46,
              height: h * 0.075,
            ),
            Radius.circular(w * 0.04),
          ),
          accentPaint,
        );
      case AiAvatarStyle.fez:
        final fez = Path()
          ..moveTo(w * 0.33, h * 0.34)
          ..lineTo(w * 0.38, h * 0.17)
          ..lineTo(w * 0.62, h * 0.17)
          ..lineTo(w * 0.67, h * 0.34)
          ..close();
        canvas.drawPath(fez, Paint()..color = const Color(0xFFA62626));
      case AiAvatarStyle.scarf:
        // Graceful wrap around head and shoulders.
        final wrapPaint = Paint()
          ..color = accent.withValues(alpha: 0.88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.085;
        canvas.drawCircle(headCenter, headRadius * 1.12, wrapPaint);
      case AiAvatarStyle.crown:
        final crown = Path()
          ..moveTo(w * 0.32, h * 0.32)
          ..lineTo(w * 0.35, h * 0.19)
          ..lineTo(w * 0.44, h * 0.27)
          ..lineTo(w * 0.50, h * 0.16)
          ..lineTo(w * 0.56, h * 0.27)
          ..lineTo(w * 0.65, h * 0.19)
          ..lineTo(w * 0.68, h * 0.32)
          ..close();
        canvas.drawPath(crown, accentPaint);
    }

    // Subtle inner rim highlight.
    canvas.drawCircle(
      center,
      w * 0.48,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_AiPersonaPainter oldDelegate) =>
      oldDelegate.persona.id != persona.id;
}
