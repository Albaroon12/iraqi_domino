import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/l10n/app_localizations.dart';
import 'package:iraqi_domino/state/settings_provider.dart';
import 'package:iraqi_domino/ui/screens/app_shell_screen.dart';
import 'package:iraqi_domino/ui/screens/splash_screen.dart';
import 'package:iraqi_domino/ui/widgets/game_loading_overlay.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('SplashScreen displays boot progress stages then transitions to AppShellScreen', (tester) async {
    await tester.pumpWidget(await buildTestApp());
    // At 200ms into boot: SplashScreen is visible with stage 1 message.
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('أصالة المقهى البغدادي'), findsOneWidget);
    expect(find.text('جارٍ تجهيز الطاولة والأحجار...'), findsOneWidget);

    // At 800ms (~57%): stage 2 (verifying account & data hub).
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.text('جارٍ التحقق من الحساب ومركز البيانات...'),
      findsOneWidget,
    );

    // Finish boot + fade transition -> lands on AppShellScreen!
    await tester.pumpAndSettle();
    expect(find.byType(AppShellScreen), findsOneWidget);
  });

  testWidgets('GameLoadingOverlay shows animated domino loading card and handles cancel', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var cancelled = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: GameLoadingOverlay(
              visible: true,
              title: 'جارٍ البحث عن لاعبين...',
              subtitle: '2/4 لاعبين',
              onCancel: () => cancelled = true,
              child: const Text('محتوى الخلفية'),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('جارٍ البحث عن لاعبين...'), findsOneWidget);
    expect(find.text('2/4 لاعبين'), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pump();
    expect(cancelled, isTrue);

    // Unmount so repeating wave controller is disposed cleanly.
    await tester.pumpWidget(const SizedBox());
  });
}
