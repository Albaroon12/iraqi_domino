import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';

/// Central audio service for game sound effects and Iraqi café ambience.
///
/// Missing audio files in `assets/audio/` are safely ignored (and cached)
/// so the app never crashes if an asset has not been added yet.
class SoundService {
  SoundService(this._ref);

  final Ref _ref;

  static const String _cafeAmbientAsset = 'audio/cafe_ambient.mp3';
  static const String _tilePlaceAsset = 'audio/tile_place.mp3';
  static const String _tileDrawAsset = 'audio/tile_draw.mp3';
  static const String _tilePassAsset = 'audio/tile_pass.mp3';

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();
  final Map<String, bool> _assetExists = {};

  bool _ambientRequested = false;

  Future<bool> _hasAsset(String assetPath) async {
    final cached = _assetExists[assetPath];
    if (cached != null) return cached;
    try {
      await rootBundle.load('assets/$assetPath');
      _assetExists[assetPath] = true;
      return true;
    } catch (_) {
      _assetExists[assetPath] = false;
      return false;
    }
  }

  Future<void> _playSfx(String assetPath) async {
    if (!_ref.read(settingsProvider).soundEnabled) return;
    if (!await _hasAsset(assetPath)) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource(assetPath), volume: 0.9);
    } catch (_) {
      // Ignore audio errors on unsupported/headless test environments.
    }
  }

  /// Plays the tile-placement clack sound.
  Future<void> playTilePlace() => _playSfx(_tilePlaceAsset);

  /// Plays the boneyard draw sound.
  Future<void> playTileDraw() => _playSfx(_tileDrawAsset);

  /// Plays the pass ("تعبّر / ما عندي") sound.
  Future<void> playPass() => _playSfx(_tilePassAsset);

  /// Starts looping the Iraqi café ambience if enabled in settings.
  Future<void> startCafeAmbient() async {
    _ambientRequested = true;
    if (!_ref.read(settingsProvider).ambientEnabled) return;
    if (!await _hasAsset(_cafeAmbientAsset)) return;
    try {
      await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
      await _ambientPlayer.setVolume(0.25);
      await _ambientPlayer.play(AssetSource(_cafeAmbientAsset));
    } catch (_) {}
  }

  /// Pauses the café ambience (e.g. when app goes to background).
  Future<void> pauseCafeAmbient() async {
    try {
      await _ambientPlayer.pause();
    } catch (_) {}
  }

  /// Resumes the café ambience if still in a match and enabled.
  Future<void> resumeCafeAmbient() async {
    if (!_ambientRequested || !_ref.read(settingsProvider).ambientEnabled) {
      return;
    }
    if (!await _hasAsset(_cafeAmbientAsset)) return;
    try {
      await _ambientPlayer.resume();
    } catch (_) {}
  }

  /// Stops the café ambience (when leaving the table or disabled in settings).
  Future<void> stopCafeAmbient({bool clearRequest = true}) async {
    if (clearRequest) _ambientRequested = false;
    try {
      await _ambientPlayer.stop();
    } catch (_) {}
  }

  void dispose() {
    _sfxPlayer.dispose();
    _ambientPlayer.dispose();
  }
}

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService(ref);
  ref.onDispose(service.dispose);
  return service;
});
