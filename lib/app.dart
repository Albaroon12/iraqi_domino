import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'ui/screens/home_shell_screen.dart';

/// Root widget of the game.
class IraqiDominoApp extends StatelessWidget {
  const IraqiDominoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,

      // Arabic-first. Flutter flips the layout to RTL automatically for 'ar'.
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,

      localizationsDelegates: const [
        // Our own translated strings (generated from the .arb files).
        AppLocalizations.delegate,
        // Material widgets translations, from the new material_ui package.
        GlobalMaterialLocalizations.delegate,
        // Text direction and basic widget translations.
        GlobalWidgetsLocalizations.delegate,
      ],

      home: const HomeShellScreen(),
    );
  }
}