import '../engine/board.dart';
import 'board_layout.dart' show LaidTile, LayoutBox;

/// Direction of travel of one piece along the line of play.
enum _Dir { down, up, left, right }

class _Placed {
  const _Placed(this.box, this.travel);
  final LayoutBox box;
  final _Dir travel;
}

/// Walking state of one arm of the line of play.
class _Arm {
  _Arm({
    required this.sign,
    required this.dir,
    required this.x,
    required this.edge,
    required this.last,
  });

  /// -1: this arm turns toward the LEFT of the screen, +1: toward the RIGHT.
  final int sign;

  /// +1 = moving down the screen, -1 = moving up.
  int dir;

  /// Center line (x) of the current column.
  double x;

  /// Far edge (y) of the last piece, in the direction of travel.
  double edge;

  /// Box of the last piece placed on this arm.
  LayoutBox last;
}

/// The serpentine layout of the line of play. Pure Dart.
///
/// - The tile size is FIXED: it depends only on the size of the area, never
///   on how many pieces are on the board.
/// - The first piece stands vertically in the center (a double lies
///   crosswise). The right-end arm goes DOWN, the left-end arm goes UP.
/// - When the next piece does not fit in the column, it is placed
///   horizontally BESIDE the last half of the last piece (the lower arm
///   turns left, the upper arm turns right). The next column starts above
///   or below that horizontal piece, one tile-width away from the old
///   column, and runs the opposite way (down becomes up, up becomes down).
/// - A double lies crosswise to the line and never turns.
/// - The two arms are independent, so a placed piece never moves.
class SerpentineLayout {
  const SerpentineLayout({
    required this.tileWidth,
    required this.tiles,
    required this.leftSlot,
    required this.rightSlot,
    required this.overflow,
  });

  final double tileWidth;

  /// One per piece of the board line, in the same order as Board.line.
  final List<LaidTile> tiles;

  /// Where the next piece will go on each end (the ghost tile).
  final LayoutBox leftSlot;
  final LayoutBox rightSlot;

  /// True if some piece had to be drawn outside the area (an arm is full).
  final bool overflow;

  /// Space between two pieces.
  static const double gap = 2;

  /// Invisible safe margin for normal pieces.
  static const double margin = 4;

  /// Smaller margin allowed to doubles.
  static const double doubleMargin = 1;

  /// The tile size is the biggest one where EACH arm can still hold at
  /// least this many pieces (26 pieces = 1 center + 2 x 12).
  /// Lower it for bigger tiles (but long rounds may overflow).
  static const int minArmTiles = 12;

  static const double maxTileWidth = 26;
  static const double minTileWidth = 8;

  static const double _eps = 0.01;

  /// The fixed tile width for an area. Depends on the area ONLY.
  static double tileWidthFor(double width, double height) {
    for (var w = maxTileWidth; w >= minTileWidth; w -= 1) {
      if (armCapacity(width, height, w) >= minArmTiles) return w;
    }
    return minTileWidth;
  }

  /// How many normal pieces one arm holds inside the area at width [w].
  static int armCapacity(double width, double height, double w) {
    final cx = width / 2;
    final center = _centerBox(cx, height / 2, w, false);
    final arm = _Arm(sign: -1, dir: 1, x: cx, edge: center.bottom, last: center);
    var n = 0;
    while (n < 200 && _next(arm, false, w, width, height, force: false) != null) {
      n++;
    }
    return n;
  }

  /// Layout with the fixed tile width of this area.
  static SerpentineLayout fit(
    Board board,
    double width,
    double height, {
    bool ghostDouble = false,
  }) => compute(
    board,
    width,
    height,
    tileWidthFor(width, height),
    ghostDouble: ghostDouble,
  );

  /// Layout at a given tile width. Never fails: pieces that do not fit are
  /// placed anyway (outside the area) and [overflow] is set.
  static SerpentineLayout compute(
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
      final slot = _centerBox(cx, cy, w, ghostDouble);
      return SerpentineLayout(
        tileWidth: w,
        tiles: const [],
        leftSlot: slot,
        rightSlot: slot,
        overflow: false,
      );
    }

    final start = board.startIndex;
    final center = line[start];
    final centerBox = _centerBox(cx, cy, w, center.isDouble);

    // Pieces in order from the center outward, for each arm.
    final right = line.sublist(start + 1);
    final left = line.sublist(0, start).reversed.toList();

