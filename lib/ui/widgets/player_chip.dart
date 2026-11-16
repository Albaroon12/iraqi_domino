import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// A small card for one player: avatar, name and remaining tile count.
/// When [isTurn] is true the card glows gold.
class PlayerChip extends StatelessWidget {
  const PlayerChip({
    super.key,
    required this.name,
    required this.tileCount,
    required this.isTurn,
    this.icon = Icons.person_rounded,
  });

  final String name;
  final int tileCount;
  final bool isTurn;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC1D110A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTurn ? AppColors.gold : AppColors.gold.withValues(alpha: 0.25),
          width: isTurn ? 2 : 1,
        ),
        boxShadow: isTurn
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
              ]
            : const [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4A3020),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
            ),
            child: Icon(icon, size: 20, color: AppColors.ivory),
          ),
          const SizedBox(height: 4),
          // Long names shrink instead of overflowing.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 70),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name,
                style: const TextStyle(
                  color: AppColors.ivory,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Text(
            l10n.tilesLeft(tileCount),
            style: TextStyle(
              color: AppColors.ivory.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}