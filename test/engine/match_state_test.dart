import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/engine/game_rules_config.dart';
import 'package:iraqi_domino/engine/match_state.dart';
import 'package:iraqi_domino/engine/round_result.dart';

void _playRoundToCompletion(MatchState match, Random rng) {
  while (!match.round.isOver) {
    final moves = match.legalMoves();
    if (moves.isNotEmpty) {
      match.play(moves[rng.nextInt(moves.length)]);
    } else if (match.playerCount == 2 && match.round.boneyard.isNotEmpty) {
      match.draw();
    } else {
      match.pass();
    }
  }
}

void main() {
  for (final players in [2, 4]) {
    group('MatchState ($players players)', () {
      test('starts with zero scores, empty history, and forced opening piece', () {
        final match = MatchState(
          playerCount: players,
          rules: const GameRulesConfig(targetScore: 151),
          random: Random(1),
        );

        expect(match.scores, [0, 0]);
        expect(match.history, isEmpty);
        expect(match.isOver, isFalse);
        expect(match.winnerTeam, isNull);
        expect(match.round.openingPiece, isNotNull);
        expect(match.round.openingPiece!.isDouble, isTrue);
      });

      test('plays multiple rounds until targetScore is reached', () {
        const target = 60;
        final rng = Random(42);
        final match = MatchState(
          playerCount: players,
          rules: const GameRulesConfig(targetScore: target),
          random: Random(7),
        );

        var rounds = 0;
        while (!match.isOver) {
          _playRoundToCompletion(match, rng);
          rounds++;
          expect(match.history.length, rounds);
          expect(match.history.last.round, rounds);
          expect(match.history.last.ourTotal, match.scores[0]);
          expect(match.history.last.theirTotal, match.scores[1]);

          if (!match.isOver) {
            final last = match.round.result!;
            match.startNextRound();
            if (last.kind == RoundEndKind.burned) {
              expect(match.round.openingPiece, isNotNull);
            } else {
              expect(match.round.startSeat, last.winnerSeat);
              expect(match.round.openingPiece, isNull);
            }
          }
        }

        final winner = match.winnerTeam!;
        expect(match.scores[winner], greaterThanOrEqualTo(target));
        expect(match.legalMoves(), isEmpty);
        expect(() => match.startNextRound(), throwsStateError);
      });

      test('startNextRound throws if the current round is not finished', () {
        final match = MatchState(
          playerCount: players,
          rules: const GameRulesConfig(targetScore: 151),
          random: Random(3),
        );

        expect(() => match.startNextRound(), throwsStateError);
      });

      test('resetMatch clears scores and history and deals a fresh round', () {
        final rng = Random(99);
        final match = MatchState(
          playerCount: players,
          rules: const GameRulesConfig(targetScore: 20),
          random: Random(5),
        );

        while (!match.isOver) {
          _playRoundToCompletion(match, rng);
          if (!match.isOver) match.startNextRound();
        }
        expect(match.isOver, isTrue);
        expect(match.history, isNotEmpty);

        match.resetMatch();

        expect(match.isOver, isFalse);
        expect(match.winnerTeam, isNull);
        expect(match.scores, [0, 0]);
        expect(match.history, isEmpty);
        expect(match.round.isOver, isFalse);
        expect(match.round.openingPiece, isNotNull);
      });
    });
  }
}
