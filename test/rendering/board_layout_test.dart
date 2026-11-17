import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/engine/board.dart';
import 'package:iraqi_domino/engine/dealer.dart';
import 'package:iraqi_domino/engine/domino_piece.dart';
import 'package:iraqi_domino/engine/round_state.dart';
import 'package:iraqi_domino/rendering/board_layout.dart';

bool _overlap(LayoutBox a, LayoutBox b) =>
    a.left < b.right - .01 &&
    b.left < a.right - .01 &&
    a.top < b.bottom - .01 &&
    b.top < a.bottom - .01;

void _check(BoardLayout layout, double width, double height) {
  final boxes = [
    for (final t in layout.tiles) t.box,
    layout.leftSlot,
    layout.rightSlot,
  ];
  for (final b in boxes) {
    expect(
      b.left >= -.01 && b.top >= -.01 && b.right <= width + .01 &&
          b.bottom <= height + .01,
      isTrue,
      reason: 'a tile is outside the table',
    );
  }
  for (var i = 0; i < boxes.length; i++) {
    for (var j = i + 1; j < boxes.length; j++) {
      expect(_overlap(boxes[i], boxes[j]), isFalse, reason: 'tiles overlap');
    }
  }
  // Touching numbers must match on screen (same row, or stacked at a turn).
  for (var i = 0; i < layout.tiles.length - 1; i++) {
    final a = layout.tiles[i];
    final b = layout.tiles[i + 1];
    final sameRow = (a.box.centerY - b.box.centerY).abs() < 1;
    final bool ok;
    if (sameRow) {
      ok = a.box.left < b.box.left
          ? a.rightValue == b.leftValue &&
              (a.box.right + BoardLayout.gap - b.box.left).abs() < .01
          : b.rightValue == a.leftValue &&
              (b.box.right + BoardLayout.gap - a.box.left).abs() < .01;
    } else {
      ok = ((a.box.right - b.box.right).abs() < .5 &&
              a.rightValue == b.rightValue) ||
          ((a.box.left - b.box.left).abs() < .5 &&
              a.leftValue == b.leftValue);
    }
    expect(ok, isTrue, reason: 'numbers do not touch at piece $i');
  }
}

void main() {
  test('1-4 then 1-6 on the 1 side: ends are 6 and 4, touching 1 to 1', () {
    final board = Board()
      ..place(const DominoPiece(1, 4), BoardEnd.right)
      ..place(const DominoPiece(1, 6), BoardEnd.left);
    final layout = BoardLayout.fit(board, 232, 280);

    expect(layout.tiles.first.leftValue, 6);
    expect(layout.tiles.first.rightValue, 1);
    expect(layout.tiles.last.leftValue, 1);
    expect(layout.tiles.last.rightValue, 4);
  });

  for (final cfg in [(4, 232.0, 280.0), (2, 336.0, 300.0), (4, 232.0, 200.0)]) {
    test('valid layout for ${cfg.$1} players in ${cfg.$2} x ${cfg.$3}', () {
      for (var seed = 0; seed < 100; seed++) {
        final random = Random(seed);
        final setup = Dealer.dealFirstRound(cfg.$1, random);
        final round = RoundState(
          playerCount: cfg.$1,
          hands: setup.hands,
          boneyard: setup.boneyard,
          startSeat: setup.startSeat,
          openingPiece: setup.startPiece,
        );
        while (!round.isOver) {
          final moves = round.legalMoves();
          if (moves.isNotEmpty) {
            round.play(moves[random.nextInt(moves.length)]);
            for (final ghost in [false, true]) {
              _check(
                BoardLayout.fit(round.board, cfg.$2, cfg.$3, ghostDouble: ghost),
                cfg.$2,
                cfg.$3,
              );
            }
          } else if (round.playerCount == 2 && round.boneyard.isNotEmpty) {
            round.draw();
          } else {
            round.pass();
          }
        }
      }
    });
  }
}