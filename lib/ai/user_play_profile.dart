import '../engine/board.dart';
import '../engine/round_state.dart';

/// Pure-Dart adaptive profile that learns the human player's (seat 0) playing
/// habits across moves and matches.
///
/// The AI uses this profile both when playing *against* the user (seats 1 and 3)
/// to predict their hidden hand and counter their favorite numbers, and when
/// playing *with* the user as their partner (seat 2 in 4-player mode) to
/// support the numbers the user likes to build on.
class UserPlayProfile {
  UserPlayProfile({
    this.movesObserved = 0,
    this.heavyPipPreference = 0.55,
    this.doubleShedPreference = 0.65,
    this.selfSuitKeepPreference = 0.60,
    this.aggressiveBlockPreference = 0.50,
    List<double>? numberOpenAffinity,
  }) : numberOpenAffinity = numberOpenAffinity != null &&
               numberOpenAffinity.length == 7
           ? List<double>.of(numberOpenAffinity)
           : List<double>.filled(7, 0.5);

  /// Total non-forced human moves observed (where legalMoves.length >= 2).
  int movesObserved;

  /// 0..1: How strongly the user prioritizes shedding their highest-pip tiles
  /// when given a choice.
  double heavyPipPreference;

  /// 0..1: How strongly the user prioritizes playing a double immediately
  /// whenever one is playable.
  double doubleShedPreference;

  /// 0..1: When the user exposes a new number on the board, how often they
  /// also hold another tile matching that exposed number in their hand
  /// (suit-building / "تأسيس اللعب على رقم ممسوك").
  double selfSuitKeepPreference;

  /// 0..1: How often the user plays a move that locks both ends to the same
  /// number or targets a number an opponent passed/drew on.
  double aggressiveBlockPreference;

  /// 0..1 per number (0..6): How often the user chooses to leave each number
  /// open on the board when other numbers were available.
  final List<double> numberOpenAffinity;

  /// Confidence weight (0.0 to 1.0) scaling how strongly the AI relies on the
  /// learned profile versus default priors.
  double get confidence => (movesObserved / 25.0).clamp(0.0, 1.0);

  /// Observes a human move ([chosenMove]) at seat 0 when [legalMoves] were
  /// available, and updates the learned weights using an exponential moving
  /// average.
  void observeHumanMove(
    RoundState round,
    Move chosenMove,
    List<Move> legalMoves,
  ) {
    if (legalMoves.length < 2 || round.turn != 0) return;

    movesObserved++;
    // Faster learning rate early on, stabilizing as more moves are observed.
    final alpha = movesObserved < 10 ? 0.22 : 0.12;
    final hand = round.hands[0];
    final chosenPiece = chosenMove.piece;

    // 1. Heavy pip preference: compare chosen piece pips to min/max among legal moves.
    var minPips = 12;
    var maxPips = 0;
    for (final m in legalMoves) {
      if (m.piece.pips < minPips) minPips = m.piece.pips;
      if (m.piece.pips > maxPips) maxPips = m.piece.pips;
    }
    if (maxPips > minPips) {
      final ratio = (chosenPiece.pips - minPips) / (maxPips - minPips);
      heavyPipPreference = _ema(heavyPipPreference, ratio, alpha);
    }

    // 2. Double shedding preference: when the user has both a playable double
    //    and a playable non-double, did they play the double?
    final hasDoubleOption = legalMoves.any((m) => m.piece.isDouble);
    final hasNonDoubleOption = legalMoves.any((m) => !m.piece.isDouble);
    if (hasDoubleOption && hasNonDoubleOption) {
      final pickedDouble = chosenPiece.isDouble ? 1.0 : 0.0;
      doubleShedPreference = _ema(doubleShedPreference, pickedDouble, alpha);
    }

    // 3. Self-suit keeping (building on a number they still hold in hand).
    final chosenLeft = _leftEndAfterMove(round.board, chosenMove);
    final chosenRight = _rightEndAfterMove(round.board, chosenMove);
    final chosenOpened = chosenMove.end == BoardEnd.left
        ? chosenLeft
        : chosenRight;

    final remainingHand = [
      for (final p in hand)
        if (p != chosenPiece) p,
    ];
    if (remainingHand.isNotEmpty) {
      final holdsOpenedSuit = remainingHand.any(
        (p) => p.hasSide(chosenOpened),
      );
      selfSuitKeepPreference = _ema(
        selfSuitKeepPreference,
        holdsOpenedSuit ? 1.0 : 0.0,
        alpha,
      );
    }

    // 4. Aggressive block / single-number lock preference.
    final oppMissing = <int>{};
    for (final e in round.passHistory) {
      if (RoundState.teamOf(e.seat, round.playerCount) != 0) {
        oppMissing.add(e.leftEnd);
        oppMissing.add(e.rightEnd);
      }
    }
    for (final e in round.drawHistory) {
      if (RoundState.teamOf(e.seat, round.playerCount) != 0) {
        oppMissing.add(e.leftEnd);
        oppMissing.add(e.rightEnd);
      }
    }

    var hadBlockingOption = false;
    var choseBlockingOption = false;
    for (final m in legalMoves) {
      final l = _leftEndAfterMove(round.board, m);
      final r = _rightEndAfterMove(round.board, m);
      final isBlocky =
          l == r || oppMissing.contains(l) || oppMissing.contains(r);
      if (isBlocky) {
        hadBlockingOption = true;
        if (m == chosenMove) choseBlockingOption = true;
      }
    }
    if (hadBlockingOption) {
      aggressiveBlockPreference = _ema(
        aggressiveBlockPreference,
        choseBlockingOption ? 1.0 : 0.0,
        alpha,
      );
    }

    // 5. Number affinity: which outward number did the user choose to expose
    //    compared to other outward numbers they could have exposed?
    final exposedOptions = <int>{};
    for (final m in legalMoves) {
      final l = _leftEndAfterMove(round.board, m);
      final r = _rightEndAfterMove(round.board, m);
      exposedOptions.add(m.end == BoardEnd.left ? l : r);
    }
    if (exposedOptions.length >= 2) {
      for (final num in exposedOptions) {
        final target = num == chosenOpened ? 1.0 : 0.0;
        numberOpenAffinity[num] = _ema(
          numberOpenAffinity[num],
          target,
          alpha * 0.75,
        );
      }
    }
  }

