import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/engine/game_rules_config.dart';
import 'package:iraqi_domino/state/match_controller.dart';

void main() {
  for (final players in [2, 4]) {
    group('MatchController ($players players)', () {
      test('initializes match state with valid hands and scores', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final args = (
          playerCount: players,
          rules: const GameRulesConfig(targetScore: 151),
        );
        final state = container.read(matchControllerProvider(args));

        expect(state.playerCount, players);
        expect(state.rules.targetScore, 151);
        expect(state.scores, [0, 0]);
        expect(state.history, isEmpty);
        expect(state.hands.length, players);
        expect(state.isMatchOver, isFalse);
        expect(state.showResultPending, isFalse);
        expect(state.turnSeat, isNotNull);
      });

      test('redeal and resetMatch emit updated revisions', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final args = (
          playerCount: players,
          rules: const GameRulesConfig(targetScore: 151),
        );
        final first = container.read(matchControllerProvider(args));
        final notifier = container.read(matchControllerProvider(args).notifier);

        notifier.redeal();
        final afterRedeal = container.read(matchControllerProvider(args));
        expect(afterRedeal.revision, greaterThan(first.revision));
        expect(afterRedeal.board.isEmpty, isTrue);

        notifier.resetMatch();
        final afterReset = container.read(matchControllerProvider(args));
        expect(afterReset.revision, greaterThan(afterRedeal.revision));
        expect(afterReset.scores, [0, 0]);
        expect(afterReset.history, isEmpty);
      });

      test('playing a legal move for seat 0 places it on the board', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final args = (
          playerCount: players,
          rules: const GameRulesConfig(targetScore: 151),
        );
        final notifier = container.read(matchControllerProvider(args).notifier);

        // Redeal until seat 0 starts so we can test playHumanMove directly.
        var state = container.read(matchControllerProvider(args));
        var attempts = 0;
        while (state.turnSeat != 0 && attempts < 50) {
          notifier.redeal();
          state = container.read(matchControllerProvider(args));
          attempts++;
        }

        if (state.turnSeat == 0 && state.myMoves.isNotEmpty) {
          final move = state.myMoves.first;
          notifier.playHumanMove(move.piece, move.end);
          final after = container.read(matchControllerProvider(args));
          expect(after.board.isEmpty, isFalse);
          expect(after.board.line.length, 1);
        }
      });
    });
  }
}
