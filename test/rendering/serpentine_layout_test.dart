import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/engine/board.dart';
import 'package:iraqi_domino/engine/dealer.dart';
import 'package:iraqi_domino/engine/domino_piece.dart';
import 'package:iraqi_domino/engine/round_state.dart';
import 'package:iraqi_domino/rendering/board_layout.dart'
    show LaidTile, LayoutBox;
import 'package:iraqi_domino/rendering/serpentine_layout.dart';

bool _overlap(LayoutBox a, LayoutBox b) =>
    a.left < b.right - .01 &&
    b.left < a.right - .01 &&
    a.top < b.bottom - .01 &&
    b.top < a.bottom - .01;

bool _inside(LayoutBox b, double width, double height) =>
    b.left >= -.01 &&
    b.top >= -.01 &&
    b.right <= width + .01 &&
    b.bottom <= height + .01;

/// The two touching surfaces of a tile (a double is one surface).
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
  const gap = SerpentineLayout.gap;
  final overlapX = min(a.right, b.right) - max(a.left, b.left);
  final overlapY = min(a.bottom, b.bottom) - max(a.top, b.top);
  final sideBySide =
      overlapY > .75 * w &&
      ((a.right + gap - b.left).abs() < tol ||
          (b.right + gap - a.left).abs() < tol);
  final stacked =
      overlapX > .75 * w &&
      ((a.bottom + gap - b.top).abs() < tol ||
          (b.bottom + gap - a.top).abs() < tol);
  return sideBySide || stacked;
}

