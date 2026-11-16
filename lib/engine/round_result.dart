/// How a round ended.
enum RoundEndKind {
  /// A player played all tiles.
  domino,

  /// Nobody can play; the lowest pip total wins.
  blocked,

  /// Tie on a block between different teams: no points, round replayed.
  burned,
}

/// The outcome of one round.
class RoundResult {
  const RoundResult({
    required this.kind,
    this.winnerSeat,
    this.winnerTeam,
    this.points = 0,
  });

  final RoundEndKind kind;

  /// The seat that starts the next round (null for a burned round).
  final int? winnerSeat;

  /// 0 = your team (seats 0 and 2), 1 = the other team.
  /// With two players it is simply the seat number.
  final int? winnerTeam;

  /// Points won: the pips left in the opposing team's hands.
  final int points;
}