  /// Serializes this profile into a compact string for `SharedPreferences`.
  String encode() {
    final affinities = numberOpenAffinity
        .map((v) => v.toStringAsFixed(4))
        .join(',');
    return [
      movesObserved,
      heavyPipPreference.toStringAsFixed(4),
      doubleShedPreference.toStringAsFixed(4),
      selfSuitKeepPreference.toStringAsFixed(4),
      aggressiveBlockPreference.toStringAsFixed(4),
      affinities,
    ].join('|');
  }

  /// Restores a [UserPlayProfile] from [raw], or returns a fresh default
  /// profile if [raw] is null or malformed.
  factory UserPlayProfile.decode(String? raw) {
    if (raw == null || raw.isEmpty) return UserPlayProfile();
    final parts = raw.split('|');
    if (parts.length != 6) return UserPlayProfile();

    final moves = int.tryParse(parts[0]);
    final heavy = double.tryParse(parts[1]);
    final doubles = double.tryParse(parts[2]);
    final suitKeep = double.tryParse(parts[3]);
    final blocky = double.tryParse(parts[4]);
    final affParts = parts[5].split(',');
    if (moves == null ||
        heavy == null ||
        doubles == null ||
        suitKeep == null ||
        blocky == null ||
        affParts.length != 7) {
      return UserPlayProfile();
    }

    final affinities = <double>[];
    for (final s in affParts) {
      final v = double.tryParse(s);
      if (v == null) return UserPlayProfile();
      affinities.add(v.clamp(0.0, 1.0));
    }

    return UserPlayProfile(
      movesObserved: moves < 0 ? 0 : moves,
      heavyPipPreference: heavy.clamp(0.0, 1.0),
      doubleShedPreference: doubles.clamp(0.0, 1.0),
      selfSuitKeepPreference: suitKeep.clamp(0.0, 1.0),
      aggressiveBlockPreference: blocky.clamp(0.0, 1.0),
      numberOpenAffinity: affinities,
    );
  }

  static double _ema(double current, double sample, double alpha) =>
      (current * (1.0 - alpha) + sample * alpha).clamp(0.0, 1.0);

  static int _leftEndAfterMove(Board board, Move move) {
    final p = move.piece;
    if (board.isEmpty) return p.low;
    final left = board.leftEnd!;
    if (move.end == BoardEnd.left) {
      return p.low == left ? p.high : p.low;
    }
    return left;
  }

  static int _rightEndAfterMove(Board board, Move move) {
    final p = move.piece;
    if (board.isEmpty) return p.high;
    final right = board.rightEnd!;
    if (move.end == BoardEnd.right) {
      return p.low == right ? p.high : p.low;
    }
    return right;
  }
}
