import 'dart:math';

import 'domino_piece.dart';

/// The result of dealing the first round of a match.
class RoundSetup {
  const RoundSetup({
    required this.hands,
    required this.boneyard,
    required this.startSeat,
    required this.startPiece,
  });

  /// One hand per seat. Seats are numbered counter-clockwise from the
  /// bottom player: 0 = you.
  final List<List<DominoPiece>> hands;

  /// Pieces left in the draw pile (14 with two players, none with four).
  final List<DominoPiece> boneyard;

  /// The seat that opens the round.
  final int startSeat;

  /// The piece the starting seat must open with.
  final DominoPiece startPiece;
}

/// Shuffles and deals the pieces. Pure Dart.
///
/// PROTOTYPE: simplified version for Phase 3. The complete rules and
/// their unit tests are written in Phase 4.
class Dealer {
  Dealer._();

  static const int handSize = 7;

  /// Pieces dealt to each player per turn of dealing: 2, then 2, then 3.
  static const List<int> dealPattern = [2, 2, 3];

  /// Deals the FIRST round of a match:
  /// - 4 players: the holder of 6-6 starts and opens with 6-6.
  /// - 2 players: the holder of the highest double starts and opens with it.
  ///
  /// PROTOTYPE: with two players, if nobody holds a double we simply deal
  /// again. The agreed rule (drawing until a double appears) comes in Phase 4.
  static RoundSetup dealFirstRound(int playerCount, Random random) {
    assert(playerCount == 2 || playerCount == 4);

    while (true) {
      final dealt = deal(playerCount, random);
      final start = _findStart(dealt.hands);
      if (start != null) {
        return RoundSetup(
          hands: dealt.hands,
          boneyard: dealt.boneyard,
          startSeat: start.seat,
          startPiece: start.piece,
        );
      }
    }
  }

  /// Shuffles the full set and deals it in the 2-2-3 pattern.
  static ({List<List<DominoPiece>> hands, List<DominoPiece> boneyard}) deal(
    int playerCount,
    Random random,
  ) {
    final pile = DominoPiece.fullSet()..shuffle(random);
    final hands = List.generate(playerCount, (_) => <DominoPiece>[]);

    var next = 0;
    for (final chunk in dealPattern) {
      for (var seat = 0; seat < playerCount; seat++) {
        hands[seat].addAll(pile.sublist(next, next + chunk));
        next += chunk;
      }
    }

    return (hands: hands, boneyard: pile.sublist(next));
  }

  /// Finds the highest double among all hands (6-6 first, then 5-5 ...).
  /// Returns null if nobody holds a double.
  static ({int seat, DominoPiece piece})? _findStart(
    List<List<DominoPiece>> hands,
  ) {
    for (var value = 6; value >= 0; value--) {
      final double = DominoPiece(value, value);
      for (var seat = 0; seat < hands.length; seat++) {
        if (hands[seat].contains(double)) {
          return (seat: seat, piece: double);
        }
      }
    }
    return null;
  }
}