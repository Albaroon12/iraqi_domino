import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/ui/widgets/player_chip.dart';

import '../helpers/test_app.dart';

void main() {
  Future<void> openGame(WidgetTester tester, String mode) async {
    // 360 x 640 logical pixels: a small, common phone size.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('العب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(mode));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ضد الكمبيوتر'));
    await tester.pumpAndSettle();
  }

  testWidgets('4-player game screen fits a phone-size screen', (tester) async {
    await openGame(tester, 'أربعة لاعبين');

    expect(find.text('أنت'), findsOneWidget);
    expect(find.byType(PlayerChip), findsNWidgets(4));

    // Leave the screen so its game timers are cancelled before the end.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('2-player game screen fits a phone-size screen', (tester) async {
    await openGame(tester, 'لاعبان');

    expect(find.text('أنت'), findsWidgets);
    expect(find.byType(PlayerChip), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox());
  });
}
