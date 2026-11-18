import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/state/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Creates a container over a fake storage with optional saved values.
Future<(ProviderContainer, SharedPreferences)> _setup([
  Map<String, Object> saved = const {},
]) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return (container, prefs);
}

void main() {
  test('default settings match the agreed rules', () async {
    final (container, _) = await _setup();

    final settings = container.read(settingsProvider);
    expect(settings.targetScore, 151);
    expect(settings.languageCode, 'ar');
    expect(settings.soundEnabled, isTrue);
  });

  test('changing the target score updates the state', () async {
    final (container, _) = await _setup();

    container.read(settingsProvider.notifier).setTargetScore(200);

    expect(container.read(settingsProvider).targetScore, 200);
  });

  test('settings survive an app restart', () async {
    final (first, prefs) = await _setup();
    first.read(settingsProvider.notifier)
      ..setTargetScore(250)
      ..setLanguage('en')
      ..setTileSkin('ruby')
      ..setSound(false);

    // A new container over the same storage simulates a fresh launch.
    final second = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(second.dispose);

    final loaded = second.read(settingsProvider);
    expect(loaded.targetScore, 250);
    expect(loaded.languageCode, 'en');
    expect(loaded.tileSkinId, 'ruby');
    expect(loaded.soundEnabled, isFalse);
  });

  test('invalid saved values fall back to the defaults', () async {
    final (container, _) = await _setup({
      'settings.target_score': 999,
      'settings.language': 'xx',
    });

    final settings = container.read(settingsProvider);
    expect(settings.targetScore, 151);
    expect(settings.languageCode, 'ar');
  });
}
