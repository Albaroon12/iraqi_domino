import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iraqi_domino/app.dart';
import 'package:iraqi_domino/state/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds the whole app with a fake in-memory storage, for widget tests.
Future<Widget> buildTestApp([Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const IraqiDominoApp(),
  );
}
