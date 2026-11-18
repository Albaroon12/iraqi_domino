import '../engine/board.dart';

/// A rectangle on the table, in pixels. Pure Dart (no Flutter imports).
class LayoutBox {
  const LayoutBox(this.left, this.top, this.width, this.height);

  final double left, top, width, height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;

  /// Taller than wide.
  bool get isVertical => height > width;
}

/// A tile placed on the table.
///
/// [firstValue] is the dots on the LEFT half (horizontal tile) or the TOP
/// half (vertical tile); [secondValue] is the right or bottom half.
/// These are physical screen positions, so they never depend on the
/// language direction.
class LaidTile {
  const LaidTile(this.box, this.firstValue, this.secondValue, this.isDouble);

  final LayoutBox box;
  final int firstValue;
  final int secondValue;
  final bool isDouble;

  bool get isVertical => box.height > box.width;
}

enum _Dir {
  right(1, 0),
  down(0, 1),
  left(-1, 0),
  up(0, -1);

  const _Dir(this.dx, this.dy);
  final int dx, dy;

  /// Quarter turn clockwise on the screen (y points down).
  _Dir get cw => _Dir.values[(index + 1) % 4];
  _Dir get ccw => _Dir.values[(index + 3) % 4];
}

class _Pt {
  const _Pt(this.x, this.y);
  final double x, y;

  _Pt move(_Dir d, double distance) =>
      _Pt(x + d.dx * distance, y + d.dy * distance);
}

class _Placed {
  const _Placed(this.box, this.dir);
  final LayoutBox box;
  final _Dir dir;
}

/// Walking state of one arm of the line of play.
class _Arm {
  _Arm(this.dir, this.end, this.lastIsDouble);

  /// Direction of travel.
  _Dir dir;

  /// The far end of the last tile, on the center line of the arm.
  _Pt end;

  bool lastIsDouble;
}

