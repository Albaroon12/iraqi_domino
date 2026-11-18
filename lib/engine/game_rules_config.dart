/// The rules of ONE match. Created when the match starts and never changed
/// afterwards. The running match does not read the global app settings.
///
/// Offline: filled from the player's default settings.
/// Online: chosen by the room creator and stored in the room, so every
/// player in the room plays with the same values.
class GameRulesConfig {
  const GameRulesConfig({this.targetScore = 151});

  /// Points needed to win the match.
  final int targetScore;
}
