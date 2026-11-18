import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Shows both scores and the target score.
/// Labels are passed in: "Us/Them" (4 players) or "You/Opponent" (2 players).
class ScoreBoard extends StatelessWidget {
  const ScoreBoard({
    super.key,
    required this.ourLabel,
    required this.theirLabel,
    required this.ourScore,
    required this.theirScore,
    required this.targetScore,
  });

  final String ourLabel;
  final String theirLabel;
  final int ourScore;
  final int theirScore;
  final int targetScore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC1D110A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScoreCell(label: ourLabel, score: ourScore),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.targetShort,
                style: TextStyle(
                  color: AppColors.ivory.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                '$targetScore',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Expanded(
            child: _ScoreCell(label: theirLabel, score: theirScore),
          ),
        ],
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.ivory, fontSize: 13),
        ),
        Text(
          '$score',
          style: const TextStyle(
            color: AppColors.ivory,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
