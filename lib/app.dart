import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'state/settings_provider.dart';
import 'ui/screens/splash_screen.dart';

/// Root widget of the game.
class IraqiDominoApp extends ConsumerWidget {
  const IraqiDominoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The language comes from the settings, so changing it there
    // rebuilds the whole app in the new language and direction.
    final locale = ref.watch(settingsProvider).locale;

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        // Our own translated strings (generated from the .arb files).
        AppLocalizations.delegate,
        // Material widgets translations, from the new material_ui package.
        GlobalMaterialLocalizations.delegate,
        // Text direction and basic widget translations.
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
