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

/// The two touching surfaces of a tile. A double is one surface: a
/// neighbour touches its long side or one of its heads, whatever half is
/// nearer.
List<LayoutBox> _halves(LaidTile t) {
  final b = t.box;
  if (t.isDouble) return [b, b];
  return b.isVertical
      ? [
          LayoutBox(b.left, b.top, b.width, b.height / 2),
          LayoutBox(b.left, b.top + b.height / 2, b.width, b.height / 2),
        ]
      : [
          LayoutBox(b.left, b.top, b.width / 2, b.height),
          LayoutBox(b.left + b.width / 2, b.top, b.width / 2, b.height),
        ];
}

/// True if two boxes face each other across the gap and share most of an
/// edge (a real connection, not a corner that happens to be close).
bool _facing(LayoutBox a, LayoutBox b, double w) {
  const tol = .5;
  final overlapX = min(a.right, b.right) - max(a.left, b.left);
  final overlapY = min(a.bottom, b.bottom) - max(a.top, b.top);
  final sideBySide =
      overlapY > .75 * w &&
      ((a.right + BoardLayout.gap - b.left).abs() < tol ||
          (b.right + BoardLayout.gap - a.left).abs() < tol);
  final stacked =
      overlapX > .75 * w &&
      ((a.bottom + BoardLayout.gap - b.top).abs() < tol ||
          (b.bottom + BoardLayout.gap - a.top).abs() < tol);
  return sideBySide || stacked;
}

