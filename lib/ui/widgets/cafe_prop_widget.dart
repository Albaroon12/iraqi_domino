import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';

/// Custom-painted miniature Iraqi Café table item (`ShopCategory.cafeProps`)
/// displayed beside the player's seat during matches and in Shop/Profile previews.
class CafePropWidget extends StatelessWidget {
  const CafePropWidget({
    super.key,
    required this.propId,
    this.size = 34,
    this.onTap,
  });

  final String propId;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final painted = SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(
        child: CustomPaint(painter: _CafePropPainter(propId: propId)),
      ),
    );
    if (onTap == null) return painted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: painted,
    );
  }
}

class _CafePropPainter extends CustomPainter {
  const _CafePropPainter({required this.propId});

  final String propId;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final brass = Paint()..color = const Color(0xFFD4AF37);
    final darkRim = Paint()
      ..color = const Color(0xFF3A2010)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    switch (propId) {
      case 'prop_loomi_tea':
        _paintEstekan(
          canvas,
          w,
          h,
          teaColor: const Color(0xFF4A1F0A),
          saucerColor: const Color(0xFFC0C7D1),
        );

      case 'prop_kleicha_plate':
        // Engraved brass plate + 3 golden date kleicha pastries
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.68),
            width: w * 0.84,
            height: h * 0.42,
          ),
          brass,
        );
        for (final pos in [
          Offset(w * 0.38, h * 0.60),
          Offset(w * 0.62, h * 0.60),
          Offset(w * 0.50, h * 0.48),
        ]) {
          canvas.drawCircle(
            pos,
            w * 0.14,
            Paint()..color = const Color(0xFFE0A952),
          );
          canvas.drawCircle(
            pos,
            w * 0.06,
            Paint()..color = const Color(0xFF5C2E0E),
          );
        }

      case 'prop_arabic_coffee':
        // Golden Dallah coffee pot + white porcelain finjan
        final dallah = Path()
          ..moveTo(w * 0.34, h * 0.82)
          ..lineTo(w * 0.58, h * 0.82)
          ..lineTo(w * 0.52, h * 0.40)
          ..lineTo(w * 0.40, h * 0.40)
          ..close();
        canvas.drawPath(dallah, brass);
        // Curved Dallah spout (left)
        final spout = Path()
          ..moveTo(w * 0.40, h * 0.52)
          ..quadraticBezierTo(w * 0.18, h * 0.44, w * 0.22, h * 0.32)
          ..lineTo(w * 0.30, h * 0.42)
          ..close();
        canvas.drawPath(spout, brass);
        // Finial lid
        canvas.drawCircle(Offset(w * 0.46, h * 0.34), w * 0.06, brass);
        // Small white finjan cup beside it
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.64, h * 0.64, w * 0.20, h * 0.18),
            Radius.circular(w * 0.05),
          ),
          Paint()..color = const Color(0xFFFBF6E9),
        );

      case 'prop_amber_misbaha':
        // Loop of glowing honey-amber beads + silver tassel
        final center = Offset(w * 0.48, h * 0.50);
        final rx = w * 0.28;
        final ry = h * 0.26;
        for (var i = 0; i < 13; i++) {
          final a = (2 * math.pi * i / 13);
          final p = center + Offset(math.cos(a) * rx, math.sin(a) * ry);
          canvas.drawCircle(
            p,
            w * 0.065,
            Paint()..color = const Color(0xFFF5A623),
          );
          canvas.drawCircle(
            p - Offset(w * 0.015, h * 0.015),
            w * 0.022,
            Paint()..color = const Color(0xFFFFF3C4),
          );
        }
        // Silver karkoosha tassel
        canvas.drawLine(
          Offset(w * 0.72, h * 0.62),
          Offset(w * 0.86, h * 0.84),
          Paint()
            ..color = const Color(0xFFD8E2EB)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );

      case 'prop_brass_samovar':
        // Traditional brass samovar urn + base + steam
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.84),
              width: w * 0.44,
              height: h * 0.12,
            ),
            Radius.circular(w * 0.04),
          ),
          brass,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.56),
            width: w * 0.48,
            height: h * 0.46,
          ),
          brass,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.56),
            width: w * 0.48,
            height: h * 0.46,
          ),
          darkRim,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.30),
            width: w * 0.22,
            height: h * 0.12,
          ),
          brass,
        );
        _paintSteam(canvas, w, h * 0.22);

      case 'prop_oud_burner':
        // Ornate golden mabkhara incense burner + aromatic smoke wisps
        final cup = Path()
          ..moveTo(w * 0.26, h * 0.42)
          ..lineTo(w * 0.74, h * 0.42)
          ..lineTo(w * 0.62, h * 0.64)
          ..lineTo(w * 0.38, h * 0.64)
          ..close();
        canvas.drawPath(cup, brass);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.72),
            width: w * 0.14,
            height: h * 0.14,
          ),
          brass,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.83),
              width: w * 0.46,
              height: h * 0.10,
            ),
            Radius.circular(w * 0.03),
          ),
          brass,
        );
        // Glowing ember
        canvas.drawCircle(
          Offset(w * 0.5, h * 0.40),
          w * 0.08,
          Paint()..color = const Color(0xFFFF5722),
        );
        _paintSteam(canvas, w, h * 0.34);

      case 'prop_estekan_tea':
      default:
        _paintEstekan(
          canvas,
          w,
          h,
          teaColor: const Color(0xFFB52B18),
          saucerColor: const Color(0xFFD4AF37),
        );
    }
  }

  void _paintEstekan(
    Canvas canvas,
    double w,
    double h, {
    required Color teaColor,
    required Color saucerColor,
  }) {
    // Saucer
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.80),
        width: w * 0.74,
        height: h * 0.20,
      ),
      Paint()..color = saucerColor,
    );

    // Waist-curved Iraqi Estekan glass
    final glass = Path()
      ..moveTo(w * 0.33, h * 0.34)
      ..quadraticBezierTo(w * 0.40, h * 0.56, w * 0.35, h * 0.78)
      ..lineTo(w * 0.65, h * 0.78)
      ..quadraticBezierTo(w * 0.60, h * 0.56, w * 0.67, h * 0.34)
      ..close();
    canvas.drawPath(glass, Paint()..color = teaColor);
    canvas.drawPath(
      glass,
      Paint()
        ..color = const Color(0xCCFFF8E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Gold rim at top of Estekan
    canvas.drawLine(
      Offset(w * 0.33, h * 0.35),
      Offset(w * 0.67, h * 0.35),
      Paint()
        ..color = AppColors.gold
        ..strokeWidth = 1.8,
    );

    _paintSteam(canvas, w, h * 0.28);
  }

  void _paintSteam(Canvas canvas, double w, double baseY) {
    final steam = Paint()
      ..color = const Color(0x77FFF8E7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final dx in [0.43, 0.57]) {
      final p = Path()
        ..moveTo(w * dx, baseY)
        ..quadraticBezierTo(
          w * (dx - 0.05),
          baseY - w * 0.10,
          w * (dx + 0.03),
          baseY - w * 0.20,
        );
      canvas.drawPath(p, steam);
    }
  }

  @override
  bool shouldRepaint(_CafePropPainter oldDelegate) =>
      oldDelegate.propId != propId;
}

/// Olive-gold tinted stadium currency pill matching the reference top-left bar.
class CafeDinarPill extends StatelessWidget {
  const CafeDinarPill({
    super.key,
    required this.amount,
    required this.isAr,
    this.compact = false,
    this.showCurrencyWord = false,
  });

  final int amount;
  final bool isAr;
  final bool compact;
  final bool showCurrencyWord;

  @override
  Widget build(BuildContext context) {
    final label = showCurrencyWord
        ? (isAr ? '$amount دينار' : '$amount D')
        : '$amount';

    return Container(
      height: compact ? 34 : 38,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13),
      decoration: BoxDecoration(
        color: const Color(0x30E7BB50),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xAAE7BB50),
          width: 1.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFFF4F7F6),
              fontSize: compact ? 12.5 : 13.5,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          SizedBox(width: compact ? 6 : 7),
          Container(
            width: compact ? 17 : 19,
            height: compact ? 17 : 19,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF7CB62), Color(0xFFD6AD41)],
              ),
            ),
            child: Icon(
              Icons.monetization_on_rounded,
              size: compact ? 13 : 15,
              color: const Color(0xFF231304),
            ),
          ),
        ],
      ),
    );
  }
}
