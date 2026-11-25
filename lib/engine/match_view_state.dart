import '../ai/ai_persona.dart';
import 'board.dart';
import 'domino_piece.dart';
import 'game_rules_config.dart';
import 'match_state.dart';
import 'round_result.dart';
import 'seat_occupant.dart';

/// Status pill kind shown when a player has no legal move. Pure Dart.
enum MatchStatusKind { noTiles, passes, draws }

/// Status pill payload indicating which seat has no move or is drawing.
class MatchStatus {
  const MatchStatus({required this.seat, required this.kind});

  final int seat;
  final MatchStatusKind kind;
}

/// Immutable snapshot of a running match exposed to the UI. Pure Dart.
class MatchViewState {
  const MatchViewState({
    required this.playerCount,
    required this.rules,
    required this.seats,
    required this.canAcceptHumanJoin,
    required this.board,
    required this.hands,
    required this.boneyardCount,
    required this.boneyardSlots,
    required this.awaitingHumanDraw,
    required this.revealingRound,
    required this.lastPlayedPiece,
    required this.startSeat,
    required this.openingPiece,
    required this.turnSeat,
    required this.scores,
    required this.history,
    required this.myMoves,
    required this.secondsLeft,
    required this.turnSeconds,
    required this.status,
    required this.roundResult,
    required this.matchWinnerTeam,
    required this.showResultPending,
    required this.revision,
  });

  final int playerCount;
  final GameRulesConfig rules;

  /// Current occupant of each seat (`0..playerCount-1`). Seat 0 is the local
  /// player; other seats hold either live players or distinct [AiPersona] bots.
  final List<SeatOccupant> seats;

  /// True while scores are still below the endgame cutoff so a disconnected
  /// seat controlled by a temporary bot could still accept a live human join.
  final bool canAcceptHumanJoin;

  final Board board;
  final List<List<DominoPiece>> hands;
  final int boneyardCount;

  /// Fixed 14-slot boneyard layout for 2-player mode (null = already drawn).
  final List<DominoPiece?> boneyardSlots;

  /// True when seat 0 (2 players) must pick a tile from the boneyard table.
  final bool awaitingHumanDraw;

  /// True right after a round ends while all players' remaining tiles are
  /// revealed face-up and points are tallied on screen.
  final bool revealingRound;

  /// The most recently placed piece in the current round (highlighted briefly).
  final DominoPiece? lastPlayedPiece;

  final int startSeat;
  final DominoPiece? openingPiece;
  final int? turnSeat;
  final List<int> scores;
  final List<MatchRoundRecord> history;
  final List<Move> myMoves;
  final int secondsLeft;
  final int turnSeconds;
  final MatchStatus? status;
  final RoundResult? roundResult;
  final int? matchWinnerTeam;
  final bool showResultPending;
  final int revision;

  bool get isFourPlayers => playerCount == 4;
  bool get isMatchOver => matchWinnerTeam != null;

  bool isPlayable(DominoPiece piece) =>
      myMoves.any((move) => move.piece == piece);

  List<BoardEnd> endsFor(DominoPiece piece) => [
    for (final move in myMoves)
      if (move.piece == piece) move.end,
  ];
}
