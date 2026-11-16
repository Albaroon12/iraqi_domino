import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/engine/board.dart';
import 'package:iraqi_domino/engine/domino_piece.dart';

void main() {
  test('the first piece starts the line', () {
    final board = Board()..place(const DominoPiece(3, 5), BoardEnd.right);

    expect(board.leftEnd, 3);
    expect(board.rightEnd, 5);
  });

  test('a piece is turned so the matching half touches the end', () {
    final board = Board()..place(const DominoPiece(3, 5), BoardEnd.right);

    // 2-5 on the right end (5): its 5 touches, its 2 becomes the new end.
    board.place(const DominoPiece(2, 5), BoardEnd.right);
    expect(board.rightEnd, 2);
    expect(board.line.last.leftValue, 5);

    // 1-3 on the left end (3): its 3 touches, its 1 becomes the new end.
    board.place(const DominoPiece(1, 3), BoardEnd.left);
    expect(board.leftEnd, 1);
    expect(board.line.first.rightValue, 3);
  });

  test('a double does not branch and keeps the end number', () {
    final board = Board()..place(const DominoPiece(3, 5), BoardEnd.right);

    board.place(const DominoPiece(5, 5), BoardEnd.right);
    expect(board.rightEnd, 5);
    expect(board.line.length, 2);

    board.place(const DominoPiece(5, 6), BoardEnd.right);
    expect(board.rightEnd, 6);
  });

  test('endsFor lists the ends where a piece matches', () {
    final board = Board()..place(const DominoPiece(3, 5), BoardEnd.right);

    expect(board.endsFor(const DominoPiece(3, 5)),
        [BoardEnd.left, BoardEnd.right]);
    expect(board.endsFor(const DominoPiece(3, 6)), [BoardEnd.left]);
    expect(board.endsFor(const DominoPiece(5, 6)), [BoardEnd.right]);
    expect(board.endsFor(const DominoPiece(0, 1)), isEmpty);
  });

  test('placing a piece that does not match throws', () {
    final board = Board()..place(const DominoPiece(3, 5), BoardEnd.right);

    expect(
      () => board.place(const DominoPiece(0, 1), BoardEnd.left),
      throwsArgumentError,
    );
  });
}