    // Right end = lower arm (goes down, turns left).
    // Left end = upper arm (goes up, turns right).
    final lower = _Arm(
      sign: -1,
      dir: 1,
      x: cx,
      edge: centerBox.bottom,
      last: centerBox,
    );
    final upper = _Arm(
      sign: 1,
      dir: -1,
      x: cx,
      edge: centerBox.top,
      last: centerBox,
    );

    final rightPlaced = [
      for (final p in right) _next(lower, p.isDouble, w, width, height, force: true)!,
    ];
    final leftPlaced = [
      for (final p in left) _next(upper, p.isDouble, w, width, height, force: true)!,
    ];

    final rightGhost = _next(lower, ghostDouble, w, width, height, force: true)!;
    final leftGhost = _next(upper, ghostDouble, w, width, height, force: true)!;

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
      final v = _values(placed.travel, p.leftValue, p.rightValue);
      tiles[start + 1 + i] = LaidTile(placed.box, v.$1, v.$2, p.isDouble);
    }
    for (var i = 0; i < left.length; i++) {
      final p = left[i];
      final placed = leftPlaced[i];
      // Left arm: the right half touches the previous piece.
      final v = _values(placed.travel, p.rightValue, p.leftValue);
      tiles[start - 1 - i] = LaidTile(placed.box, v.$1, v.$2, p.isDouble);
    }

    final all = [for (final t in tiles) t!];
    final overflow = all.any((t) => !_within(t.box, 0, width, height));

    return SerpentineLayout(
      tileWidth: w,
      tiles: all,
      leftSlot: leftGhost.box,
      rightSlot: rightGhost.box,
      overflow: overflow,
    );
  }

  /// First piece: vertical, or crosswise (horizontal) for a double.
  static LayoutBox _centerBox(double cx, double cy, double w, bool isDouble) =>
      isDouble
      ? LayoutBox(cx - w, cy - w / 2, 2 * w, w)
      : LayoutBox(cx - w / 2, cy - w, w, 2 * w);

  /// (first, second) = (left or top half, right or bottom half) of a piece
  /// travelling in [dir], given the value that touches the previous piece
  /// ([toward]) and the value on the far half ([outward]).
  static (int, int) _values(_Dir dir, int toward, int outward) => switch (dir) {
    _Dir.right || _Dir.down => (toward, outward),
    _Dir.left || _Dir.up => (outward, toward),
  };

  static bool _within(LayoutBox b, double m, double width, double height) =>
      b.left >= m - _eps &&
      b.top >= m - _eps &&
      b.right <= width - m + _eps &&
      b.bottom <= height - m + _eps;

  /// Puts the next piece of [a] and moves the arm forward.
  /// Returns null if nothing fits and [force] is false.
  static _Placed? _next(
    _Arm a,
    bool isDouble,
    double w,
    double width,
    double height, {
    required bool force,
  }) {
    final len = isDouble ? w : 2 * w;
    final thick = isDouble ? 2 * w : w;
    final m = isDouble ? doubleMargin : margin;

    // Straight on, in the same column.
    final top = a.dir > 0 ? a.edge + gap : a.edge - gap - len;
    final straight = LayoutBox(a.x - thick / 2, top, thick, len);

    if (_within(straight, m, width, height) || (isDouble && force)) {
      a.edge = a.dir > 0 ? straight.bottom : straight.top;
      a.last = straight;
      return _Placed(straight, a.dir > 0 ? _Dir.down : _Dir.up);
    }

    // A double NEVER turns.
    if (isDouble) return null;

    // Turn: a horizontal piece beside the last half of the last piece
    // (or beside the head of a double).
    final last = a.last;
    final halfTop = last.isVertical
        ? (a.dir > 0 ? last.bottom - w : last.top)
        : last.top;
    final turnLeft = a.sign < 0 ? last.left - gap - 2 * w : last.right + gap;
    final turn = LayoutBox(turnLeft, halfTop, 2 * w, w);

    if (!_within(turn, margin, width, height) && !force) return null;

    // The new column goes through the outer half of the turn piece.
    a.x = a.sign < 0 ? turn.left + w / 2 : turn.right - w / 2;
    a.dir = -a.dir;
    a.edge = a.dir > 0 ? turn.bottom : turn.top;
    a.last = turn;
    return _Placed(turn, a.sign < 0 ? _Dir.left : _Dir.right);
  }
}