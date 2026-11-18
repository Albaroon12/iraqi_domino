import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';

/// Compact player marker: a small avatar with a tile-count badge and the
/// name below it. The avatar glows gold when it is the player's turn.
///
/// When [secondsLeft] is given, a ring counts the turn time down around the
/// avatar; in the last 10 seconds it turns red and shows the number.
class PlayerChip extends StatelessWidget {
  const PlayerChip({
    super.key,
    required this.name,
    required this.tileCount,
    required this.isTurn,
    this.icon = Icons.person_rounded,
    this.secondsLeft,
    this.secondsTotal = 30,
  });

  final String name;
  final int tileCount;
  final bool isTurn;
  final IconData icon;
  final int? secondsLeft;
  final int secondsTotal;

  @override
  Widget build(BuildContext context) {
    final left = secondsLeft;
    final urgent = left != null && left <= 10;
    const urgentColor = Color(0xFFE5533D);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4A3020),
                border: Border.all(
                  color: isTurn
                      ? AppColors.gold
                      : AppColors.gold.withValues(alpha: 0.35),
                  width: isTurn ? 2.5 : 1.5,
                ),
                boxShadow: isTurn
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.6),
                          blurRadius: 12,
                        ),
                      ]
                    : const [],
              ),
              child: urgent
                  ? Text(
                      '$left',
                      style: const TextStyle(
                        color: urgentColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    )
                  : Icon(icon, size: 20, color: AppColors.ivory),
            ),
            // Turn timer ring.
            if (left != null)
              Positioned(
                left: -5,
                top: -5,
                right: -5,
                bottom: -5,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: left / secondsTotal),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.linear,
                    builder: (context, value, _) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 3,
                      color: urgent ? urgentColor : AppColors.gold,
                      backgroundColor: const Color(0x33FFFFFF),
                    ),
                  ),
                ),
              ),
            // Tile count badge.
            Positioned(
              right: -7,
              bottom: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                height: 17,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$tileCount',
                  style: const TextStyle(
                    color: AppColors.walnut,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xAA1D110A),
            borderRadius: BorderRadius.circular(8),
          ),
          // Long names shrink instead of overflowing.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.ivory,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
