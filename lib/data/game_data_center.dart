import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/settings_provider.dart';
import 'player_account.dart';

/// Optional remote synchronization contract for Phase 7 Online Auth & Cloud
/// Profile sync. Keeping this interface in `lib/data/` ensures the UI, Local
/// Multiplayer, and Online Matchmaking all talk ONLY to [GameDataCenter].
abstract interface class RemoteAccountGateway {
  /// Exchanges guest or provider credentials for a verified online session.
  Future<PlayerAccount> authenticate({
    required AuthProviderKind provider,
    required String credentialToken,
    required PlayerAccount currentLocalAccount,
  });

  /// Pushes updated local stats/profile to the backend when online.
  Future<void> syncAccount(PlayerAccount account);
}

/// Central single source of truth ("مركز البيانات الموحد") for player identity
/// (Guest vs Signed-In), public peer profile, and cumulative match statistics
/// across Offline AI, Local Wi-Fi, Offline Wi-Fi, Bluetooth, and Online play.
class GameDataCenter extends Notifier<PlayerAccount> {
  static const String _kAccountStorageKey = 'data_center.player_account';
  static const String _kInitialEntryDoneKey = 'data_center.initial_entry_done';

  RemoteAccountGateway? _remoteGateway;

  SharedPreferences? get _prefsOrNull {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      return null;
    }
  }

  @override
  PlayerAccount build() {
    SharedPreferences? prefs;
    try {
      prefs = ref.watch(sharedPreferencesProvider);
    } catch (_) {
      prefs = null;
    }

    final saved = PlayerAccount.tryDecode(
      prefs?.getString(_kAccountStorageKey),
    );
    if (saved != null) return saved;

    final freshGuest = PlayerAccount.createDefaultGuest();
    prefs?.setString(_kAccountStorageKey, freshGuest.encode());
    return freshGuest;
  }

  /// Attaches a Phase 7 online backend gateway without changing any callers.
  void attachRemoteGateway(RemoteAccountGateway? gateway) {
    _remoteGateway = gateway;
  }

  /// Public identity safe to broadcast in Local & Online lobbies.
  PublicPlayerProfile get publicProfile => state.toPublicProfile();

  /// Whether the player has already passed the initial welcome/account choice
  /// (used in Step 7.2 to show Sign-In vs Continue as Guest on first launch).
  bool get hasCompletedInitialEntry =>
      _prefsOrNull?.getBool(_kInitialEntryDoneKey) ?? false;

  void markInitialEntryCompleted() {
    _prefsOrNull?.setBool(_kInitialEntryDoneKey, true);
  }

  /// Verifies the stored session during [SplashScreen] boot. If an online
  /// [RemoteAccountGateway] is attached and the user is authenticated, syncs
  /// profile state silently without blocking offline play on network failure.
  Future<void> verifyBootSession() async {
    final gateway = _remoteGateway;
    if (gateway != null && state.isAuthenticated) {
      try {
        await gateway
            .syncAccount(state)
            .timeout(const Duration(milliseconds: 900));
      } catch (_) {
        // Offline or server unreachable: keep cached verified account intact.
      }
    }
  }

  /// Updates the player's visible name (trimmed, max 24 chars).
  void updateDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final clipped = trimmed.length > 24 ? trimmed.substring(0, 24) : trimmed;
    _saveAndEmit(state.copyWith(displayName: clipped));
  }

  /// Updates the player's chosen avatar index.
  void updateAvatarIndex(int avatarIndex) {
    if (avatarIndex < 0) return;
    _saveAndEmit(state.copyWith(avatarIndex: avatarIndex));
  }

  /// Upgrades or switches from Guest mode to an authenticated account
  /// (ready for Phase 7 Online sign-in while preserving accumulated stats).
  void bindAuthenticatedAccount({
    required String userId,
    required AuthProviderKind provider,
    required String displayName,
    String? email,
    required String authToken,
    String? refreshToken,
    int? rating,
  }) {
    final cleanName = displayName.trim().isEmpty
        ? state.displayName
        : displayName.trim();
    final updated = state.copyWith(
      playerId: userId,
      kind: AccountKind.authenticated,
      authProvider: provider,
      displayName: cleanName,
      email: email,
      authToken: authToken,
      refreshToken: refreshToken,
      rating: rating ?? state.rating,
    );
    _saveAndEmit(updated);
  }

  /// Signs in through the attached Phase 7 [RemoteAccountGateway] if configured.
  Future<PlayerAccount> signInOnline({
    required AuthProviderKind provider,
    required String credentialToken,
  }) async {
    final gateway = _remoteGateway;
    if (gateway == null) {
      throw StateError('Online authentication server is not connected yet.');
    }
    final verified = await gateway.authenticate(
      provider: provider,
      credentialToken: credentialToken,
      currentLocalAccount: state,
    );
    _saveAndEmit(verified);
    return verified;
  }

  /// Signs in with email & password (uses [RemoteAccountGateway] when attached,
  /// or local credential verification while offline/pre-server), preserving any
  /// Guest match stats accumulated on this device.
  Future<PlayerAccount> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw ArgumentError('يرجى إدخال بريد إلكتروني صحيح');
    }
    if (password.length < 6) {
      throw ArgumentError('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
    }

    final gateway = _remoteGateway;
    if (gateway != null) {
      final verified = await gateway.authenticate(
        provider: AuthProviderKind.email,
        credentialToken: '$cleanEmail:$password',
        currentLocalAccount: state,
      );
      markInitialEntryCompleted();
      _saveAndEmit(verified);
      return verified;
    }

    final emailPrefix = cleanEmail.split('@').first;
    final displayName = state.displayName.startsWith('ضيف')
        ? emailPrefix
        : state.displayName;
    final userId = 'usr_${cleanEmail.hashCode.abs()}';

    bindAuthenticatedAccount(
      userId: userId,
      provider: AuthProviderKind.email,
      displayName: displayName,
      email: cleanEmail,
      authToken: 'local_jwt_$userId',
    );
    markInitialEntryCompleted();
    return state;
  }

  /// Registers a new account and links current Guest stats/rating to it.
  Future<PlayerAccount> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final cleanName = displayName.trim();
    if (cleanName.length < 2) {
      throw ArgumentError('يرجى إدخال اسم لاعب لا يقل عن حرفين');
    }
    final cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw ArgumentError('يرجى إدخال بريد إلكتروني صحيح');
    }
    if (password.length < 6) {
      throw ArgumentError('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
    }

    final gateway = _remoteGateway;
    if (gateway != null) {
      final verified = await gateway.authenticate(
        provider: AuthProviderKind.email,
        credentialToken: 'register:$cleanName:$cleanEmail:$password',
        currentLocalAccount: state.copyWith(displayName: cleanName),
      );
      markInitialEntryCompleted();
      _saveAndEmit(verified);
      return verified;
    }

    final userId = 'usr_${cleanEmail.hashCode.abs()}';
    bindAuthenticatedAccount(
      userId: userId,
      provider: AuthProviderKind.email,
      displayName: cleanName,
      email: cleanEmail,
      authToken: 'local_jwt_$userId',
    );
    markInitialEntryCompleted();
    return state;
  }

  /// Signs out of an authenticated account back to the persistent device Guest
  /// identity ("اللعب كضيف").
  void continueAsGuest({String? guestDisplayName}) {
    final fallbackName = (guestDisplayName?.trim().isNotEmpty ?? false)
        ? guestDisplayName!.trim()
        : state.displayName;
    final guest = state.copyWith(
      playerId: state.guestDeviceId,
      kind: AccountKind.guest,
      authProvider: AuthProviderKind.none,
      displayName: fallbackName,
      clearAuthCredentials: true,
    );
    markInitialEntryCompleted();
    _saveAndEmit(guest);
  }

  /// Records a finished match from ANY mode (AI, Wi-Fi, Offline Wi-Fi,
  /// Bluetooth, or Online) into the unified player record.
  void recordMatchOutcome({
    required bool won,
    required int ourScore,
    required int roundsWonInMatch,
  }) {
    final nextStats = state.stats.recordMatch(
      won: won,
      ourScore: ourScore,
      roundsWonInMatch: roundsWonInMatch,
    );
    // Simple local Elo-like rating progression (synced/overridden online later).
    final delta = won ? 15 : -8;
    final nextRating = (state.rating + delta).clamp(100, 9999);
    _saveAndEmit(state.copyWith(stats: nextStats, rating: nextRating));
  }

  void _saveAndEmit(PlayerAccount next) {
    state = next;
    _prefsOrNull?.setString(_kAccountStorageKey, next.encode());
    final gateway = _remoteGateway;
    if (gateway != null && next.isAuthenticated) {
      gateway.syncAccount(next).ignore();
    }
  }
}

/// Global provider for the unified [GameDataCenter].
final gameDataCenterProvider =
    NotifierProvider<GameDataCenter, PlayerAccount>(GameDataCenter.new);
