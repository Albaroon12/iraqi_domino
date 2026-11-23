import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/ai/ai_persona.dart';
import 'package:iraqi_domino/engine/seat_occupant.dart';

void main() {
  group('AiPersona', () {
    test('defines 10 unique personas with distinct IDs and names', () {
      expect(AiPersona.all, hasLength(10));
      final ids = AiPersona.all.map((p) => p.id).toSet();
      final namesAr = AiPersona.all.map((p) => p.nameAr).toSet();
      final namesEn = AiPersona.all.map((p) => p.nameEn).toSet();

      expect(ids, hasLength(10));
      expect(namesAr, hasLength(10));
      expect(namesEn, hasLength(10));
    });

    test('pickDistinct returns non-overlapping personas and respects excludeIds', () {
      final picked = AiPersona.pickDistinct(
        3,
        Random(7),
        excludeIds: const {'abu_ali'},
      );
      expect(picked, hasLength(3));
      expect(picked.map((p) => p.id).toSet(), hasLength(3));
      expect(picked.any((p) => p.id == 'abu_ali'), isFalse);
    });
  });

  group('SeatOccupant endgame hot-join cutoff', () {
    test('allows human join early/mid match and blocks near target score', () {
      expect(
        SeatOccupant.canAcceptHumanJoin(
          scores: const [40, 65],
          targetScore: 151,
          isMatchOver: false,
        ),
        isTrue,
      );

      // 110 / 151 is above the 65% endgame cutoff (~98 pts) -> block new joins!
      expect(
        SeatOccupant.canAcceptHumanJoin(
          scores: const [50, 110],
          targetScore: 151,
          isMatchOver: false,
        ),
        isFalse,
      );

      expect(
        SeatOccupant.canAcceptHumanJoin(
          scores: const [0, 0],
          targetScore: 151,
          isMatchOver: true,
        ),
        isFalse,
      );
    });
  });
}