/// Positions of every tile on the table.
///
/// The first piece stands VERTICALLY in the center (a double lies
/// crosswise). The arm of the right end goes down, the arm of the left end
/// goes up. When the next piece would leave the safe zone or touch another
/// piece, the arm turns 90 degrees (clockwise): the lower head turns left,
/// the upper head turns right.
///
/// DOUBLES: a double always lies crosswise to the line (wide side across)
/// and NEVER turns. It is placed straight on. The piece after it is the one
/// that turns, and it leaves from the HEAD (left or right end) of the
/// double, not from its middle. A double can only follow a normal piece on
/// the same arm (the open number stays the same, and there is only one
/// double of each number), so there is always a normal piece before it.
///
/// Pieces are placed in the order they were played ([Board.history]), so a
/// placed piece never moves (only a change of tile size moves everything).
///
/// Safe zone: an invisible margin inside the area. Normal pieces stay
/// inside [safeMargin]; doubles may use the margin (down to
/// [doubleMargin]) so they never have to turn.
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

  /// Space between two pieces.
  static const double gap = 3;

  /// Invisible safe margin for normal pieces.
  static const double safeMargin = 8;

  /// Smaller margin allowed to doubles (the exception).
  static const double doubleMargin = 2;

  static const double _eps = 0.01;

  /// Tile sizes tried from big to small until everything fits.
  /// The last two are an emergency (a very long, crowded line).
  static const List<double> sizes = [24, 22, 20, 18, 16, 14, 12, 10, 8, 7, 6];

  /// Biggest size at which the line AND one more piece on each end fit.
  /// The fit is checked with both a double and a normal piece as the extra
  /// piece, so the size does not jump when a ghost appears.
  static BoardLayout fit(
    Board board,
    double width,
    double height, {
    bool ghostDouble = false,
  }) {
    for (final w in sizes) {
      final fitsBoth = [true, false].every(
        (g) =>
            _build(board, width, height, w, ghostDouble: g, force: false) !=
            null,
      );
      if (fitsBoth) {
        return _build(
          board,
          width,
          height,
          w,
          ghostDouble: ghostDouble,
          force: false,
        )!;
      }
    }
    return _build(
      board,
      width,
      height,
      sizes.last,
      ghostDouble: ghostDouble,
      force: true,
    )!;
  }

  /// Layout at a fixed tile size. Never fails: if something does not fit,
  /// it is placed anyway (possibly outside the area).
  static BoardLayout compute(
    Board board,
    double width,
    double height,
    double w, {
    bool ghostDouble = false,
  }) => _build(board, width, height, w, ghostDouble: ghostDouble, force: true)!;

  /// The box of the very first piece (or of its ghost on an empty board):
  /// vertical, or crosswise (horizontal) for a double.
  static LayoutBox _centerBox(double cx, double cy, double w, bool isDouble) =>
      isDouble
      ? LayoutBox(cx - w, cy - w / 2, 2 * w, w)
      : LayoutBox(cx - w / 2, cy - w, w, 2 * w);

  /// Returns null when [force] is false and something does not fit.
  static BoardLayout? _build(
    Board board,
    double width,
    double height,
    double w, {
    required bool ghostDouble,
    required bool force,
  }) {
    final cx = width / 2;
    final cy = height / 2;
    final line = board.line;

    if (line.isEmpty) {
      final slot = _centerBox(cx, cy, w, ghostDouble);
      return BoardLayout(
        tileWidth: w,
        tiles: const [],
        leftSlot: slot,
        rightSlot: slot,
      );
    }

    final start = board.startIndex;
    final center = line[start];
    final centerBox = _centerBox(cx, cy, w, center.isDouble);
    // Length of the first piece along the vertical line.
    final cLen = center.isDouble ? w : 2 * w;

    // Pieces in order from the center outward, for each arm.
    final right = line.sublist(start + 1);
    final left = line.sublist(0, start).reversed.toList();

    final occupied = <LayoutBox>[centerBox];
    final rightArm = _Arm(_Dir.down, _Pt(cx, cy + cLen / 2), center.isDouble);
    final leftArm = _Arm(_Dir.up, _Pt(cx, cy - cLen / 2), center.isDouble);
    final rightPlaced = <_Placed>[];
    final leftPlaced = <_Placed>[];

    _Placed? put(_Arm arm, bool isDouble) {
      final placed = _place(
        arm,
        isDouble,
        occupied,
        width,
        height,
        w,
        force: force,
      );
      if (placed != null) occupied.add(placed.box);
      return placed;
    }

    // Replay the pieces in the order they were played.
    final history = board.history;
    var ri = 0;
    var li = 0;
    for (var i = 1; i < history.length; i++) {
      if (history[i] == BoardEnd.right) {
        final p = put(rightArm, right[ri++].isDouble);
        if (p == null) return null;
        rightPlaced.add(p);
      } else {
        final p = put(leftArm, left[li++].isDouble);
        if (p == null) return null;
        leftPlaced.add(p);
      }
    }

    // The two ghost places (where the next piece would go).
    final rightGhost = put(rightArm, ghostDouble);
    if (rightGhost == null) return null;
    final leftGhost = put(leftArm, ghostDouble);
    if (leftGhost == null) return null;

    final tiles = List<LaidTile?>.filled(line.length, null);
    // The first piece is vertical: its left value is the top half.
    tiles[start] = LaidTile(
      centerBox,
      center.leftValue,
      center.rightValue,
      center.isDouble,
    );

    for (var i = 0; i < right.length; i++) {
      final p = right[i];
      final placed = rightPlaced[i];
      // Right arm: the left half touches the previous piece.
      final v = _values(placed.dir, p.leftValue, p.rightValue);
      tiles[start + 1 + i] = LaidTile(placed.box, v.$1, v.$2, p.isDouble);
    }

    for (var i = 0; i < left.length; i++) {
      final p = left[i];
      final placed = leftPlaced[i];
      // Left arm: the right half touches the previous piece.
      final v = _values(placed.dir, p.rightValue, p.leftValue);
      tiles[start - 1 - i] = LaidTile(placed.box, v.$1, v.$2, p.isDouble);
    }

    return BoardLayout(
      tileWidth: w,
      tiles: [for (final t in tiles) t!],
      leftSlot: leftGhost.box,
      rightSlot: rightGhost.box,
    );
  }

  /// (first, second) = (left or top half, right or bottom half) of a piece
  /// that travels in [dir], given the value that touches the previous piece
  /// ([toward]) and the value on the far half ([outward]).
  static (int, int) _values(_Dir dir, int toward, int outward) => switch (dir) {
    _Dir.right || _Dir.down => (toward, outward),
    _Dir.left || _Dir.up => (outward, toward),
  };

  /// Puts the next piece of [arm].
  ///
  /// - A double goes straight on, crosswise, or does not fit (it never
  ///   turns, and is never forced to lie lengthwise).
  /// - A normal piece goes straight on if it fits, otherwise it turns 90
  ///   degrees (clockwise first, then counter-clockwise). After a normal
  ///   piece it starts beside the middle of the last half; after a double
  ///   it starts beside the HEAD of the double.
  ///
  /// Returns null if nothing fits and [force] is false.
  static _Placed? _place(
    _Arm arm,
    bool isDouble,
    List<LayoutBox> occupied,
    double width,
    double height,
    double w, {
    required bool force,
  }) {
    final len = isDouble ? w : 2 * w;
    final thick = isDouble ? 2 * w : w;
    // A normal piece keeps half a tile of room ahead, so the next piece can
    // always turn after it.
    final ahead = isDouble ? 0.0 : w / 2;
    final margin = isDouble ? doubleMargin : safeMargin;

    bool free(_Dir dir, _Pt start) => _isFree(
      _boxAt(start, dir, len, thick),
      // Zone that must be inside the area: as thick as a double.
      _boxAt(start, dir, len + ahead, 2 * w),
      margin,
      occupied,
      width,
      height,
    );

    _Placed commit(_Dir dir, _Pt start) {
      final box = _boxAt(start, dir, len, thick);
      arm.dir = dir;
      arm.end = start.move(dir, len);
      arm.lastIsDouble = isDouble;
      return _Placed(box, dir);
    }

    final straight = arm.end.move(arm.dir, gap);
    if (free(arm.dir, straight)) return commit(arm.dir, straight);

    // A double NEVER turns.
    if (isDouble) return force ? commit(arm.dir, straight) : null;

    // Turn: the new line goes through the center of the last half (or of
    // the double) and starts beside it. After a double, "beside" means at
    // its head: one tile width away from the line.
    final corner = arm.end.move(arm.dir, -w / 2);
    final reach = (arm.lastIsDouble ? w : w / 2) + gap;
    for (final d in [arm.dir.cw, arm.dir.ccw]) {
      final s = corner.move(d, reach);
      if (free(d, s)) return commit(d, s);
    }

    if (!force) return null;
    return commit(arm.dir.cw, corner.move(arm.dir.cw, reach));
  }

  /// The box of a piece whose near edge is at [p] and that travels in [dir].
  /// [thick] is centered on the line through [p].
  static LayoutBox _boxAt(_Pt p, _Dir dir, double len, double thick) =>
      switch (dir) {
        _Dir.right => LayoutBox(p.x, p.y - thick / 2, len, thick),
        _Dir.left => LayoutBox(p.x - len, p.y - thick / 2, len, thick),
        _Dir.down => LayoutBox(p.x - thick / 2, p.y, thick, len),
        _Dir.up => LayoutBox(p.x - thick / 2, p.y - len, thick, len),
      };

  /// The [zone] is inside the area (kept [margin] away from its edge), and
  /// the real [box] is at least [gap] away from every placed box.
  static bool _isFree(
    LayoutBox box,
    LayoutBox zone,
    double margin,
    List<LayoutBox> occupied,
    double width,
    double height,
  ) {
    if (zone.left < margin - _eps ||
        zone.top < margin - _eps ||
        zone.right > width - margin + _eps ||
        zone.bottom > height - margin + _eps) {
      return false;
    }
    for (final o in occupied) {
      if (box.left < o.right + gap - _eps &&
          o.left < box.right + gap - _eps &&
          box.top < o.bottom + gap - _eps &&
          o.top < box.bottom + gap - _eps) {
        return false;
      }
    }
    return true;
  }
}
