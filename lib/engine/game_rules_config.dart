import '../ai/ai_difficulty.dart';

/// The rules of ONE match. Created when the match starts and never changed
/// afterwards. The running match does not read the global app settings.
///
/// Offline: filled from the player's default settings.
/// Online / Local Room: chosen by the room creator and stored in the room, so
/// every player in the room plays with the same values.
class GameRulesConfig {
  const GameRulesConfig({
    this.targetScore = 151,
    this.aiDifficulty = AiDifficulty.medium,
  });

  /// Points needed to win the match.
  final int targetScore;

  /// Difficulty of computer players (and takeover bots) in the match.
  final AiDifficulty aiDifficulty;

  @override
  bool operator ==(Object other) =>
      other is GameRulesConfig &&
      other.targetScore == targetScore &&
      other.aiDifficulty == aiDifficulty;

  @override
  int get hashCode => Object.hash(targetScore, aiDifficulty);
}
