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
  ///   If neither player holds a double, they draw alternately from the
  ///   boneyard (one tile at a time, starting from a random player) until a
  ///   double appears; the drawer of that double starts and opens with it.
  static RoundSetup dealFirstRound(int playerCount, Random random) {
    assert(playerCount == 2 || playerCount == 4);

    final dealt = deal(playerCount, random);
    final hands = [
      for (final hand in dealt.hands) [...hand],
    ];
    final boneyard = [...dealt.boneyard];

    final start = _findStart(hands);
    if (start != null) {
      return RoundSetup(
        hands: hands,
        boneyard: boneyard,
        startSeat: start.seat,
        startPiece: start.piece,
      );
    }

    // 2 players with no initial double: alternate draws until a double appears.
    var seat = random.nextInt(playerCount);
    while (boneyard.isNotEmpty) {
      final piece = boneyard.removeLast();
      hands[seat].add(piece);
      if (piece.isDouble) {
        return RoundSetup(
          hands: hands,
          boneyard: boneyard,
          startSeat: seat,
          startPiece: piece,
        );
      }
      seat = (seat + 1) % playerCount;
    }

    throw StateError('No double found in full domino set');
  }

  /// Shuffles the full set and deals it in the 2-2-3 pattern.
  ///
  /// Automatically re-deals if any player receives 6 or more doubles or
  /// 6 or more tiles sharing the same number.
  static ({List<List<DominoPiece>> hands, List<DominoPiece> boneyard}) deal(
    int playerCount,
    Random random,
  ) {
    while (true) {
      final pile = DominoPiece.fullSet()..shuffle(random);
      final hands = List.generate(playerCount, (_) => <DominoPiece>[]);

      var next = 0;
      for (final chunk in dealPattern) {
        for (var seat = 0; seat < playerCount; seat++) {
          hands[seat].addAll(pile.sublist(next, next + chunk));
          next += chunk;
        }
      }

      if (hands.every(isValidHand)) {
        return (hands: hands, boneyard: pile.sublist(next));
      }
    }
  }

  /// Returns false if [hand] has 6 or more doubles or 6 or more tiles
  /// containing the same number (0–6), which requires an automatic redeal.
  static bool isValidHand(List<DominoPiece> hand) {
    if (hand.where((p) => p.isDouble).length >= 6) return false;
    for (var value = 0; value <= 6; value++) {
      if (hand.where((p) => p.hasSide(value)).length >= 6) return false;
    }
    return true;
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
