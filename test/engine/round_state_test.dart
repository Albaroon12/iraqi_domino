import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/engine/board.dart';
import 'package:iraqi_domino/engine/domino_piece.dart';
import 'package:iraqi_domino/engine/round_result.dart';
import 'package:iraqi_domino/engine/round_state.dart';

const _sixSix = Move(DominoPiece(6, 6), BoardEnd.right);

/// A four-player round where seat 0 opens with 6-6.
RoundState _fourPlayers(List<List<DominoPiece>> hands) => RoundState(
  playerCount: 4,
  hands: hands,
  boneyard: const [],
  startSeat: 0,
  openingPiece: const DominoPiece(6, 6),
);

void main() {
  test('the opening move is limited to the opening piece', () {
    final round = _fourPlayers(const [
      [DominoPiece(6, 6), DominoPiece(1, 2)],
      [DominoPiece(3, 4)],
      [DominoPiece(0, 5)],
      [DominoPiece(2, 2)],
    ]);

    expect(round.legalMoves(), [_sixSix]);
  });

  test('legal moves are computed for the player whose turn it is', () {
    final round = _fourPlayers(const [
      [DominoPiece(6, 6), DominoPiece(1, 2)],
      [DominoPiece(3, 6), DominoPiece(1, 2)],
      [DominoPiece(0, 5)],
      [DominoPiece(2, 2)],
    ]);

    round.play(_sixSix);

    expect(round.turn, 1);
    expect(round.legalMoves(), [
      const Move(DominoPiece(3, 6), BoardEnd.left),
      const Move(DominoPiece(3, 6), BoardEnd.right),
    ]);
  });

  test('an illegal move is rejected', () {
    final round = _fourPlayers(const [
      [DominoPiece(6, 6), DominoPiece(1, 2)],
      [DominoPiece(3, 4)],
      [DominoPiece(0, 5)],
      [DominoPiece(2, 2)],
    ]);

    expect(
      () => round.play(const Move(DominoPiece(1, 2), BoardEnd.right)),
      throwsStateError,
    );
  });

  test('a player with a legal move cannot pass', () {
    final round = _fourPlayers(const [
      [DominoPiece(6, 6), DominoPiece(1, 2)],
      [DominoPiece(3, 4)],
      [DominoPiece(0, 5)],
      [DominoPiece(2, 2)],
    ]);

    expect(round.pass, throwsStateError);
  });

  test('domino: the team of the winner scores the OPPONENTS pips only', () {
    final round = _fourPlayers(const [
      [DominoPiece(6, 6)],
      [DominoPiece(1, 2)], // opponent: 3
      [DominoPiece(0, 3), DominoPiece(0, 0)], // partner: 3, not counted
      [DominoPiece(4, 4)], // opponent: 8
    ]);

    round.play(_sixSix);

    expect(round.isOver, isTrue);
    expect(round.result!.kind, RoundEndKind.domino);
    expect(round.result!.winnerTeam, 0);
    expect(round.result!.winnerSeat, 0);
    expect(round.result!.points, 11);
  });

  test('blocked: the lowest total wins and scores the opponents pips', () {
    final round = _fourPlayers(const [
      [DominoPiece(6, 6), DominoPiece(0, 1)], // left: 1
      [DominoPiece(2, 3)], // 5
      [DominoPiece(4, 5)], // 9
      [DominoPiece(1, 2)], // 3
    ]);

    round.play(_sixSix);
    for (var i = 0; i < 4; i++) {
      round.pass();
    }

    expect(round.result!.kind, RoundEndKind.blocked);
    expect(round.result!.winnerTeam, 0);
    expect(round.result!.winnerSeat, 0);
    expect(round.result!.points, 8); // seats 1 and 3: 5 + 3
  });

  test('blocked: a tie between different teams burns the round', () {
    final round = _fourPlayers(const [
      [DominoPiece(6, 6), DominoPiece(0, 2)], // 2
      [DominoPiece(1, 1)], // 2
      [DominoPiece(4, 5)], // 9
      [DominoPiece(3, 4)], // 7
    ]);

    round.play(_sixSix);
    for (var i = 0; i < 4; i++) {
      round.pass();
    }

    expect(round.result!.kind, RoundEndKind.burned);
    expect(round.result!.points, 0);
    expect(round.result!.winnerTeam, isNull);
  });

  test(
    'blocked: a tie inside one team wins; the closest to the blocker starts',
    () {
      final round = _fourPlayers(const [
        [DominoPiece(6, 6), DominoPiece(0, 4)], // 4
        [DominoPiece(1, 6), DominoPiece(3, 3)], // plays 6-1, keeps 6
        [DominoPiece(2, 2)], // 4
        [DominoPiece(3, 4)], // 7
      ]);

      round.play(_sixSix); // seat 0
      round.play(const Move(DominoPiece(1, 6), BoardEnd.right)); // seat 1
      for (var i = 0; i < 4; i++) {
        round.pass(); // seats 2, 3, 0, 1
      }

      // Lowest: seats 0 and 2 (both 4), same team. The blocker is seat 1,
      // so seat 2 is the closest in play order.
      expect(round.result!.kind, RoundEndKind.blocked);
      expect(round.result!.winnerTeam, 0);
      expect(round.result!.winnerSeat, 2);
      expect(round.result!.points, 13); // seats 1 and 3: 6 + 7
    },
  );

  group('two players', () {
    RoundState twoPlayers() => RoundState(
      playerCount: 2,
      hands: const [
        [DominoPiece(6, 6), DominoPiece(0, 1)],
        [DominoPiece(2, 3)],
      ],
      boneyard: const [DominoPiece(4, 5), DominoPiece(1, 6)],
      startSeat: 0,
      openingPiece: const DominoPiece(6, 6),
    );

    test('a player with no move must draw before passing', () {
      final round = twoPlayers()..play(_sixSix);

      expect(round.turn, 1);
      expect(round.legalMoves(), isEmpty);
      expect(round.pass, throwsStateError);

      final drawn = round.draw();
      expect(drawn, const DominoPiece(1, 6));
      expect(round.legalMoves().length, 2);
    });

    test('empty draw pile and nobody can play: blocked, lowest wins', () {
      final round = RoundState(
        playerCount: 2,
        hands: const [
          [DominoPiece(6, 6), DominoPiece(0, 1)],
          [DominoPiece(2, 3)],
        ],
        boneyard: const [],
        startSeat: 0,
        openingPiece: const DominoPiece(6, 6),
      )..play(_sixSix);

      round.pass(); // seat 1
      round.pass(); // seat 0

      expect(round.result!.kind, RoundEndKind.blocked);
      expect(round.result!.winnerSeat, 0);
      expect(round.result!.points, 5);
    });
  });
}
