import '../engine/board.dart';

/// A rectangle on the table, in pixels. Pure Dart (no Flutter imports).
class LayoutBox {
  const LayoutBox(this.left, this.top, this.width, this.height);

  final double left, top, width, height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerY => top + height / 2;
}

/// A tile placed on the table. [leftValue] and [rightValue] are the dots
/// on the PHYSICAL left and right halves, so they never depend on the
/// language direction.
class LaidTile {
  const LaidTile(this.box, this.leftValue, this.rightValue, this.isDouble);

  final LayoutBox box;
  final int leftValue;
  final int rightValue;
  final bool isDouble;
}

class _Placed {
  const _Placed(this.box, this.movesRight);
  final LayoutBox box;
  final bool movesRight;
}

/// Positions of every tile on the table.
///
/// The first piece is in the center. The right arm grows to the right and,
/// at the edge, turns DOWN into the next row (going left). The left arm
/// mirrors it: grows left, turns UP. At a turn the new tile sits right
/// below the last one, so the two touching numbers are above each other.
/// A placed tile never moves (only a size change moves everything).
class BoardLayout {
  const BoardLayout({
    required this.tileWidth,
    required this.tiles,
    required this.leftSlot,
    required this.rightSlot,
  });

  final double tileWidth;

  /// One per piece of the board line, in the same order.
  final List<LaidTile> tiles;

  /// Where the next piece will go on each end (the lit ghost tile).
  final LayoutBox leftSlot;
  final LayoutBox rightSlot;

  static const double gap = 3;

  /// Tile sizes tried from big to small until everything fits.
  static const List<double> sizes = [30, 26, 22, 20, 18, 16, 14, 12];

  /// Biggest size at which the line AND one more piece on each end fit.
  /// The fit is always checked with a double as the extra piece (the
  /// biggest), so the size does not jump when a ghost appears.
  static BoardLayout fit(
    Board board,
    double width,
    double height, {
    bool ghostDouble = false,
  }) {
    for (final w in sizes) {
      if (compute(board, width, height, w, ghostDouble: true)
          ._fits(width, height)) {
        return compute(board, width, height, w, ghostDouble: ghostDouble);
      }
    }
    return compute(board, width, height, sizes.last, ghostDouble: ghostDouble);
  }

  static BoardLayout compute(
    Board board,
    double width,
    double height,
    double w, {
    bool ghostDouble = false,
  }) {
    final cx = width / 2;
    final cy = height / 2;
    final line = board.line;

    if (line.isEmpty) {
      final slot = ghostDouble
          ? LayoutBox(cx - w / 2, cy - w, w, 2 * w)
          : LayoutBox(cx - w, cy - w / 2, 2 * w, w);
      return BoardLayout(
        tileWidth: w,
        tiles: const [],
        leftSlot: slot,
        rightSlot: slot,
      );
    }

    final start = board.startIndex;
    final center = line[start];
    final cLen = center.isDouble ? w : 2 * w;
    final cThick = center.isDouble ? 2 * w : w;
    final centerBox = LayoutBox(cx - cLen / 2, cy - cThick / 2, cLen, cThick);

    // Pieces in order from the center outward, for each arm.
    final right = line.sublist(start + 1);
    final left = line.sublist(0, start).reversed.toList();

    final armStart = cx + cLen / 2 + gap;
    final rightBoxes = _arm(
      [for (final p in right) p.isDouble, ghostDouble],
      armStart, width, height, w,
    );
    // The left arm is laid out like the right one, then rotated 180 degrees
    // around the center of the table (rows go up, direction flips).
    final leftFrame = _arm(
      [for (final p in left) p.isDouble, ghostDouble],
      armStart, width, height, w,
    );
    _Placed turn(_Placed p) => _Placed(
          LayoutBox(
            width - p.box.right,
            height - p.box.bottom,
            p.box.width,
            p.box.height,
          ),
          !p.movesRight,
        );

    final tiles = List<LaidTile?>.filled(line.length, null);
    tiles[start] = LaidTile(
      centerBox,
      center.leftValue,
      center.rightValue,
      center.isDouble,
    );

    for (var i = 0; i < right.length; i++) {
      final p = right[i];
      final placed = rightBoxes[i];
      // Right arm: the left half touches the center, the right half is out.
      final toward = p.leftValue;
      final outward = p.rightValue;
      tiles[start + 1 + i] = LaidTile(
        placed.box,
        placed.movesRight ? toward : outward,
        placed.movesRight ? outward : toward,
        p.isDouble,
      );
    }

    for (var i = 0; i < left.length; i++) {
      final p = left[i];
      final placed = turn(leftFrame[i]);
      // Left arm: the right half touches the center, the left half is out.
      final toward = p.rightValue;
      final outward = p.leftValue;
      tiles[start - 1 - i] = LaidTile(
        placed.box,
        placed.movesRight ? toward : outward,
        placed.movesRight ? outward : toward,
        p.isDouble,
      );
    }

    return BoardLayout(
      tileWidth: w,
      tiles: [for (final t in tiles) t!],
      leftSlot: turn(leftFrame.last).box,
      rightSlot: rightBoxes.last.box,
    );
  }

  /// Lays out one arm (in the "right arm" frame): [doubles] tells, for each
  /// piece from the center outward, whether it is a double.
  static List<_Placed> _arm(
    List<bool> doubles,
    double startX,
    double width,
    double height,
    double w,
  ) {
    final pitch = 2 * w + 4; // row distance; leaves room for crosswise doubles
    final cy = height / 2;
    final out = <_Placed>[];

    var row = 0;
    var right = true;
    var x = startX; // moving right: left edge of the next tile; else right edge
    var inRow = 0;
    var prevLeft = 0.0;
    var prevRight = 0.0;

    for (final isDouble in doubles) {
      final len = isDouble ? w : 2 * w;
      final thick = isDouble ? 2 * w : w;

      final fits = right ? x + len <= width : x - len >= 0;
      if (!fits && inRow > 0) {
        // Turn: start the next row right below the previous tile.
        row++;
        right = !right;
        x = right ? prevLeft : prevRight;
        inRow = 0;
      }

      final double left;
      if (right) {
        left = x;
        x = x + len + gap;
      } else {
        left = x - len;
        x = left - gap;
      }

      final box = LayoutBox(left, cy + row * pitch - thick / 2, len, thick);
      out.add(_Placed(box, right));
      prevLeft = box.left;
      prevRight = box.right;
      inRow++;
    }
    return out;
  }

  bool _fits(double width, double height) {
    bool inside(LayoutBox b) =>
        b.left >= -0.01 &&
        b.top >= -0.01 &&
        b.right <= width + 0.01 &&
        b.bottom <= height + 0.01;
    return tiles.every((t) => inside(t.box)) &&
        inside(leftSlot) &&
        inside(rightSlot);
  }
}