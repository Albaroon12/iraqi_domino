import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/settings_provider.dart';
import 'cafe_events_and_tournaments.dart';
import 'cafe_progression.dart';
import 'cafe_shop_catalog.dart';
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

  /// Permanently deletes the signed-in user's account on the server
  /// (Apple App Store Guideline 5.1.1(v) & Google Play Data Safety compliance).
  Future<void> deleteOwnAccount(String authToken);
}

/// Central single source of truth ("مركز البيانات الموحد") for player identity,
/// **دينار المقهى** (`cafeDinars`), rental/permanent Shop inventory, active
/// boosters, VIP Council membership, and per-game statistics across **المقهى**.
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

  /// Whether the player has already passed the initial welcome/account choice.
  bool get hasCompletedInitialEntry =>
      _prefsOrNull?.getBool(_kInitialEntryDoneKey) ?? false;

  void markInitialEntryCompleted() {
    _prefsOrNull?.setBool(_kInitialEntryDoneKey, true);
  }

  /// Verifies the stored session during `SplashScreen` boot and cleans up any
  /// expired rentals back to default equipped items.
  Future<void> verifyBootSession([DateTime? now]) async {
    refreshExpiredRentals(now);
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

  /// Purges expired rental timestamps and resets any expired equipped item back
  /// to its default starter cosmetic.
  void refreshExpiredRentals([DateTime? now]) {
    final ts = now ?? DateTime.now();
    final ms = ts.millisecondsSinceEpoch;
    final activeRentals = <String, int>{
      for (final e in state.rentedItemExpiries.entries)
        if (e.value > ms) e.key: e.value,
    };

    final nextTable = state.effectiveTableId(ts);
    final nextFrame = state.effectiveFrameId(ts);
    final nextDomino = state.effectiveDominoItemId(ts);
    final nextProp = state.effectiveCafePropId(ts);

    if (activeRentals.length != state.rentedItemExpiries.length ||
        nextTable != state.equippedTableId ||
        nextFrame != state.equippedFrameId ||
        nextDomino != state.equippedDominoSkinId ||
        nextProp != state.equippedCafePropId) {
      final updated = state.copyWith(
        rentedItemExpiries: activeRentals,
        equippedTableId: nextTable,
        equippedFrameId: nextFrame,
        equippedDominoSkinId: nextDomino,
        equippedCafePropId: nextProp,
      );
      _syncTileSkinSetting(updated.effectiveDominoSkinCode(ts));
      _saveAndEmit(updated);
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

  /// Upgrades or switches from Guest mode to an authenticated account.
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

  /// Signs in with email & password.
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

  /// Registers a new account and links current Guest stats/rating/inventory to it.
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

  /// Signs in or registers using a Google account (`Gmail` on the phone,
  /// `AuthProviderKind.google`), linking current Guest stats, rating, and
  /// **دينار المقهى** seamlessly.
  Future<PlayerAccount> signInWithGoogle({
    required String googleEmail,
    String? displayNameOverride,
  }) async {
    final cleanEmail = googleEmail.trim().toLowerCase();
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw ArgumentError('يرجى اختيار بريد Google صحيح');
    }
    final prefix = cleanEmail.split('@').first;
    final preferredName =
        (displayNameOverride?.trim().isNotEmpty ?? false)
            ? displayNameOverride!.trim()
            : (state.displayName.startsWith('ضيف')
                  ? prefix
                  : state.displayName);

    final gateway = _remoteGateway;
    if (gateway != null) {
      final verified = await gateway.authenticate(
        provider: AuthProviderKind.google,
        credentialToken: '$cleanEmail:$preferredName',
        currentLocalAccount: state.copyWith(displayName: preferredName),
      );
      markInitialEntryCompleted();
      _saveAndEmit(verified);
      return verified;
    }

    final userId = 'usr_g_${cleanEmail.hashCode.abs()}';
    bindAuthenticatedAccount(
      userId: userId,
      provider: AuthProviderKind.google,
      displayName: preferredName,
      email: cleanEmail,
      authToken: 'local_google_jwt_$userId',
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

  /// Permanently deletes the user's account both on the online server (if
  /// connected) and locally on the device, resetting to a clean fresh Guest ID.
  Future<void> deleteMyAccountPermanently() async {
    final gateway = _remoteGateway;
    final token = state.authToken;
    if (gateway != null &&
        state.isAuthenticated &&
        token != null &&
        token.isNotEmpty) {
      await gateway.deleteOwnAccount(token);
    }
    final freshGuest = PlayerAccount.createDefaultGuest();
    state = freshGuest;
    _prefsOrNull?.setString(_kAccountStorageKey, freshGuest.encode());
  }

  /// Records a finished match into the unified player record:
  /// - **0 Café Dinars** from regular matches (Dinars come strictly from
  ///   Tournaments & Events!).
  /// - Updates global Café stats and per-game stats (`[gameId]`).
  /// - Awards match XP **only when [isOnlineMatch] is true** (0 XP against
  ///   offline AI!), applying active VIP / 2x-XP boosters and daily cap.
  /// - Consumes 1 [PlayerAccount.ratingShieldCharges] on loss to protect rating.
  /// - Unlocks newly met game badges (badge XP bypasses the daily match cap).
  void recordMatchOutcome({
    required bool won,
    required int ourScore,
    required int roundsWonInMatch,
    int roundsLostInMatch = 0,
    int dominoWinsInMatch = 0,
    int blockedWinsInMatch = 0,
    int highestRoundPoints = 0,
    int opponentScore = 0,
    bool beatExpertAi = false,
    bool isOnlineMatch = false,
    String gameId = 'iraqi_domino',
    String? todayDateOverride,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final cleanSweep = won && opponentScore == 0 && ourScore > 0;

    final nextGlobalStats = state.stats.recordMatch(
      won: won,
      ourScore: ourScore,
      roundsWonInMatch: roundsWonInMatch,
      roundsLostInMatch: roundsLostInMatch,
      dominoWinsInMatch: dominoWinsInMatch,
      blockedWinsInMatch: blockedWinsInMatch,
      highestRoundPoints: highestRoundPoints,
      cleanSweep: cleanSweep,
      beatExpertAi: beatExpertAi,
    );

    final prevGameStats = state.statsForGame(gameId);
    final nextGameStats = prevGameStats.recordMatch(
      won: won,
      ourScore: ourScore,
      roundsWonInMatch: roundsWonInMatch,
      roundsLostInMatch: roundsLostInMatch,
      dominoWinsInMatch: dominoWinsInMatch,
      blockedWinsInMatch: blockedWinsInMatch,
      highestRoundPoints: highestRoundPoints,
      cleanSweep: cleanSweep,
      beatExpertAi: beatExpertAi,
    );
    final nextPerGame = <String, PlayerStats>{
      ...state.perGameStats,
      gameId: nextGameStats,
    };

    // 1. Match XP (Online only; 0 XP vs Offline AI; capped at daily cap):
    final todayKey = todayDateOverride ?? CafeProgression.todayDateKey(now);
    final earnedToday = state.effectiveDailyMatchXp(todayKey);
    final matchXpResult = CafeProgression.computeMatchXp(
      isOnlineMatch: isOnlineMatch,
      wonMatch: won,
      roundsWon: roundsWonInMatch,
      roundsLost: roundsLostInMatch,
      dailyMatchXpAlreadyEarned: earnedToday,
      isVip: state.isVipActive(now),
      hasDoubleXpBooster: state.hasActiveDoubleXp(now),
      extraDailyCapBonus: state.effectiveDailyCapBoost(todayKey),
    );

    // 2. Check per-game badges (Badge XP bypasses the daily match XP cap!):
    final nextUnlocked = <String>{...state.unlockedBadgeIds};
    var badgeBonusXp = 0;
    for (final badge in CafeProgression.badgesForGame(gameId)) {
      if (!nextUnlocked.contains(badge.id) && badge.isMet(nextGameStats)) {
        nextUnlocked.add(badge.id);
        badgeBonusXp += badge.difficulty.xpReward;
      }
    }

    final nextTotalXp = state.totalXp + matchXpResult.awardedXp + badgeBonusXp;
    final nextDailyMatchXp = earnedToday + matchXpResult.awardedXp;

    // 3. Rating & Rating Shield protection:
    var nextShields = state.ratingShieldCharges;
    int delta;
    if (won) {
      delta = isOnlineMatch ? 20 : 12;
    } else if (nextShields > 0) {
      delta = 0;
      nextShields -= 1;
    } else {
      delta = -8;
    }
    final nextRating = (state.rating + delta).clamp(100, 9999);

    _saveAndEmit(
      state.copyWith(
        stats: nextGlobalStats,
        perGameStats: nextPerGame,
        totalXp: nextTotalXp,
        dailyMatchXp: nextDailyMatchXp,
        dailyXpDate: todayKey,
        ratingShieldCharges: nextShields,
        unlockedBadgeIds: nextUnlocked,
        rating: nextRating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 9: Shop Purchases (3 Days / 7 Days / Permanent, Boosters & VIP)
  // ---------------------------------------------------------------------------

  /// Purchases or rents an item from [CafeShopCatalog] using **دينار المقهى**.
  ShopPurchaseStatus purchaseShopItem({
    required String itemId,
    PurchaseDuration duration = PurchaseDuration.permanent,
    DateTime? now,
    String? todayDateOverride,
  }) {
    final ts = now ?? DateTime.now();
    final item = CafeShopCatalog.byId(itemId);
    if (item == null) return ShopPurchaseStatus.itemNotFound;
    if (item.requiresFutureGame) {
      return ShopPurchaseStatus.gameNotAvailableYet;
    }
    if (item.kind == ShopItemKind.equippable && state.isItemPermanent(itemId)) {
      return ShopPurchaseStatus.alreadyOwnedPermanently;
    }

    final vipActive = state.isVipActive(ts);
    final price = item.priceFor(duration, isVipActive: vipActive);
    if (price == null) return ShopPurchaseStatus.itemNotFound;
    if (state.cafeDinars < price) {
      return ShopPurchaseStatus.insufficientDinars;
    }

    final nextDinars = state.cafeDinars - price;
    final nowMs = ts.millisecondsSinceEpoch;
    final todayKey = todayDateOverride ?? CafeProgression.todayDateKey(ts);

    switch (item.kind) {
      case ShopItemKind.equippable:
        var nextPerm = state.permanentOwnedItemIds;
        var nextRentals = <String, int>{...state.rentedItemExpiries};
        if (duration == PurchaseDuration.permanent) {
          nextPerm = {...nextPerm, itemId};
          nextRentals.remove(itemId);
        } else {
          final baseStart = max(nowMs, nextRentals[itemId] ?? 0);
          final addedMs = Duration(days: duration.days).inMilliseconds;
          nextRentals[itemId] = baseStart + addedMs;
        }

        var nextAccount = state.copyWith(
          cafeDinars: nextDinars,
          permanentOwnedItemIds: nextPerm,
          rentedItemExpiries: nextRentals,
        );
        // Auto-equip newly bought/rented item for instant visual gratification!
        nextAccount = _applyEquipToAccount(nextAccount, item, ts);
        _saveAndEmit(nextAccount);
        return ShopPurchaseStatus.success;

      case ShopItemKind.consumableBooster:
        var nextDoubleXp = state.doubleXpUntilEpochMs;
        var nextCapBoost = state.effectiveDailyCapBoost(todayKey);
        var nextCapDate = state.dailyCapBoostDate;
        var nextShields = state.ratingShieldCharges;
        var nextTickets = state.extraTournamentTickets;

        if (item.id == 'boost_xp_2x_24h' || item.id == 'boost_xp_2x_3d') {
          final startMs = max(nowMs, nextDoubleXp);
          nextDoubleXp =
              startMs + Duration(days: item.durationDays).inMilliseconds;
        } else if (item.id == 'boost_daily_cap_1000') {
          nextCapBoost += 1000;
          nextCapDate = todayKey;
        } else if (item.id == 'boost_rating_shield_3') {
          nextShields += 3;
        } else if (item.id == 'boost_tournament_ticket') {
          nextTickets += 1;
        }

        _saveAndEmit(
          state.copyWith(
            cafeDinars: nextDinars,
            doubleXpUntilEpochMs: nextDoubleXp,
            dailyCapBoostXp: nextCapBoost,
            dailyCapBoostDate: nextCapDate,
            ratingShieldCharges: nextShields,
            extraTournamentTickets: nextTickets,
          ),
        );
        return ShopPurchaseStatus.success;

      case ShopItemKind.vipMembership:
        final startMs = max(nowMs, state.vipUntilEpochMs);
        final nextVipUntil =
            startMs + Duration(days: item.durationDays).inMilliseconds;
        final bonusTickets = item.durationDays >= 30 ? 3 : 1;
        _saveAndEmit(
          state.copyWith(
            cafeDinars: nextDinars,
            vipUntilEpochMs: nextVipUntil,
            extraTournamentTickets:
                state.extraTournamentTickets + bonusTickets,
          ),
        );
        return ShopPurchaseStatus.success;
    }
  }

  /// Equips an already owned/rented cosmetic item.
  bool equipShopItem(String itemId, [DateTime? now]) {
    final ts = now ?? DateTime.now();
    final item = CafeShopCatalog.byId(itemId);
    if (item == null || item.kind != ShopItemKind.equippable) return false;
    if (item.requiresFutureGame) return false;
    if (!state.isItemOwned(itemId, ts)) return false;

    final updated = _applyEquipToAccount(state, item, ts);
    _saveAndEmit(updated);
    return true;
  }

  PlayerAccount _applyEquipToAccount(
    PlayerAccount acc,
    ShopItemDefinition item,
    DateTime ts,
  ) {
    switch (item.category) {
      case ShopCategory.tables:
        return acc.copyWith(equippedTableId: item.id);
      case ShopCategory.frames:
        return acc.copyWith(equippedFrameId: item.id);
      case ShopCategory.gamePieces:
        if (item.gameId == 'iraqi_domino') {
          _syncTileSkinSetting(item.effectiveAssetId);
          return acc.copyWith(equippedDominoSkinId: item.id);
        }
        return acc;
      case ShopCategory.cafeProps:
        return acc.copyWith(equippedCafePropId: item.id);
      case ShopCategory.boosters:
      case ShopCategory.vip:
        return acc;
    }
  }

  void _syncTileSkinSetting(String skinCode) {
    try {
      ref.read(settingsProvider.notifier).setTileSkin(skinCode);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Phase 10: Tournaments & Seasonal Events (Sole Sources of دينار المقهى)
  // ---------------------------------------------------------------------------

  /// Enters a [CafeTournamentTier] (daily free entry, extra ticket, or staked
  /// Dinar entry).
  TournamentEntryStatus startTournamentSession(
    CafeTournamentTier tier, {
    String? todayDateOverride,
  }) {
    if (!tier.enabled) return TournamentEntryStatus.tournamentDisabled;
    final todayKey = todayDateOverride ?? CafeProgression.todayDateKey();

    if (tier.isDailyFree) {
      if (state.hasFreeDailyTournamentAvailable(todayKey)) {
        _saveAndEmit(
          state.copyWith(
            lastFreeTournamentDate: todayKey,
            tournamentsPlayed: state.tournamentsPlayed + 1,
          ),
        );
        return TournamentEntryStatus.enteredFreeDaily;
      }
      if (state.extraTournamentTickets > 0) {
        _saveAndEmit(
          state.copyWith(
            extraTournamentTickets: state.extraTournamentTickets - 1,
            tournamentsPlayed: state.tournamentsPlayed + 1,
          ),
        );
        return TournamentEntryStatus.enteredWithTicket;
      }
      return TournamentEntryStatus.dailyFreeAlreadyUsed;
    }

    if (state.cafeDinars < tier.entryFeeDinars) {
      return TournamentEntryStatus.insufficientDinars;
    }
    _saveAndEmit(
      state.copyWith(
        cafeDinars: state.cafeDinars - tier.entryFeeDinars,
        tournamentsPlayed: state.tournamentsPlayed + 1,
      ),
    );
    return TournamentEntryStatus.enteredPaid;
  }

  /// Settles a completed Tournament match: on victory, awards the net prize pool
  /// (after 10% Café rake) in **دينار المقهى**, uncapped bonus XP, and +1 trophy.
  void completeTournamentMatch({
    required CafeTournamentTier tier,
    required bool won,
  }) {
    if (!won) return;
    _saveAndEmit(
      state.copyWith(
        cafeDinars: state.cafeDinars + tier.netPrizeDinars,
        totalXp: state.totalXp + tier.bonusXpForWinner,
        tournamentsWon: state.tournamentsWon + 1,
      ),
    );
  }

  /// Claims a completed recurring, seasonal, or sponsored [CafeEventDefinition]
  /// once per recurrence period, granting **دينار المقهى** and uncapped XP.
  bool claimEventReward(
    CafeEventDefinition event, {
    String? todayDateOverride,
  }) {
    if (!event.isActiveOn(todayDateOverride)) return false;
    final key = event.claimKey(todayDateOverride);
    if (state.claimedEventIds.contains(key)) return false;
    if (!event.isCompletedBy(state, todayDateOverride)) return false;

    final nextBaselines = <String, int>{...state.eventProgressBaselines};
    if (event.recurrence != EventRecurrenceKind.once) {
      nextBaselines[event.id] = event.rawProgressOf(state);
    }

    _saveAndEmit(
      state.copyWith(
        claimedEventIds: {...state.claimedEventIds, key},
        eventProgressBaselines: nextBaselines,
        cafeDinars: state.cafeDinars + event.rewardDinars,
        totalXp: state.totalXp + event.rewardBonusXp,
      ),
    );
    return true;
  }

  /// Deducts [entryFeeDinars] when entering a paid Tournament (or consumes an
  /// [PlayerAccount.extraTournamentTickets] when [useTicket] is true).
  bool enterTournament({required int entryFeeDinars, bool useTicket = false}) {
    if (useTicket) {
      if (state.extraTournamentTickets <= 0) return false;
      _saveAndEmit(
        state.copyWith(
          extraTournamentTickets: state.extraTournamentTickets - 1,
        ),
      );
      return true;
    }
    if (entryFeeDinars < 0 || state.cafeDinars < entryFeeDinars) return false;
    if (entryFeeDinars == 0) return true;
    _saveAndEmit(state.copyWith(cafeDinars: state.cafeDinars - entryFeeDinars));
    return true;
  }

  /// Awards net tournament prize Dinars (after 10% Café rake) and optional XP.
  void awardTournamentPrize({required int prizeDinars, int bonusXp = 0}) {
    if (prizeDinars <= 0 && bonusXp <= 0) return;
    _saveAndEmit(
      state.copyWith(
        cafeDinars: state.cafeDinars + max(0, prizeDinars),
        totalXp: state.totalXp + max(0, bonusXp),
      ),
    );
  }

  /// Grants Event liquidity Dinars and/or uncapped Event XP.
  void grantEventReward({int dinars = 0, int bonusXp = 0}) {
    if (dinars <= 0 && bonusXp <= 0) return;
    _saveAndEmit(
      state.copyWith(
        cafeDinars: state.cafeDinars + max(0, dinars),
        totalXp: state.totalXp + max(0, bonusXp),
      ),
    );
  }

  /// Grants bonus event/challenge XP directly (bypasses the daily match cap).
  void grantEventBonusXp(int bonusXp) => grantEventReward(bonusXp: bonusXp);

  /// Toggles direct VIP status (for testing/admin or permanent VIP).
  void setVipStatus(bool isVip) {
    _saveAndEmit(state.copyWith(isVip: isVip));
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
