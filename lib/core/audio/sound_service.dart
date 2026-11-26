import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';

/// Central audio & tactile haptics service for **المقهى** (`Al-Maqha`).
///
/// Automatically prefers custom `.mp3` files in `assets/audio/` when present
/// and falls back to bundled first-party `.wav` effects so every sound works
/// out of the box without crashes.
class SoundService {
  SoundService(this._ref);

  final Ref _ref;

  static const List<String> _cafeAmbientCandidates = [
    'audio/cafe_ambient.mp3',
    'audio/cafe_ambient.wav',
  ];
  static const List<String> _tilePlaceCandidates = [
    'audio/tile_place.mp3',
    'audio/tile_place.wav',
  ];
  static const List<String> _tileDrawCandidates = [
    'audio/tile_draw.mp3',
    'audio/tile_draw.wav',
  ];
  static const List<String> _tilePassCandidates = [
    'audio/tile_pass.mp3',
    'audio/tile_pass.wav',
  ];

  AudioPlayer? _sfxPlayer;
  AudioPlayer? _ambientPlayer;
  final Map<String, bool> _assetExists = {};

  bool _ambientRequested = false;

  AudioPlayer? _getSfxPlayer() {
    if (_sfxPlayer != null) return _sfxPlayer;
    try {
      return _sfxPlayer = AudioPlayer();
    } catch (_) {
      return null;
    }
  }

  AudioPlayer? _getAmbientPlayer() {
    if (_ambientPlayer != null) return _ambientPlayer;
    try {
      return _ambientPlayer = AudioPlayer();
    } catch (_) {
      return null;
    }
  }

  bool get _soundEnabled {
    try {
      return _ref.read(settingsProvider).soundEnabled;
    } catch (_) {
      return false;
    }
  }

  bool get _ambientEnabled {
    try {
      return _ref.read(settingsProvider).ambientEnabled;
    } catch (_) {
      return false;
    }
  }

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

  Future<String?> _resolveFirstAvailable(List<String> candidates) async {
    for (final path in candidates) {
      if (await _hasAsset(path)) return path;
    }
    return null;
  }

  Future<void> _playSfxCandidates(
    List<String> candidates, {
    bool lightHaptic = false,
  }) async {
    if (!_soundEnabled) return;
    if (lightHaptic) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
    final resolved = await _resolveFirstAvailable(candidates);
    if (resolved == null) return;
    final player = _getSfxPlayer();
    if (player == null) return;
    try {
      await player.stop();
      await player.play(AssetSource(resolved), volume: 0.9);
    } catch (_) {
      // Ignore audio errors on unsupported/headless test environments.
    }
  }

  /// Pre-warms asset existence checks during [SplashScreen] boot so the first
  /// tile placement in a match has zero lookup latency.
  Future<void> warmUp() async {
    await Future.wait([
      _resolveFirstAvailable(_cafeAmbientCandidates),
      _resolveFirstAvailable(_tilePlaceCandidates),
      _resolveFirstAvailable(_tileDrawCandidates),
      _resolveFirstAvailable(_tilePassCandidates),
    ]);
  }

  /// Plays the tile-placement clack sound + subtle tactile impact.
  Future<void> playTilePlace() =>
      _playSfxCandidates(_tilePlaceCandidates, lightHaptic: true);

  /// Plays the boneyard draw sound.
  Future<void> playTileDraw() => _playSfxCandidates(_tileDrawCandidates);

  /// Plays the pass ("تعبّر / ما عندي") sound.
  Future<void> playPass() => _playSfxCandidates(_tilePassCandidates);

  /// Starts looping the Iraqi café ambience if enabled in settings.
  Future<void> startCafeAmbient() async {
    _ambientRequested = true;
    if (!_ambientEnabled) return;
    final resolved = await _resolveFirstAvailable(_cafeAmbientCandidates);
    if (resolved == null) return;
    final player = _getAmbientPlayer();
    if (player == null) return;
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0.22);
      await player.play(AssetSource(resolved));
    } catch (_) {}
  }

  /// Pauses the café ambience (e.g. when app goes to background).
  Future<void> pauseCafeAmbient() async {
    try {
      await _ambientPlayer?.pause();
    } catch (_) {}
  }

  /// Resumes the café ambience if still in a match and enabled.
  Future<void> resumeCafeAmbient() async {
    if (!_ambientRequested || !_ambientEnabled) {
      return;
    }
    final resolved = await _resolveFirstAvailable(_cafeAmbientCandidates);
    if (resolved == null) return;
    try {
      await _ambientPlayer?.resume();
    } catch (_) {}
  }

  /// Stops the café ambience (when leaving the table or disabled in settings).
  Future<void> stopCafeAmbient({bool clearRequest = true}) async {
    if (clearRequest) _ambientRequested = false;
    try {
      await _ambientPlayer?.stop();
    } catch (_) {}
  }

  void dispose() {
    _sfxPlayer?.dispose();
    _ambientPlayer?.dispose();
  }
}

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService(ref);
  ref.onDispose(service.dispose);
  return service;
});
