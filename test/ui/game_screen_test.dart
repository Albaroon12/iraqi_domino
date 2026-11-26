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

  testWidgets('Bottom dock ordered left-to-right and Games tab switches & persists active Home game', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    // 1. Verify physical left-to-right bottom bar order:
    // ملفي < الألعاب < الرئيسية < المهام < السوق
    final xProfile = tester.getCenter(find.text('ملفي')).dx;
    final xGames = tester.getCenter(find.text('الألعاب')).dx;
    final xHome = tester.getCenter(find.text('الرئيسية')).dx;
    final xTasks = tester.getCenter(find.text('المهام')).dx;
    final xShop = tester.getCenter(find.text('السوق')).dx;
    expect(xProfile, lessThan(xGames));
    expect(xGames, lessThan(xHome));
    expect(xHome, lessThan(xTasks));
    expect(xTasks, lessThan(xShop));

    // 2. Verify Home shows only Local Play & Practice cards beneath Play:
    expect(find.text('لعب محلي'), findsOneWidget);
    expect(find.text('تدريب'), findsOneWidget);
    expect(find.text('فرق 2×2'), findsNothing);
    expect(find.text('المزيد'), findsNothing);

    // 3. Switch to Games tab -> tap تشغيل on طاولة الزهر -> returns to Home with Backgammon & its Leaderboard!
    await tester.tap(find.text('الألعاب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طاولة الزهر'));
    await tester.pumpAndSettle();

    expect(find.text('المتصدرين — طاولة الزهر'), findsOneWidget);

    // Tap the shaded Leaderboard button -> opens the Podium Leaderboard popup sheet!
    await tester.ensureVisible(find.text('المتصدرين — طاولة الزهر'));
    await tester.tap(find.text('المتصدرين — طاولة الزهر'));
    await tester.pumpAndSettle();
    expect(find.text('التصنيف'), findsOneWidget);
    expect(find.text('كل الوقت'), findsOneWidget);
    expect(find.text('الشهر'), findsOneWidget);
    expect(find.text('الأسبوع'), findsOneWidget);

    // 4. Reopening the app with saved settings.selected_game restores طاولة الزهر on Home!
    await tester.pumpWidget(
      await buildTestApp({'settings.selected_game': 'backgammon'}),
    );
    await tester.pumpAndSettle();
    expect(find.text('المتصدرين — طاولة الزهر'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
