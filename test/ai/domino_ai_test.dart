import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/ai/ai_difficulty.dart';
import 'package:iraqi_domino/ai/domino_ai.dart';
import 'package:iraqi_domino/ai/user_play_profile.dart';
import 'package:iraqi_domino/engine/board.dart';
import 'package:iraqi_domino/engine/dealer.dart';
import 'package:iraqi_domino/engine/domino_piece.dart';
import 'package:iraqi_domino/engine/round_state.dart';

RoundState _dealFirstRound(int playerCount, Random random) {
  final setup = Dealer.dealFirstRound(playerCount, random);
  return RoundState(
    playerCount: playerCount,
    hands: setup.hands,
    boneyard: setup.boneyard,
    startSeat: setup.startSeat,
    openingPiece: setup.startPiece,
  );
}

void main() {
  group('AiDifficulty', () {
    test('byId resolves valid ids and falls back to medium', () {
      expect(AiDifficulty.byId('easy'), AiDifficulty.easy);
      expect(AiDifficulty.byId('medium'), AiDifficulty.medium);
      expect(AiDifficulty.byId('hard'), AiDifficulty.hard);
      expect(AiDifficulty.byId('expert'), AiDifficulty.expert);
      expect(AiDifficulty.byId('unknown'), AiDifficulty.medium);
      expect(AiDifficulty.byId(null), AiDifficulty.medium);
    });
  });

  group('UserPlayProfile', () {
    test('learns user preferences from moves and round-trips encode/decode', () {
      final profile = UserPlayProfile();
      final userRound = RoundState(
        playerCount: 2,
        hands: [
          [
            const DominoPiece(2, 2),
            const DominoPiece(2, 6),
            const DominoPiece(0, 2),
            const DominoPiece(5, 6),
          ],
          [const DominoPiece(2, 3), const DominoPiece(4, 4)],
        ],
        boneyard: const [],
        startSeat: 1,
      );
      userRound.play(const Move(DominoPiece(2, 3), BoardEnd.right));

      final legal = userRound.legalMoves();
      // User chooses to play the heavy tile [2-6] which exposes 6 (supported by [5-6] in hand)
      const chosen = Move(DominoPiece(2, 6), BoardEnd.left);
      for (var i = 0; i < 6; i++) {
        profile.observeHumanMove(userRound, chosen, legal);
      }

      expect(profile.movesObserved, 6);
      expect(profile.heavyPipPreference, greaterThan(0.7));
      expect(profile.selfSuitKeepPreference, greaterThan(0.7));
      expect(profile.numberOpenAffinity[6], greaterThan(0.6));

      final restored = UserPlayProfile.decode(profile.encode());
      expect(restored.movesObserved, profile.movesObserved);
      expect(
        restored.heavyPipPreference,
        closeTo(profile.heavyPipPreference, 0.001),
      );
      expect(
        restored.selfSuitKeepPreference,
        closeTo(profile.selfSuitKeepPreference, 0.001),
      );
      expect(
        restored.numberOpenAffinity[6],
        closeTo(profile.numberOpenAffinity[6], 0.001),
      );
    });
  });

  group('DominoAi', () {
    test(
      'always chooses a legal move and is deterministic across all levels',
      () {
        final random = Random(42);
        for (final playerCount in [2, 4]) {
          for (final difficulty in AiDifficulty.values) {
            final round = _dealFirstRound(playerCount, random);
            while (!round.isOver) {
              final legal = round.legalMoves();
              if (legal.isEmpty) {
                if (playerCount == 2 && round.boneyard.isNotEmpty) {
                  round.draw();
                } else {
                  round.pass();
                }
                continue;
              }
              final first = DominoAi.chooseMove(round, difficulty: difficulty);
              final second = DominoAi.chooseMove(round, difficulty: difficulty);
              expect(first, equals(second));
              expect(legal, contains(first));
              round.play(first);
            }
          }
        }
      },
    );

    test('Medium/Hard/Expert prioritize high-pip double over low-pip tile', () {
      final round = RoundState(
        playerCount: 2,
        hands: [
          [const DominoPiece(2, 5), const DominoPiece(3, 6)],
          [const DominoPiece(0, 2), const DominoPiece(5, 5)],
        ],
        boneyard: const [DominoPiece(1, 6)],
        startSeat: 0,
      );
      round.play(const Move(DominoPiece(2, 5), BoardEnd.right));

      final easyMove = DominoAi.chooseMove(
        round,
        difficulty: AiDifficulty.easy,
      );
      final mediumMove = DominoAi.chooseMove(
        round,
        difficulty: AiDifficulty.medium,
      );
      final hardMove = DominoAi.chooseMove(
        round,
        difficulty: AiDifficulty.hard,
      );
      final expertMove = DominoAi.chooseMove(
        round,
        difficulty: AiDifficulty.expert,
      );

      expect(easyMove.piece, const DominoPiece(0, 2));
      expect(mediumMove.piece, const DominoPiece(5, 5));
      expect(hardMove.piece, const DominoPiece(5, 5));
      expect(expertMove.piece, const DominoPiece(5, 5));
    });

    test('Hard and Expert exploit opponent pass history to block them', () {
      final lockRound = RoundState(
        playerCount: 4,
        hands: [
          // Seat 0 (us)
          [
            const DominoPiece(4, 4),
            const DominoPiece(2, 4),
            const DominoPiece(2, 5),
            const DominoPiece(0, 1),
            const DominoPiece(3, 6),
          ],
          // Seat 1 (right opponent): no 4s
          [const DominoPiece(5, 5), const DominoPiece(5, 6)],
          // Seat 2 (partner): plays 1-4
          [const DominoPiece(1, 4), const DominoPiece(3, 3)],
          // Seat 3 (left opponent): plays 2-4
          [const DominoPiece(2, 4), const DominoPiece(6, 6)],
        ],
        boneyard: const [],
        startSeat: 0,
      );
      lockRound.play(const Move(DominoPiece(4, 4), BoardEnd.right));
      lockRound.pass(); // Seat 1 passes on 4..4
      lockRound.play(
        const Move(DominoPiece(1, 4), BoardEnd.left),
      ); // Seat 2 -> 1..4
      lockRound.play(
        const Move(DominoPiece(2, 4), BoardEnd.right),
      ); // Seat 3 -> 1..2

      expect(lockRound.passHistory, hasLength(1));
      expect(lockRound.passHistory.single.seat, 1);

      final easyChoice = DominoAi.chooseMove(
        lockRound,
        difficulty: AiDifficulty.easy,
      );
      final mediumChoice = DominoAi.chooseMove(
        lockRound,
        difficulty: AiDifficulty.medium,
      );
      final hardChoice = DominoAi.chooseMove(
        lockRound,
        difficulty: AiDifficulty.hard,
      );
      final expertChoice = DominoAi.chooseMove(
        lockRound,
        difficulty: AiDifficulty.expert,
      );

      expect(easyChoice, const Move(DominoPiece(0, 1), BoardEnd.left));
      expect(mediumChoice, const Move(DominoPiece(2, 5), BoardEnd.right));
      expect(hardChoice, const Move(DominoPiece(2, 4), BoardEnd.right));
      expect(expertChoice, const Move(DominoPiece(2, 4), BoardEnd.right));
    });

    test(
      '2-player AI deduces opponent missing numbers from boneyard draws',
      () {
        // Seat 1 opens with 1-4 (board 1..4).
        // Seat 0 has no 1s or 4s, draws [1-2] from the boneyard, and plays [1-2]
        // on left (board 2..4).
        // Now it is Seat 1's turn on board 2..4:
        // Seat 1 knows Seat 0 drew on (1, 4) and only matched 1, so Seat 0
        // STILL lacks 4 (and 1)!
        // Seat 1 holds [2-1] (which makes board 1..4, locking Seat 0 out of BOTH ends!)
        // and [2-5] (which has more pips so Medium prefers it, but opens 5 for Seat 0).
        final round = RoundState(
          playerCount: 2,
          hands: [
            // Seat 0 (human)
            [const DominoPiece(5, 5), const DominoPiece(5, 6)],
            // Seat 1 (AI)
            [
              const DominoPiece(1, 4),
              const DominoPiece(1, 2),
              const DominoPiece(2, 5),
              const DominoPiece(3, 6),
            ],
          ],
          boneyard: const [DominoPiece(0, 6), DominoPiece(1, 2)],
          startSeat: 1,
        );

        round.play(const Move(DominoPiece(1, 4), BoardEnd.right)); // 1..4
        round.draw(); // Seat 0 draws (1, 2) while board is 1..4
        round.play(const Move(DominoPiece(1, 2), BoardEnd.left)); // 2..4

        expect(round.drawHistory, hasLength(1));

        final mediumMove = DominoAi.chooseMove(
          round,
          difficulty: AiDifficulty.medium,
        );
        final hardMove = DominoAi.chooseMove(
          round,
          difficulty: AiDifficulty.hard,
        );
        final expertMove = DominoAi.chooseMove(
          round,
          difficulty: AiDifficulty.expert,
        );

        expect(mediumMove, const Move(DominoPiece(2, 5), BoardEnd.left));
        expect(hardMove, const Move(DominoPiece(1, 2), BoardEnd.left));
        expect(expertMove, const Move(DominoPiece(1, 2), BoardEnd.left));
      },
    );

    test('Expert outperforms Easy over 40 simulated 2-player rounds', () {
      var expertPoints = 0;
      var easyPoints = 0;

      for (var seed = 0; seed < 40; seed++) {
        final round = _dealFirstRound(2, Random(1000 + seed));
        final expertSeat = seed % 2;

        while (!round.isOver) {
          final moves = round.legalMoves();
          if (moves.isEmpty) {
            if (round.boneyard.isNotEmpty) {
              round.draw();
            } else {
              round.pass();
            }
            continue;
          }
          final diff = round.turn == expertSeat
              ? AiDifficulty.expert
              : AiDifficulty.easy;
          round.play(DominoAi.chooseMove(round, difficulty: diff));
        }

        final result = round.result!;
        if (result.winnerTeam == expertSeat) {
          expertPoints += result.points;
        } else if (result.winnerTeam != null) {
          easyPoints += result.points;
        }
      }

      expect(expertPoints, greaterThan(easyPoints));
    });
  });
}
