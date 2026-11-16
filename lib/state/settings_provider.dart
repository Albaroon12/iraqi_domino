import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gives access to the device storage. It is created once in main()
/// and injected here, so tests can replace it with a fake one.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() or in tests.',
  ),
);

/// The player's settings. Immutable: every change creates a new object,
/// which is what lets Riverpod notice the change and rebuild the screens.
class SettingsState {
  const SettingsState({
    this.languageCode = 'ar',
    this.targetScore = 151,
    this.tileSkinId = 'ivory',
    this.soundEnabled = true,
  });

  static const List<String> supportedLanguages = ['ar', 'en'];

  /// Target score choices offered in the settings screen.
  static const List<int> targetScoreOptions = [151, 200, 250];

  final String languageCode;
  final int targetScore;
  final String tileSkinId;
  final bool soundEnabled;

  Locale get locale => Locale(languageCode);

  SettingsState copyWith({
    String? languageCode,
    int? targetScore,
    String? tileSkinId,
    bool? soundEnabled,
  }) {
    return SettingsState(
      languageCode: languageCode ?? this.languageCode,
      targetScore: targetScore ?? this.targetScore,
      tileSkinId: tileSkinId ?? this.tileSkinId,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }
}

/// Holds the settings, saves every change, and loads them at startup.
class SettingsNotifier extends Notifier<SettingsState> {
  static const _kLanguage = 'settings.language';
  static const _kTargetScore = 'settings.target_score';
  static const _kTileSkin = 'settings.tile_skin';
  static const _kSound = 'settings.sound';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  /// Reads the saved values. Anything missing or invalid (for example a
  /// score we no longer offer) falls back to the default.
  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    const defaults = SettingsState();

    final language = prefs.getString(_kLanguage);
    final score = prefs.getInt(_kTargetScore);

    return SettingsState(
      languageCode: SettingsState.supportedLanguages.contains(language)
          ? language!
          : defaults.languageCode,
      targetScore: SettingsState.targetScoreOptions.contains(score)
          ? score!
          : defaults.targetScore,
      tileSkinId: prefs.getString(_kTileSkin) ?? defaults.tileSkinId,
      soundEnabled: prefs.getBool(_kSound) ?? defaults.soundEnabled,
    );
  }

  void setLanguage(String code) {
    state = state.copyWith(languageCode: code);
    _prefs.setString(_kLanguage, code);
  }

  void setTargetScore(int score) {
    state = state.copyWith(targetScore: score);
    _prefs.setInt(_kTargetScore, score);
  }

  void setTileSkin(String id) {
    state = state.copyWith(tileSkinId: id);
    _prefs.setString(_kTileSkin, id);
  }

  void setSound(bool enabled) {
    state = state.copyWith(soundEnabled: enabled);
    _prefs.setBool(_kSound, enabled);
  }
}

/// The single access point to the settings from any screen.
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);