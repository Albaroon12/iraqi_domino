/// One piece of the double-six domino set.
/// Pure Dart: no Flutter imports, so it can be unit-tested and reused
/// on a future server.
class DominoPiece implements Comparable<DominoPiece> {
  /// [low] must be <= [high], so every piece has exactly one representation
  /// (there is no separate "5-2" and "2-5").
  const DominoPiece(this.low, this.high)
      : assert(low >= 0 && high <= 6 && low <= high);

  final int low;
  final int high;

  bool get isDouble => low == high;

  /// Total number of dots (used for scoring).
  int get pips => low + high;

  /// True if one of the two halves shows [value].
  bool hasSide(int value) => low == value || high == value;

  /// The 28 pieces of the double-six set: 0-0, 0-1 ... 6-6.
  static List<DominoPiece> fullSet() => [
        for (var a = 0; a <= 6; a++)
          for (var b = a; b <= 6; b++) DominoPiece(a, b),
      ];

  @override
  bool operator ==(Object other) =>
      other is DominoPiece && other.low == low && other.high == high;

  @override
  int get hashCode => Object.hash(low, high);

  /// Sorting order: by the low half, then the high half.
  @override
  int compareTo(DominoPiece other) =>
      low != other.low ? low.compareTo(other.low) : high.compareTo(other.high);

  @override
  String toString() => '$low-$high';
}