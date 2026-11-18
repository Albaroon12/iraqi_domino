import 'domino_piece.dart';

/// One of the two open ends of the line of play.
enum BoardEnd { left, right }

/// A piece lying on the table. [leftValue] and [rightValue] are the dots
/// on its left and right half, as seen along the line of play.
/// The orientation is chosen automatically when the piece is placed.
class PlacedPiece {
  const PlacedPiece(this.piece, this.leftValue, this.rightValue);

  final DominoPiece piece;
  final int leftValue;
  final int rightValue;

  /// Doubles are drawn crosswise and never create a branch.
  bool get isDouble => piece.isDouble;
}

/// A legal move: play [piece] on [end].
class Move {
  const Move(this.piece, this.end);

  final DominoPiece piece;
  final BoardEnd end;

  @override
  bool operator ==(Object other) =>
      other is Move && other.piece == piece && other.end == end;

  @override
  int get hashCode => Object.hash(piece, end);

  @override
  String toString() => '$piece on ${end.name}';
}

/// The single line of play (no branches in the standard mode).
/// Pure Dart: no Flutter imports.
class Board {
  final List<PlacedPiece> _line = [];
  final List<BoardEnd> _history = [];

  int _leftCount = 0;

  /// Index (in [line]) of the first piece played: the center of the layout.
  int get startIndex => _leftCount;

  /// Pieces from the left end to the right end.
  List<PlacedPiece> get line => List.unmodifiable(_line);

  /// The end used by every placement, in the order the pieces were played.
  /// The first entry is the opening piece (always [BoardEnd.right]).
  /// The layout replays this order so a piece never moves once placed.
  List<BoardEnd> get history => List.unmodifiable(_history);

  bool get isEmpty => _line.isEmpty;

  /// The open number on each end (null while the board is empty).
  int? get leftEnd => isEmpty ? null : _line.first.leftValue;
  int? get rightEnd => isEmpty ? null : _line.last.rightValue;

  /// The ends where [piece] could be played.
  /// On an empty board the piece simply starts the line.
  /// (Which piece may open the round is decided by RoundState.)
  List<BoardEnd> endsFor(DominoPiece piece) {
    if (isEmpty) return const [BoardEnd.right];
    return [
      if (piece.hasSide(leftEnd!)) BoardEnd.left,
      if (piece.hasSide(rightEnd!)) BoardEnd.right,
    ];
  }

  /// Places [piece] on [end], turning it so the matching half touches
  /// the open end. Throws if the move is not legal.
  void place(DominoPiece piece, BoardEnd end) {
    if (!endsFor(piece).contains(end)) {
      throw ArgumentError('$piece cannot be played on ${end.name}');
    }

    _history.add(end);

    if (isEmpty) {
      _line.add(PlacedPiece(piece, piece.low, piece.high));
      return;
    }

    if (end == BoardEnd.right) {
      final touching = rightEnd!;
      final outer = piece.low == touching ? piece.high : piece.low;
      _line.add(PlacedPiece(piece, touching, outer));
    } else {
      final touching = leftEnd!;
      final outer = piece.low == touching ? piece.high : piece.low;
      _line.insert(0, PlacedPiece(piece, outer, touching));
      _leftCount++;
    }
  }
}
