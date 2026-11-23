import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/engine/game_rules_config.dart';
import 'package:iraqi_domino/state/match_controller.dart';

void main() {
  for (final players in [2, 4]) {
    group('MatchController ($players players)', () {
      test('initializes match state with valid hands, scores, and distinct AI personas', () {
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
        expect(state.seats.length, players);
        expect(state.seats[0].isHuman, isTrue);

        // Every AI seat gets a unique named AiPersona.
        final personaIds = <String>{};
        for (var i = 1; i < players; i++) {
          expect(state.seats[i].isBot, isTrue);
          expect(state.seats[i].aiPersona, isNotNull);
          personaIds.add(state.seats[i].aiPersona!.id);
        }
        expect(personaIds.length, players - 1);
        expect(state.canAcceptHumanJoin, isTrue);
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

  group('MatchController AI Takeover & Hot-Join', () {
    test('replaceHumanWithBot marks seat open and tryHotJoinHuman reclaims it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const args = (
        playerCount: 4,
        rules: GameRulesConfig(targetScore: 151),
      );
      final notifier = container.read(matchControllerProvider(args).notifier);

      notifier.replaceHumanWithBot(2);
      final afterDrop = container.read(matchControllerProvider(args));
      expect(afterDrop.seats[2].isBot, isTrue);
      expect(afterDrop.seats[2].openForHumanJoin, isTrue);

      final joined = notifier.tryHotJoinHuman(
        seat: 2,
        playerId: 'u_99',
        nameAr: 'سيف',
        nameEn: 'Saif',
      );
      expect(joined, isTrue);
      final afterJoin = container.read(matchControllerProvider(args));
      expect(afterJoin.seats[2].isHuman, isTrue);
      expect(afterJoin.seats[2].nameAr, 'سيف');
    });
  });
}
