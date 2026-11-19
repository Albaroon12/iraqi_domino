import 'package:flutter/widgets.dart';

import '../core/constants/app_colors.dart';

/// The square playing surface: a carved wooden frame, a thin gold line,
/// and a colored felt inside. Game content goes in [child].
///
/// It only decorates: it fills whatever size its parent gives it, so the
/// game screen decides the square's size. Colors are constructor values so
/// a future "table skin" can restyle it without touching the layout.
class BoardFrame extends StatelessWidget {
  const BoardFrame({
    super.key,
    required this.child,
    this.frameWidth = 10,
    this.feltLight = const Color(0xFF2A6B47),
    this.feltDark = const Color(0xFF123824),
    this.frameLight = const Color(0xFF7A5030),
    this.frameDark = const Color(0xFF2A180D),
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
          colors: [frameLight, frameDark],
        ),
        border: Border.all(color: const Color(0xFF140A05), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(frameWidth),
        // Thin gold line between the wood and the felt.
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
                // Felt: lighter in the middle, darker at the edges.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: [feltLight, feltDark],
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}