void _check(BoardLayout layout, double width, double height) {
  final w = layout.tileWidth;

  // Every piece is w x 2w.
  for (final t in layout.tiles) {
    expect(max(t.box.width, t.box.height), closeTo(2 * w, .01));
    expect(min(t.box.width, t.box.height), closeTo(w, .01));
  }

  // A double is crosswise to its line: perpendicular to the piece before
  // it (the one toward the center). Never lengthwise, never a corner.
  for (var i = 0; i < layout.tiles.length; i++) {
    final t = layout.tiles[i];
    if (!t.isDouble) continue;
    final isCenter = _isCenter(layout, i);
    if (isCenter) {
      // The first piece: a double lies crosswise to the vertical line.
      expect(t.box.isVertical, isFalse, reason: 'center double is not wide');
      continue;
    }
    final prev = _towardCenter(layout, i);
    if (prev == null || prev.isDouble) continue;
    expect(
      t.isVertical,
      isNot(prev.isVertical),
      reason: 'a double is not crosswise at piece $i',
    );
  }

  final boxes = [
    for (final t in layout.tiles) t.box,
    layout.leftSlot,
    layout.rightSlot,
  ];

  for (final b in boxes) {
    expect(
      b.left >= -.01 &&
          b.top >= -.01 &&
          b.right <= width + .01 &&
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

  // Neighbours in the line must touch on screen, with equal numbers.
  // (This also proves that the piece after a double leaves from its head.)
  for (var i = 0; i < layout.tiles.length - 1; i++) {
    final a = layout.tiles[i];
    final b = layout.tiles[i + 1];
    final ha = _halves(a);
    final hb = _halves(b);
    final va = [a.firstValue, a.secondValue];
    final vb = [b.firstValue, b.secondValue];

    var touching = 0;
    for (var x = 0; x < 2; x++) {
      for (var y = 0; y < 2; y++) {
        if (_facing(ha[x], hb[y], w)) {
          touching++;
          expect(va[x], vb[y], reason: 'numbers do not match at piece $i');
        }
      }
    }
    expect(touching, greaterThan(0), reason: 'pieces $i and ${i + 1} apart');
  }
}

// The layout does not expose the start index, so the first piece is found
// as the one closest to the middle of the pieces' bounding area... which
// is fragile. Instead the tests below pass the board's start index in.
int _startIndexForCheck = 0;

bool _isCenter(BoardLayout layout, int i) => i == _startIndexForCheck;

LaidTile? _towardCenter(BoardLayout layout, int i) {
  if (i == _startIndexForCheck) return null;
  final j = i > _startIndexForCheck ? i - 1 : i + 1;
  return layout.tiles[j];
}

/// Checks a layout of [board]. Remembers where the first piece is.
void _checkBoard(Board board, BoardLayout layout, double width, double height) {
  _startIndexForCheck = board.startIndex;
  _check(layout, width, height);
}

/// The boxes of the tiles in the order they were played.
List<LayoutBox> _inPlayOrder(Board board, BoardLayout layout) {
  final start = board.startIndex;
  final history = board.history;
  var r = 0;
  var l = 0;
  final out = <LayoutBox>[layout.tiles[start].box];
  for (var i = 1; i < history.length; i++) {
    if (history[i] == BoardEnd.right) {
      r++;
      out.add(layout.tiles[start + r].box);
    } else {
      l++;
      out.add(layout.tiles[start - l].box);
    }
  }
  return out;
}

void main() {
  test('1-4 then 1-6 on the 1 side: ends are 6 and 4, touching 1 to 1', () {
    final board = Board()
      ..place(const DominoPiece(1, 4), BoardEnd.right)
      ..place(const DominoPiece(1, 6), BoardEnd.left);
    final layout = BoardLayout.fit(board, 232, 280);

    // The line is vertical: the left arm goes up.
    expect(layout.tiles.first.firstValue, 6);
    expect(layout.tiles.first.secondValue, 1);
    expect(layout.tiles.last.firstValue, 1);
    expect(layout.tiles.last.secondValue, 4);
    _checkBoard(board, layout, 232, 280);
  });

  test('the line is always vertical at the start, even in a wide area', () {
    final board = Board()..place(const DominoPiece(1, 4), BoardEnd.right);

    expect(BoardLayout.fit(board, 232, 280).tiles.single.isVertical, isTrue);
    expect(BoardLayout.fit(board, 340, 258).tiles.single.isVertical, isTrue);
  });

  test('a double as the first piece lies crosswise', () {
    final board = Board()..place(const DominoPiece(6, 6), BoardEnd.right);
    final layout = BoardLayout.fit(board, 232, 280);

    final box = layout.tiles.single.box;
    expect(box.width, closeTo(2 * layout.tileWidth, .01));
    expect(box.height, closeTo(layout.tileWidth, .01));
  });

  test('a double in a vertical line is crosswise and does not turn', () {
    // 6-6, then 6-3 below it, then 3-3 below that (a double after a normal).
    final board = Board()
      ..place(const DominoPiece(6, 6), BoardEnd.right)
      ..place(const DominoPiece(3, 6), BoardEnd.right)
      ..place(const DominoPiece(3, 3), BoardEnd.right);
    final layout = BoardLayout.fit(board, 232, 280);

    final normal = layout.tiles[1];
    final double = layout.tiles[2];
    expect(normal.isVertical, isTrue);
    expect(double.isVertical, isFalse); // wide: crosswise
    // Straight below the normal piece, centered on its line.
    expect(double.box.centerX, closeTo(normal.box.centerX, .01));
    expect(double.box.top, greaterThan(normal.box.bottom));
    _checkBoard(board, layout, 232, 280);
  });

  test('a long line turns and has vertical and horizontal runs', () {
    final board = Board()..place(const DominoPiece(0, 1), BoardEnd.right);
    for (final p in const [
      DominoPiece(1, 2),
      DominoPiece(2, 3),
      DominoPiece(3, 4),
      DominoPiece(4, 5),
      DominoPiece(5, 6),
      DominoPiece(0, 6),
      DominoPiece(0, 2),
      DominoPiece(2, 4),
      DominoPiece(4, 6),
    ]) {
      board.place(p, BoardEnd.right);
    }
    final layout = BoardLayout.fit(board, 232, 280);

    expect(layout.tiles.any((t) => t.isVertical), isTrue);
    expect(layout.tiles.any((t) => !t.isVertical), isTrue);
    _checkBoard(board, layout, 232, 280);
  });

  for (final cfg in [
    (4, 232.0, 280.0),
    (2, 336.0, 300.0),
    (4, 232.0, 200.0),
    (4, 208.0, 320.0),
    (2, 340.0, 258.0),
  ]) {
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
              _checkBoard(
                round.board,
                BoardLayout.fit(
                  round.board,
                  cfg.$2,
                  cfg.$3,
                  ghostDouble: ghost,
                ),
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

    test(
      'placed tiles never move (${cfg.$1} players, ${cfg.$2}x${cfg.$3})',
      () {
        for (var seed = 0; seed < 60; seed++) {
          final random = Random(seed);
          final setup = Dealer.dealFirstRound(cfg.$1, random);
          final round = RoundState(
            playerCount: cfg.$1,
            hands: setup.hands,
            boneyard: setup.boneyard,
            startSeat: setup.startSeat,
            openingPiece: setup.startPiece,
          );
          double? lastSize;
          List<LayoutBox>? last;
          while (!round.isOver) {
            final moves = round.legalMoves();
            if (moves.isNotEmpty) {
              round.play(moves[random.nextInt(moves.length)]);
              final layout = BoardLayout.fit(round.board, cfg.$2, cfg.$3);
              final now = _inPlayOrder(round.board, layout);
              if (last != null && lastSize == layout.tileWidth) {
                for (var i = 0; i < last.length; i++) {
                  expect(now[i].left, closeTo(last[i].left, .01));
                  expect(now[i].top, closeTo(last[i].top, .01));
                }
              }
              last = now;
              lastSize = layout.tileWidth;
            } else if (round.playerCount == 2 && round.boneyard.isNotEmpty) {
              round.draw();
            } else {
              round.pass();
            }
          }
        }
      },
    );
  }
}
