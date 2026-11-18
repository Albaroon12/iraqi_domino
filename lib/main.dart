import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'state/settings_provider.dart';

Future<void> main() async {
  // Required before using platform services (orientation, storage).
  WidgetsFlutterBinding.ensureInitialized();

  // The game is portrait-only.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Open the device storage BEFORE the app starts, so the saved settings
  // are already available when the first screen is built.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const IraqiDominoApp(),
    ),
  );
}
