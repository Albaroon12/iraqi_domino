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