/// Checks a layout that does not overflow.
void _check(SerpentineLayout layout, double width, double height) {
  final w = layout.tileWidth;

  for (final t in layout.tiles) {
    expect(max(t.box.width, t.box.height), closeTo(2 * w, .01));
    expect(min(t.box.width, t.box.height), closeTo(w, .01));
    expect(_inside(t.box, width, height), isTrue, reason: 'tile outside');
  }

  for (var i = 0; i < layout.tiles.length; i++) {
    for (var j = i + 1; j < layout.tiles.length; j++) {
      expect(
        _overlap(layout.tiles[i].box, layout.tiles[j].box),
        isFalse,
        reason: 'tiles $i and $j overlap',
      );
    }
  }

  // A ghost that is visible must not sit on a tile.
  for (final g in [layout.leftSlot, layout.rightSlot]) {
    if (!_inside(g, width, height)) continue;
    for (final t in layout.tiles) {
      expect(_overlap(g, t.box), isFalse, reason: 'ghost on a tile');
    }
  }

  // Neighbours in the line touch on screen, with equal numbers.
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

/// Pieces from [first], each one placed on the right end.
Board _rightChain() {
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
  return board;
}

/// Pieces placed on the left end.
Board _leftChain() {
  final board = Board()..place(const DominoPiece(0, 1), BoardEnd.right);
  for (final p in const [
    DominoPiece(0, 2),
    DominoPiece(2, 3),
    DominoPiece(3, 4),
    DominoPiece(4, 5),
    DominoPiece(5, 6),
    DominoPiece(1, 6),
    DominoPiece(1, 3),
    DominoPiece(3, 5),
  ]) {
    board.place(p, BoardEnd.left);
  }
  return board;
}

RoundState _newRound(int players, Random random) {
  final setup = Dealer.dealFirstRound(players, random);
  return RoundState(
    playerCount: players,
    hands: setup.hands,
    boneyard: setup.boneyard,
    startSeat: setup.startSeat,
    openingPiece: setup.startPiece,
  );
}

/// The boxes of the tiles in the order they were played.
List<LayoutBox> _inPlayOrder(Board board, SerpentineLayout layout) {
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
  test('the tile size depends only on the area, never on the pieces', () {
    final empty = SerpentineLayout.fit(Board(), 215, 215);
    final one = SerpentineLayout.fit(
      Board()..place(const DominoPiece(1, 4), BoardEnd.right),
      215,
      215,
    );
    final many = SerpentineLayout.fit(_rightChain(), 215, 215);

    expect(one.tileWidth, empty.tileWidth);
    expect(many.tileWidth, empty.tileWidth);
  });

  test('each arm can hold the minimum number of pieces', () {
    for (final size in [179.0, 215.0, 300.0]) {
      final w = SerpentineLayout.tileWidthFor(size, size);
      expect(
        SerpentineLayout.armCapacity(size, size, w),
        greaterThanOrEqualTo(SerpentineLayout.minArmTiles),
        reason: 'size $size, tile width $w',
      );
    }
  });

  test('the first piece is vertical in the center', () {
    final board = Board()..place(const DominoPiece(1, 4), BoardEnd.right);
    final layout = SerpentineLayout.fit(board, 215, 215);

    final box = layout.tiles.single.box;
    expect(box.isVertical, isTrue);
    expect(box.centerX, closeTo(215 / 2, .01));
    expect(box.centerY, closeTo(215 / 2, .01));
  });

  test('a double as the first piece lies crosswise', () {
    final board = Board()..place(const DominoPiece(6, 6), BoardEnd.right);
    final layout = SerpentineLayout.fit(board, 215, 215);

    final box = layout.tiles.single.box;
    expect(box.width, closeTo(2 * layout.tileWidth, .01));
    expect(box.height, closeTo(layout.tileWidth, .01));
  });

  test('the right end goes down and the left end goes up', () {
    final board = Board()
      ..place(const DominoPiece(3, 5), BoardEnd.right)
      ..place(const DominoPiece(5, 6), BoardEnd.right)
      ..place(const DominoPiece(2, 3), BoardEnd.left);
    final layout = SerpentineLayout.fit(board, 215, 215);

    final up = layout.tiles[0];
    final mid = layout.tiles[1];
    final down = layout.tiles[2];

    expect(up.box.bottom, lessThan(mid.box.top));
    expect(down.box.top, greaterThan(mid.box.bottom));
    expect(up.box.centerX, closeTo(mid.box.centerX, .01));
    expect(down.box.centerX, closeTo(mid.box.centerX, .01));

    // Numbers touch: 3 above the center, 5 below it.
    expect([mid.firstValue, mid.secondValue], [3, 5]);
    expect([up.firstValue, up.secondValue], [2, 3]);
    expect([down.firstValue, down.secondValue], [5, 6]);
    _check(layout, 215, 215);
  });

  test('the lower arm turns left with a horizontal piece', () {
    final layout = SerpentineLayout.fit(_rightChain(), 215, 215);

    expect(layout.overflow, isFalse);
    final turns = layout.tiles.where((t) => !t.isVertical).toList();
    expect(turns, isNotEmpty);
    for (final t in turns) {
      expect(t.box.right, lessThan(215 / 2));
    }
    _check(layout, 215, 215);
  });

  test('the upper arm turns right with a horizontal piece', () {
    final layout = SerpentineLayout.fit(_leftChain(), 215, 215);

    expect(layout.overflow, isFalse);
    final turns = layout.tiles.where((t) => !t.isVertical).toList();
    expect(turns, isNotEmpty);
    for (final t in turns) {
      expect(t.box.left, greaterThan(215 / 2));
    }
    _check(layout, 215, 215);
  });

  for (final cfg in [
    (4, 179.0, 179.0),
    (2, 215.0, 215.0),
    (4, 215.0, 215.0),
    (2, 300.0, 300.0),
    (4, 200.0, 260.0),
  ]) {
    test('valid layouts for ${cfg.$1} players in ${cfg.$2} x ${cfg.$3}', () {
      var checked = 0;
      for (var seed = 0; seed < 100; seed++) {
        final random = Random(seed);
        final round = _newRound(cfg.$1, random);
        while (!round.isOver) {
          final moves = round.legalMoves();
          if (moves.isNotEmpty) {
            round.play(moves[random.nextInt(moves.length)]);
            for (final ghost in [false, true]) {
              final layout = SerpentineLayout.fit(
                round.board,
                cfg.$2,
                cfg.$3,
                ghostDouble: ghost,
              );
              // A full arm may overflow: that is allowed, not checked here.
              if (layout.overflow) continue;
              checked++;
              _check(layout, cfg.$2, cfg.$3);
            }
          } else if (round.playerCount == 2 && round.boneyard.isNotEmpty) {
            round.draw();
          } else {
            round.pass();
          }
        }
      }
      expect(checked, greaterThan(0));
    });

    test('placed tiles never move (${cfg.$1} players, ${cfg.$2}x${cfg.$3})', () {
      for (var seed = 0; seed < 60; seed++) {
        final random = Random(seed);
        final round = _newRound(cfg.$1, random);
        List<LayoutBox>? last;
        while (!round.isOver) {
          final moves = round.legalMoves();
          if (moves.isNotEmpty) {
            round.play(moves[random.nextInt(moves.length)]);
            final layout = SerpentineLayout.fit(round.board, cfg.$2, cfg.$3);
            final now = _inPlayOrder(round.board, layout);
            if (last != null) {
              for (var i = 0; i < last.length; i++) {
                expect(now[i].left, closeTo(last[i].left, .01));
                expect(now[i].top, closeTo(last[i].top, .01));
              }
            }
            last = now;
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