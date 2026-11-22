import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/engine/dealer.dart';
import 'package:iraqi_domino/engine/domino_piece.dart';

void main() {
  test('the full set has 28 unique pieces', () {
    final set = DominoPiece.fullSet();
    expect(set.length, 28);
    expect(set.toSet().length, 28);
  });

  test('a piece has one representation and counts its pips', () {
    expect(const DominoPiece(2, 5), const DominoPiece(2, 5));
    expect(const DominoPiece(6, 6).isDouble, isTrue);
    expect(const DominoPiece(2, 5).pips, 7);
  });

  for (final players in [2, 4]) {
    group('$players players', () {
      test('every player gets at least 7 pieces and no piece is repeated', () {
        for (var seed = 0; seed < 200; seed++) {
          final round = Dealer.dealFirstRound(players, Random(seed));

          expect(round.hands.length, players);
          for (final hand in round.hands) {
            if (players == 4) {
              expect(hand.length, 7);
            } else {
              expect(hand.length, greaterThanOrEqualTo(7));
            }
          }
          if (players == 4) {
            expect(round.boneyard.length, 0);
          } else {
            expect(round.boneyard.length, lessThanOrEqualTo(14));
          }

          final all = [...round.hands.expand((h) => h), ...round.boneyard];
          expect(all.length, 28);
          expect(all.toSet().length, 28);
        }
      });

      test('the starter holds the highest double', () {
        for (var seed = 0; seed < 200; seed++) {
          final round = Dealer.dealFirstRound(players, Random(seed));

          expect(round.hands[round.startSeat], contains(round.startPiece));
          expect(round.startPiece.isDouble, isTrue);

          final highest = round.hands
              .expand((h) => h)
              .where((p) => p.isDouble)
              .map((p) => p.high)
              .reduce(max);
          expect(round.startPiece.high, highest);

          // With four players all 28 pieces are dealt, so it is always 6-6.
          if (players == 4) {
            expect(round.startPiece, const DominoPiece(6, 6));
          }
        }
      });

      test('the same seed gives the same deal', () {
        final a = Dealer.dealFirstRound(players, Random(42));
        final b = Dealer.dealFirstRound(players, Random(42));

        expect(a.hands, b.hands);
        expect(a.startSeat, b.startSeat);
      });

      test('no hand has 6+ doubles or 6+ tiles of the same number', () {
        for (var seed = 0; seed < 200; seed++) {
          final round = Dealer.dealFirstRound(players, Random(seed));
          for (final hand in round.hands) {
            expect(Dealer.isValidHand(hand), isTrue);
          }
          final later = Dealer.deal(players, Random(seed + 1000));
          for (final hand in later.hands) {
            expect(Dealer.isValidHand(hand), isTrue);
          }
        }
      });
    });
  }

  test('isValidHand rejects 6 doubles or 6 tiles with the same number', () {
    expect(
      Dealer.isValidHand(const [
        DominoPiece(0, 0),
        DominoPiece(1, 1),
        DominoPiece(2, 2),
        DominoPiece(3, 3),
        DominoPiece(4, 4),
        DominoPiece(5, 5),
        DominoPiece(0, 1),
      ]),
      isFalse,
    );
    expect(
      Dealer.isValidHand(const [
        DominoPiece(0, 6),
        DominoPiece(1, 6),
        DominoPiece(2, 6),
        DominoPiece(3, 6),
        DominoPiece(4, 6),
        DominoPiece(5, 6),
        DominoPiece(0, 1),
      ]),
      isFalse,
    );
    expect(
      Dealer.isValidHand(const [
        DominoPiece(0, 0),
        DominoPiece(1, 1),
        DominoPiece(2, 2),
        DominoPiece(3, 3),
        DominoPiece(4, 4),
        DominoPiece(0, 6),
        DominoPiece(1, 5),
      ]),
      isTrue,
    );
  });
}
