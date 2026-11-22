import 'dart:math';

import 'board.dart';
import 'dealer.dart';
import 'domino_piece.dart';
import 'game_rules_config.dart';
import 'round_result.dart';
import 'round_state.dart';

/// Recorded outcome of one completed round within a match.
class MatchRoundRecord {
  const MatchRoundRecord({
    required this.round,
    required this.result,
    required this.ourTotal,
    required this.theirTotal,
  });

  /// 1-based round number.
  final int round;
  final RoundResult result;

  /// Cumulative match scores after this round.
  final int ourTotal;
  final int theirTotal;
}

/// Manages a full match across multiple rounds until one side reaches
/// [GameRulesConfig.targetScore]. Pure Dart (no Flutter imports).
class MatchState {
  MatchState({
    required this.playerCount,
    required this.rules,
    Random? random,
  }) : assert(playerCount == 2 || playerCount == 4),
       _random = random ?? Random() {
    _round = _dealFirstRound();
  }

  final int playerCount;
  final GameRulesConfig rules;
  final Random _random;

  late RoundState _round;
  final List<int> _scores = [0, 0];
  final List<MatchRoundRecord> _history = [];
  bool _roundRecorded = false;

  /// The active (or most recently finished) round.
  RoundState get round => _round;

  /// Match scores: index 0 = your team, index 1 = opponents' team.
  List<int> get scores => List.unmodifiable(_scores);

  /// History of all completed rounds in this match.
  List<MatchRoundRecord> get history => List.unmodifiable(_history);

  /// The winning team (0 or 1) once [GameRulesConfig.targetScore] is reached,
  /// or null while the match is still in progress.
  int? get winnerTeam {
    if (_scores[0] >= rules.targetScore) return 0;
    if (_scores[1] >= rules.targetScore) return 1;
    return null;
  }

  /// True when a side has reached or exceeded [GameRulesConfig.targetScore].
  bool get isOver => winnerTeam != null;

  /// Legal moves for the current player, or empty when the round/match is over.
  List<Move> legalMoves() => isOver ? const [] : _round.legalMoves();

  /// Plays [move] in the current round and records the round outcome if it
  /// ends the round.
  void play(Move move) {
    if (isOver) throw StateError('The match is over');
    _round.play(move);
    _recordIfRoundOver();
  }

  /// Draws a tile from the boneyard (2-player mode only).
  DominoPiece draw([int? index]) {
    if (isOver) throw StateError('The match is over');
    return _round.draw(index);
  }

  /// Passes the current player's turn and records the round outcome if the
  /// round becomes blocked.
  void pass() {
    if (isOver) throw StateError('The match is over');
    _round.pass();
    _recordIfRoundOver();
  }

  /// Deals and starts the next round after the current round has finished.
  ///
  /// A burned round is dealt like a first round (highest double opens).
  /// After a win, the winning seat starts and may open with any piece.
  void startNextRound() {
    if (isOver) throw StateError('The match is already over');
    final last = _round.result;
    if (last == null) {
      throw StateError('Cannot start next round before the current round ends');
    }

    _roundRecorded = false;
    final winner = last.winnerSeat;
    if (last.kind == RoundEndKind.burned || winner == null) {
      _round = _dealFirstRound();
    } else {
      final dealt = Dealer.deal(playerCount, _random);
      _round = RoundState(
        playerCount: playerCount,
        hands: dealt.hands,
        boneyard: dealt.boneyard,
        startSeat: winner,
      );
    }
  }

  /// Resets scores and history and deals a fresh first round.
  void resetMatch() {
    _scores[0] = 0;
    _scores[1] = 0;
    _history.clear();
    _roundRecorded = false;
    _round = _dealFirstRound();
  }

  /// Developer shortcut: deals a fresh first round without resetting scores.
  void redealCurrentRound() {
    _roundRecorded = false;
    _round = _dealFirstRound();
  }

  RoundState _dealFirstRound() {
    final setup = Dealer.dealFirstRound(playerCount, _random);
    return RoundState(
      playerCount: playerCount,
      hands: setup.hands,
      boneyard: setup.boneyard,
      startSeat: setup.startSeat,
      openingPiece: setup.startPiece,
    );
  }

  void _recordIfRoundOver() {
    final result = _round.result;
    if (result == null || _roundRecorded) return;
    _roundRecorded = true;

    final team = result.winnerTeam;
    if (team != null) {
      _scores[team] += result.points;
    }
    _history.add(
      MatchRoundRecord(
        round: _history.length + 1,
        result: result,
        ourTotal: _scores[0],
        theirTotal: _scores[1],
      ),
    );
  }
}
