import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/core/network/connectivity_provider.dart';
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

  testWidgets('ModeHubScreen shows single Local Play button and opens method & room hub', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('العب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أربعة لاعبين'));
    await tester.pumpAndSettle();

    // Single Local Play button on ModeHubScreen:
    expect(find.text('اللعب المحلي'), findsOneWidget);

    await tester.tap(find.text('اللعب المحلي'));
    await tester.pumpAndSettle();

    // Inside LocalMultiplayerScreen: 3 connection methods + Room Number & Available Rooms tabs:
    expect(find.text('واي فاي بدون إنترنت'), findsOneWidget);
    expect(find.text('بلوتوث'), findsOneWidget);
    expect(find.text('شبكة الواي فاي (Wi-Fi)'), findsOneWidget);
    expect(find.text('إدخال رقم الغرفة'), findsOneWidget);
    expect(find.textContaining('الغرف المتاحة'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Offline mode hides online features and shows only Vs AI and Local Play', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    // Switch connectivity to Offline:
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(Directionality).first),
    );
    scope.read(connectivityProvider.notifier).setOnlineStatus(false);
    await tester.pumpAndSettle();

    // Main screen enters Offline-Only Café view (Shop/Tournaments bottom tabs hidden):
    expect(find.text('وضع بدون إنترنت'), findsOneWidget);
    expect(find.text('السوق'), findsNothing);

    // Open 4-player ModeHubScreen while offline -> ONLY Vs AI & Local Play appear!
    await tester.tap(find.text('أربعة لاعبين'));
    await tester.pumpAndSettle();
    expect(find.text('ضد الكمبيوتر'), findsOneWidget);
    expect(find.text('اللعب المحلي'), findsOneWidget);
    expect(find.text('لعب عشوائي (أونلاين)'), findsNothing);
    expect(find.text('غرفة أصدقاء (أونلاين)'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
