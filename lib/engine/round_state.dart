import 'board.dart';
import 'domino_piece.dart';
import 'round_result.dart';

/// The state of one round. Pure Dart.
///
/// PROTOTYPE: a simple mutable version for the playable prototype.
/// Phase 4 completes it (match scoring, all rule options) and tests it
/// against game_rules.md.
///
/// Seats are numbered counter-clockwise from the bottom player.
class RoundState {
  RoundState({
    required this.playerCount,
    required List<List<DominoPiece>> hands,
    required List<DominoPiece> boneyard,
    required this.startSeat,
    this.openingPiece,
  }) : assert(playerCount == 2 || playerCount == 4),
       hands = [
         for (final hand in hands) [...hand],
       ],
       boneyard = [...boneyard],
       turn = startSeat;

  final int playerCount;
  final List<List<DominoPiece>> hands;

  /// The draw pile (used with two players only).
  final List<DominoPiece> boneyard;

  final int startSeat;

  /// The piece the first player must open with (first round of a match).
  /// null means the starter may open with any piece.
  final DominoPiece? openingPiece;

  final Board board = Board();

  /// The seat whose turn it is.
  int turn;

  /// The seat that placed the last piece (the one who "blocked" the game).
  int lastPlayedSeat = -1;

  /// Passes in a row. When everybody passed, the game is blocked.
  int consecutivePasses = 0;

  RoundResult? result;

  bool get isOver => result != null;

  /// Team of a seat: with four players, opposite seats are partners.
  static int teamOf(int seat, int playerCount) =>
      playerCount == 4 ? seat % 2 : seat;

  /// The legal moves of the player whose turn it is.
  ///
  /// Computed on demand and ONLY for the current player, because hands
  /// change after every move. There is no per-seat cache.
  List<Move> legalMoves() {
    if (isOver) return const [];
    final hand = hands[turn];

    if (board.isEmpty) {
      final open = openingPiece;
      return [
        for (final piece in hand)
          if (open == null || piece == open) Move(piece, BoardEnd.right),
      ];
    }

    return [
      for (final piece in hand)
        for (final end in board.endsFor(piece)) Move(piece, end),
    ];
  }

  /// Plays [move] for the current player and passes the turn.
  void play(Move move) {
    if (!legalMoves().contains(move)) {
      throw StateError('Illegal move: $move');
    }

    board.place(move.piece, move.end);
    hands[turn].remove(move.piece);
    lastPlayedSeat = turn;
    consecutivePasses = 0;

    if (hands[turn].isEmpty) {
      _finishDomino(turn);
    } else {
      turn = (turn + 1) % playerCount;
    }
  }

  /// Draws one piece for the current player (two players only).
  /// Allowed only when the player has no legal move.
  DominoPiece draw() {
    if (isOver) throw StateError('The round is over');
    if (playerCount != 2) throw StateError('Drawing is for two players only');
    if (boneyard.isEmpty) throw StateError('The draw pile is empty');
    if (legalMoves().isNotEmpty) {
      throw StateError('Cannot draw: the player has a legal move');
    }

    final piece = boneyard.removeLast();
    hands[turn].add(piece);
    return piece;
  }

  /// The current player passes ("I have none").
  /// Allowed only with no legal move (and, with two players, an empty pile).
  void pass() {
    if (isOver) throw StateError('The round is over');
    if (legalMoves().isNotEmpty) {
      throw StateError('Cannot pass: the player has a legal move');
    }
    if (playerCount == 2 && boneyard.isNotEmpty) {
      throw StateError('Cannot pass: the player must draw first');
    }

    consecutivePasses++;
    if (consecutivePasses >= playerCount) {
      _finishBlocked();
    } else {
      turn = (turn + 1) % playerCount;
    }
  }

  int _teamOf(int seat) => teamOf(seat, playerCount);

  int _handPips(int seat) =>
      hands[seat].fold<int>(0, (sum, piece) => sum + piece.pips);

  /// Pips left in the hands of the players NOT in [team].
  int _opponentPips(int team) {
    var sum = 0;
    for (var seat = 0; seat < playerCount; seat++) {
      if (_teamOf(seat) != team) sum += _handPips(seat);
    }
    return sum;
  }

  void _finishDomino(int winnerSeat) {
    final team = _teamOf(winnerSeat);
    result = RoundResult(
      kind: RoundEndKind.domino,
      winnerSeat: winnerSeat,
      winnerTeam: team,
      points: _opponentPips(team),
    );
  }

  void _finishBlocked() {
    final totals = [for (var s = 0; s < playerCount; s++) _handPips(s)];
    final lowest = totals.reduce((a, b) => a < b ? a : b);
    final lowSeats = [
      for (var s = 0; s < playerCount; s++)
        if (totals[s] == lowest) s,
    ];

    // Tie between different teams: the round is burned.
    final teams = lowSeats.map(_teamOf).toSet();
    if (teams.length > 1) {
      result = const RoundResult(kind: RoundEndKind.burned);
      return;
    }

    // Tie inside the same team: that team wins, and the tied player
    // closest to the blocker (in play order) starts the next round.
    // [ASSUMED] in game_rules.md.
    var starter = lowSeats.first;
    var closest = playerCount;
    for (final seat in lowSeats) {
      final distance = (seat - lastPlayedSeat + playerCount) % playerCount;
      if (distance < closest) {
        closest = distance;
        starter = seat;
      }
    }

    final team = teams.single;
    result = RoundResult(
      kind: RoundEndKind.blocked,
      winnerSeat: starter,
      winnerTeam: team,
      points: _opponentPips(team),
    );
  }
}
