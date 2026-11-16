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
      test('every player gets 7 pieces and no piece is repeated', () {
        for (var seed = 0; seed < 200; seed++) {
          final round = Dealer.dealFirstRound(players, Random(seed));

          expect(round.hands.length, players);
          for (final hand in round.hands) {
            expect(hand.length, 7);
          }
          expect(round.boneyard.length, players == 4 ? 0 : 14);

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
    });
  }
}