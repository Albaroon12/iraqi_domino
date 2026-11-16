import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'game_button.dart';

/// How a round ended.
enum RoundEndKind {
  /// A player (or team) played all tiles.
  domino,

  /// Nobody can play; the lowest pip total wins.
  blocked,

  /// Tie on a block: no points, the round is replayed.
  burned,
}

/// Shows the end-of-round dialog. Uses sample data for now; the real
/// values will come from the game engine in Phase 4.
Future<void> showRoundResultDialog(
  BuildContext context, {
  required RoundEndKind kind,
  required bool weWon,
  required int points,
  required int ourTotal,
  required int theirTotal,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RoundResultDialog(
      kind: kind,
      weWon: weWon,
      points: points,
      ourTotal: ourTotal,
      theirTotal: theirTotal,
    ),
  );
}

class _RoundResultDialog extends StatelessWidget {
  const _RoundResultDialog({
    required this.kind,
    required this.weWon,
    required this.points,
    required this.ourTotal,
    required this.theirTotal,
  });

  final RoundEndKind kind;
  final bool weWon;
  final int points;
  final int ourTotal;
  final int theirTotal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final burned = kind == RoundEndKind.burned;

    final title = burned
        ? l10n.roundBurned
        : (weWon ? l10n.weWonRound : l10n.theyWonRound);
    final reason = switch (kind) {
      RoundEndKind.domino => l10n.reasonDomino,
      RoundEndKind.blocked => l10n.reasonBlocked,
      RoundEndKind.burned => l10n.reasonBurned,
    };
    final icon = burned
        ? Icons.local_fire_department_outlined
        : (weWon
            ? Icons.emoji_events_outlined
            : Icons.sentiment_dissatisfied_outlined);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A2515), Color(0xFF1D110A)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.gold),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ivory.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            if (!burned) ...[
              const SizedBox(height: 16),
              Text(
                l10n.roundPoints(points),
                style: const TextStyle(
                  color: AppColors.ivory,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              l10n.totalsLine(ourTotal, theirTotal),
              style: TextStyle(
                color: AppColors.ivory.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GameButton(
                label: l10n.nextRound,
                primary: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}