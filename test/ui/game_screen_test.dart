import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/rendering/domino_tile.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('4-player game screen fits a phone-size screen', (tester) async {
    // 360 x 640 logical pixels: a small, common phone size.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('العب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أربعة لاعبين'));
    await tester.pumpAndSettle();

    expect(find.text('فريقنا'), findsOneWidget);
    expect(find.text('شريكك'), findsOneWidget);
    // Your real hand: exactly seven face-up tiles.
    expect(find.byType(DominoTile), findsNWidgets(7));
  });
}