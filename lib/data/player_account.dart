import 'dart:convert';
import 'dart:math';

import 'cafe_progression.dart';
import 'cafe_shop_catalog.dart';

/// Whether the active player profile is a local/online Guest or a verified
/// registered account (Phase 7 Online Auth).
enum AccountKind {
  guest('guest'),
  authenticated('authenticated');

  const AccountKind(this.id);
  final String id;

  static AccountKind byId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return AccountKind.guest;
  }
}

/// Authentication provider backing an [AccountKind.authenticated] account.
enum AuthProviderKind {
  none('none'),
  email('email'),
  google('google'),
  apple('apple'),
  phone('phone');

  const AuthProviderKind(this.id);
  final String id;

  static AuthProviderKind byId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return AuthProviderKind.none;
  }
}

/// Detailed statistics tracked both globally across Al-Maqha ("المقهى") and
/// individually per game (`'iraqi_domino'`, `'backgammon'`, `'cards'`).
class PlayerStats {
  const PlayerStats({
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.roundsWon = 0,
    this.roundsLost = 0,
    this.dominoRoundWins = 0,
    this.blockedRoundWins = 0,
    this.highestSingleRoundScore = 0,
    this.cleanSweepWins = 0,
    this.expertAiWins = 0,
    this.currentWinStreak = 0,
    this.bestWinStreak = 0,
    this.totalPointsScored = 0,
  });

  final int matchesPlayed;
  final int matchesWon;
  final int roundsWon;
  final int roundsLost;
  final int dominoRoundWins;
  final int blockedRoundWins;
  final int highestSingleRoundScore;
  final int cleanSweepWins;
  final int expertAiWins;
  final int currentWinStreak;
  final int bestWinStreak;
  final int totalPointsScored;

  int get matchesLost => max(0, matchesPlayed - matchesWon);

  double get winRate =>
      matchesPlayed == 0 ? 0.0 : matchesWon / matchesPlayed;

  PlayerStats recordMatch({
    required bool won,
    required int ourScore,
    required int roundsWonInMatch,
    int roundsLostInMatch = 0,
    int dominoWinsInMatch = 0,
    int blockedWinsInMatch = 0,
    int highestRoundPoints = 0,
    bool cleanSweep = false,
    bool beatExpertAi = false,
  }) {
    final nextPlayed = matchesPlayed + 1;
    final nextWon = matchesWon + (won ? 1 : 0);
    final nextStreak = won ? currentWinStreak + 1 : 0;
    final nextBest = nextStreak > bestWinStreak ? nextStreak : bestWinStreak;
    return PlayerStats(
      matchesPlayed: nextPlayed,
      matchesWon: nextWon,
      roundsWon: roundsWon + roundsWonInMatch,
      roundsLost: roundsLost + roundsLostInMatch,
      dominoRoundWins: dominoRoundWins + dominoWinsInMatch,
      blockedRoundWins: blockedRoundWins + blockedWinsInMatch,
      highestSingleRoundScore: max(
        highestSingleRoundScore,
        highestRoundPoints,
      ),
      cleanSweepWins: cleanSweepWins + (won && cleanSweep ? 1 : 0),
      expertAiWins: expertAiWins + (won && beatExpertAi ? 1 : 0),
      currentWinStreak: nextStreak,
      bestWinStreak: nextBest,
      totalPointsScored: totalPointsScored + ourScore,
    );
  }

  Map<String, Object?> toJson() => {
    'matchesPlayed': matchesPlayed,
    'matchesWon': matchesWon,
    'roundsWon': roundsWon,
    'roundsLost': roundsLost,
    'dominoRoundWins': dominoRoundWins,
    'blockedRoundWins': blockedRoundWins,
    'highestSingleRoundScore': highestSingleRoundScore,
    'cleanSweepWins': cleanSweepWins,
    'expertAiWins': expertAiWins,
    'currentWinStreak': currentWinStreak,
    'bestWinStreak': bestWinStreak,
    'totalPointsScored': totalPointsScored,
  };

  factory PlayerStats.fromJson(Map<String, Object?> json) => PlayerStats(
    matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
    matchesWon: (json['matchesWon'] as num?)?.toInt() ?? 0,
    roundsWon: (json['roundsWon'] as num?)?.toInt() ?? 0,
    roundsLost: (json['roundsLost'] as num?)?.toInt() ?? 0,
    dominoRoundWins: (json['dominoRoundWins'] as num?)?.toInt() ?? 0,
    blockedRoundWins: (json['blockedRoundWins'] as num?)?.toInt() ?? 0,
    highestSingleRoundScore:
        (json['highestSingleRoundScore'] as num?)?.toInt() ?? 0,
    cleanSweepWins: (json['cleanSweepWins'] as num?)?.toInt() ?? 0,
    expertAiWins: (json['expertAiWins'] as num?)?.toInt() ?? 0,
    currentWinStreak: (json['currentWinStreak'] as num?)?.toInt() ?? 0,
    bestWinStreak: (json['bestWinStreak'] as num?)?.toInt() ?? 0,
    totalPointsScored: (json['totalPointsScored'] as num?)?.toInt() ?? 0,
  );
}

/// Safe, token-free public identity broadcast to peers in Local Wi-Fi,
/// Offline Wi-Fi, Bluetooth, and Online rooms. Pure Dart.
class PublicPlayerProfile {
  const PublicPlayerProfile({
    required this.playerId,
    required this.displayName,
    required this.isGuest,
    this.avatarIndex = 0,
    this.rating = 1000,
    this.level = 1,
    this.isVip = false,
    this.avatarFrameId = 'frame_none',
    this.cafePropId = 'prop_estekan_tea',
  });

  final String playerId;
  final String displayName;
  final bool isGuest;
  final int avatarIndex;
  final int rating;
  final int level;
  final bool isVip;
  final String avatarFrameId;
  final String cafePropId;

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'displayName': displayName,
    'isGuest': isGuest,
    'avatarIndex': avatarIndex,
    'rating': rating,
    'level': level,
    'isVip': isVip,
    'avatarFrameId': avatarFrameId,
    'cafePropId': cafePropId,
  };

  factory PublicPlayerProfile.fromJson(Map<String, Object?> json) {
    final rawName = (json['displayName'] as String?)?.trim() ?? '';
    return PublicPlayerProfile(
      playerId: (json['playerId'] as String?) ?? 'guest_unknown',
      displayName: rawName.isEmpty ? 'لاعب' : rawName,
      isGuest: (json['isGuest'] as bool?) ?? true,
      avatarIndex: (json['avatarIndex'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? 1000,
      level: ((json['level'] as num?)?.toInt() ?? 1).clamp(
        1,
        CafeProgression.maxLevel,
      ),
      isVip: (json['isVip'] as bool?) ?? false,
      avatarFrameId: (json['avatarFrameId'] as String?) ?? 'frame_none',
      cafePropId: (json['cafePropId'] as String?) ?? 'prop_estekan_tea',
    );
  }
}

/// Complete player account model stored in the unified `GameDataCenter`.
/// Pure Dart (zero Flutter imports) so `bin/server.dart` uses it directly.
class PlayerAccount {
  const PlayerAccount({
    required this.playerId,
    required this.guestDeviceId,
    required this.kind,
    required this.authProvider,
    required this.displayName,
    this.email,
    this.authToken,
    this.refreshToken,
    this.avatarIndex = 0,
    this.rating = 1000,
    this.totalXp = 0,
    this.dailyMatchXp = 0,
    this.dailyXpDate = '',
    this.isVip = false,
    this.vipUntilEpochMs = 0,
    this.cafeDinars = CafeShopCatalog.starterWelcomeDinars,
    this.permanentOwnedItemIds = const {},
    this.rentedItemExpiries = const {},
    this.equippedTableId = 'table_classic_green',
    this.equippedFrameId = 'frame_none',
    this.equippedDominoSkinId = 'tile_ivory',
    this.equippedCafePropId = 'prop_estekan_tea',
    this.doubleXpUntilEpochMs = 0,
    this.dailyCapBoostXp = 0,
    this.dailyCapBoostDate = '',
    this.ratingShieldCharges = 0,
    this.extraTournamentTickets = 0,
    this.tournamentsPlayed = 0,
    this.tournamentsWon = 0,
    this.lastFreeTournamentDate = '',
    this.claimedEventIds = const {},
    this.eventProgressBaselines = const {},
    this.unlockedBadgeIds = const {},
    this.stats = const PlayerStats(),
    this.perGameStats = const {},
  });

  final String playerId;
  final String guestDeviceId;
  final AccountKind kind;
  final AuthProviderKind authProvider;
  final String displayName;
  final String? email;
  final String? authToken;
  final String? refreshToken;
  final int avatarIndex;
  final int rating;

  /// Cumulative Café XP across all games, badges, and events.
  final int totalXp;

  /// Match XP earned today (capped at `2,000 XP/day`, or `4,000 XP/day` if VIP,
  /// plus any active [dailyCapBoostXp] for today).
  final int dailyMatchXp;

  /// Calendar date (`YYYY-MM-DD`) corresponding to [dailyMatchXp].
  final String dailyXpDate;

  /// Direct VIP flag or timed `مجلس شيوخ المقهى` membership via [vipUntilEpochMs].
  final bool isVip;
  final int vipUntilEpochMs;

  /// Single Café currency: **دينار المقهى** (`Café Dinar`).
  /// Earned strictly from Tournaments & Events (never from regular matches).
  final int cafeDinars;

  /// Item IDs owned permanently.
  final Set<String> permanentOwnedItemIds;

  /// Item IDs rented temporarily mapped to their UTC/local expiration epoch ms.
  final Map<String, int> rentedItemExpiries;

  /// Equipped Shop cosmetics (automatically fall back to defaults if expired).
  final String equippedTableId;
  final String equippedFrameId;
  final String equippedDominoSkinId;
  final String equippedCafePropId;

  /// Active smart boosters.
  final int doubleXpUntilEpochMs;
  final int dailyCapBoostXp;
  final String dailyCapBoostDate;
  final int ratingShieldCharges;
  final int extraTournamentTickets;

  /// Phase 10: Tournament & Event progression records.
  final int tournamentsPlayed;
  final int tournamentsWon;
  final String lastFreeTournamentDate;
  final Set<String> claimedEventIds;
  final Map<String, int> eventProgressBaselines;

  /// Unlocked badge IDs across all games in Al-Maqha.
  final Set<String> unlockedBadgeIds;

  /// Global Café summary statistics across all games.
  final PlayerStats stats;

  /// Per-game detailed statistics keyed by `gameId` (e.g. `'iraqi_domino'`).
  final Map<String, PlayerStats> perGameStats;

  bool get isGuest => kind == AccountKind.guest;
  bool get isAuthenticated => kind == AccountKind.authenticated;

  /// Whether **مجلس شيوخ المقهى (VIP)** is currently active.
  bool isVipActive([DateTime? now]) {
    if (isVip) return true;
    final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return vipUntilEpochMs > ms;
  }

  /// Whether a `2x XP` booster card is currently active.
  bool hasActiveDoubleXp([DateTime? now]) {
    final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return doubleXpUntilEpochMs > ms;
  }

  /// Extra daily XP cap active on [todayKey] from `'boost_daily_cap_1000'`.
  int effectiveDailyCapBoost([String? todayKey]) {
    final key = todayKey ?? CafeProgression.todayDateKey();
    return dailyCapBoostDate == key ? max(0, dailyCapBoostXp) : 0;
  }

  /// Resolved Café level (`1..50`) and progress bar metrics from [totalXp].
  ({int level, int currentLevelXp, int nextLevelXp, double progress})
  get levelInfo => CafeProgression.resolveLevel(totalXp);

  int get level => levelInfo.level;

  int get dailyMatchXpCap => effectiveDailyMatchXpCap();

  int effectiveDailyMatchXpCap({DateTime? now, String? todayKey}) =>
      CafeProgression.dailyCapFor(
        isVip: isVipActive(now),
        extraDailyCapBonus: effectiveDailyCapBoost(todayKey),
      );

  /// Match XP earned on [todayKey] (returns `0` if [dailyXpDate] is from a previous day).
  int effectiveDailyMatchXp([String? todayKey]) {
    final key = todayKey ?? CafeProgression.todayDateKey();
    return dailyXpDate == key ? dailyMatchXp : 0;
  }

  /// Whether [itemId] is owned permanently (starter free or bought permanently).
  bool isItemPermanent(String itemId) =>
      CafeShopCatalog.defaultFreeItemIds.contains(itemId) ||
      permanentOwnedItemIds.contains(itemId);

  /// Whether [itemId] is currently usable (either permanent or active rental).
  bool isItemOwned(String itemId, [DateTime? now]) {
    if (isItemPermanent(itemId)) return true;
    final exp = rentedItemExpiries[itemId];
    if (exp == null) return false;
    final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return exp > ms;
  }

  /// Remaining rental duration for [itemId], or `null` if permanent / expired / unowned.
  Duration? remainingRental(String itemId, [DateTime? now]) {
    if (isItemPermanent(itemId)) return null;
    final exp = rentedItemExpiries[itemId];
    if (exp == null) return null;
    final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
    if (exp <= ms) return null;
    return Duration(milliseconds: exp - ms);
  }

  String effectiveTableId([DateTime? now]) =>
      isItemOwned(equippedTableId, now)
      ? equippedTableId
      : 'table_classic_green';

  String effectiveFrameId([DateTime? now]) =>
      isItemOwned(equippedFrameId, now) ? equippedFrameId : 'frame_none';

  /// Returns the Shop item ID of the equipped Domino stone (`'tile_ivory'`, etc.).
  String effectiveDominoItemId([DateTime? now]) =>
      isItemOwned(equippedDominoSkinId, now)
      ? equippedDominoSkinId
      : 'tile_ivory';

  /// Returns the underlying `TileSkin.id` (`'ivory'`, `'ebony'`, `'amber'`, ...).
  String effectiveDominoSkinCode([DateTime? now]) {
    final itemId = effectiveDominoItemId(now);
    return CafeShopCatalog.byId(itemId)?.effectiveAssetId ?? 'ivory';
  }

  String effectiveCafePropId([DateTime? now]) =>
      isItemOwned(equippedCafePropId, now)
      ? equippedCafePropId
      : 'prop_estekan_tea';

  bool hasLuxuryQuickChat([DateTime? now]) =>
      isItemOwned('chat_sheikh_pack', now);

  /// Whether today's free daily tournament entry has not been used yet.
  bool hasFreeDailyTournamentAvailable([String? todayKey]) {
    final key = todayKey ?? CafeProgression.todayDateKey();
    return lastFreeTournamentDate != key;
  }

  /// Detailed stats for a specific [gameId] (falls back to [stats] for `'iraqi_domino'`
  /// if migrating from an earlier version).
  PlayerStats statsForGame(String gameId) {
    final specific = perGameStats[gameId];
    if (specific != null) return specific;
    if (gameId == 'iraqi_domino') return stats;
    return const PlayerStats();
  }

  factory PlayerAccount.createDefaultGuest([Random? random]) {
    final rng = random ?? Random();
    final hex = List.generate(
      12,
      (_) => rng.nextInt(16).toRadixString(16),
    ).join();
    final tag = (1000 + rng.nextInt(9000)).toString();
    final guestId = 'guest_$hex';
    return PlayerAccount(
      playerId: guestId,
      guestDeviceId: guestId,
      kind: AccountKind.guest,
      authProvider: AuthProviderKind.none,
      displayName: 'ضيف $tag',
      dailyXpDate: CafeProgression.todayDateKey(),
      cafeDinars: CafeShopCatalog.starterWelcomeDinars,
    );
  }

  PublicPlayerProfile toPublicProfile([DateTime? now]) => PublicPlayerProfile(
    playerId: playerId,
    displayName: displayName,
    isGuest: isGuest,
    avatarIndex: avatarIndex,
    rating: rating,
    level: level,
    isVip: isVipActive(now),
    avatarFrameId: effectiveFrameId(now),
    cafePropId: effectiveCafePropId(now),
  );

  PlayerAccount copyWith({
    String? playerId,
    String? guestDeviceId,
    AccountKind? kind,
    AuthProviderKind? authProvider,
    String? displayName,
    String? email,
    String? authToken,
    String? refreshToken,
    bool clearAuthCredentials = false,
    int? avatarIndex,
    int? rating,
    int? totalXp,
    int? dailyMatchXp,
    String? dailyXpDate,
    bool? isVip,
    int? vipUntilEpochMs,
    int? cafeDinars,
    Set<String>? permanentOwnedItemIds,
    Map<String, int>? rentedItemExpiries,
    String? equippedTableId,
    String? equippedFrameId,
    String? equippedDominoSkinId,
    String? equippedCafePropId,
    int? doubleXpUntilEpochMs,
    int? dailyCapBoostXp,
    String? dailyCapBoostDate,
    int? ratingShieldCharges,
    int? extraTournamentTickets,
    int? tournamentsPlayed,
    int? tournamentsWon,
    String? lastFreeTournamentDate,
    Set<String>? claimedEventIds,
    Map<String, int>? eventProgressBaselines,
    Set<String>? unlockedBadgeIds,
    PlayerStats? stats,
    Map<String, PlayerStats>? perGameStats,
  }) {
    return PlayerAccount(
      playerId: playerId ?? this.playerId,
      guestDeviceId: guestDeviceId ?? this.guestDeviceId,
      kind: kind ?? this.kind,
      authProvider: authProvider ?? this.authProvider,
      displayName: displayName ?? this.displayName,
      email: clearAuthCredentials ? null : (email ?? this.email),
      authToken: clearAuthCredentials ? null : (authToken ?? this.authToken),
      refreshToken: clearAuthCredentials
          ? null
          : (refreshToken ?? this.refreshToken),
      avatarIndex: avatarIndex ?? this.avatarIndex,
      rating: rating ?? this.rating,
      totalXp: totalXp ?? this.totalXp,
      dailyMatchXp: dailyMatchXp ?? this.dailyMatchXp,
      dailyXpDate: dailyXpDate ?? this.dailyXpDate,
      isVip: isVip ?? this.isVip,
      vipUntilEpochMs: vipUntilEpochMs ?? this.vipUntilEpochMs,
      cafeDinars: cafeDinars ?? this.cafeDinars,
      permanentOwnedItemIds:
          permanentOwnedItemIds ?? this.permanentOwnedItemIds,
      rentedItemExpiries: rentedItemExpiries ?? this.rentedItemExpiries,
      equippedTableId: equippedTableId ?? this.equippedTableId,
      equippedFrameId: equippedFrameId ?? this.equippedFrameId,
      equippedDominoSkinId: equippedDominoSkinId ?? this.equippedDominoSkinId,
      equippedCafePropId: equippedCafePropId ?? this.equippedCafePropId,
      doubleXpUntilEpochMs: doubleXpUntilEpochMs ?? this.doubleXpUntilEpochMs,
      dailyCapBoostXp: dailyCapBoostXp ?? this.dailyCapBoostXp,
      dailyCapBoostDate: dailyCapBoostDate ?? this.dailyCapBoostDate,
      ratingShieldCharges: ratingShieldCharges ?? this.ratingShieldCharges,
      extraTournamentTickets:
          extraTournamentTickets ?? this.extraTournamentTickets,
      tournamentsPlayed: tournamentsPlayed ?? this.tournamentsPlayed,
      tournamentsWon: tournamentsWon ?? this.tournamentsWon,
      lastFreeTournamentDate:
          lastFreeTournamentDate ?? this.lastFreeTournamentDate,
      claimedEventIds: claimedEventIds ?? this.claimedEventIds,
      eventProgressBaselines:
          eventProgressBaselines ?? this.eventProgressBaselines,
      unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
      stats: stats ?? this.stats,
      perGameStats: perGameStats ?? this.perGameStats,
    );
  }

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'guestDeviceId': guestDeviceId,
    'kind': kind.id,
    'authProvider': authProvider.id,
    'displayName': displayName,
    'email': email,
    'authToken': authToken,
    'refreshToken': refreshToken,
    'avatarIndex': avatarIndex,
    'rating': rating,
    'totalXp': totalXp,
    'dailyMatchXp': dailyMatchXp,
    'dailyXpDate': dailyXpDate,
    'isVip': isVip,
    'vipUntilEpochMs': vipUntilEpochMs,
    'cafeDinars': cafeDinars,
    'permanentOwnedItemIds': permanentOwnedItemIds.toList(),
    'rentedItemExpiries': rentedItemExpiries,
    'equippedTableId': equippedTableId,
    'equippedFrameId': equippedFrameId,
    'equippedDominoSkinId': equippedDominoSkinId,
    'equippedCafePropId': equippedCafePropId,
    'doubleXpUntilEpochMs': doubleXpUntilEpochMs,
    'dailyCapBoostXp': dailyCapBoostXp,
    'dailyCapBoostDate': dailyCapBoostDate,
    'ratingShieldCharges': ratingShieldCharges,
    'extraTournamentTickets': extraTournamentTickets,
    'tournamentsPlayed': tournamentsPlayed,
    'tournamentsWon': tournamentsWon,
    'lastFreeTournamentDate': lastFreeTournamentDate,
    'claimedEventIds': claimedEventIds.toList(),
    'eventProgressBaselines': eventProgressBaselines,
    'unlockedBadgeIds': unlockedBadgeIds.toList(),
    'stats': stats.toJson(),
    'perGameStats': {
      for (final e in perGameStats.entries) e.key: e.value.toJson(),
    },
  };

  String encode() => jsonEncode(toJson());

  static PlayerAccount? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      final playerId = decoded['playerId'] as String?;
      if (playerId == null || playerId.isEmpty) return null;
      final guestId = (decoded['guestDeviceId'] as String?) ?? playerId;
      final rawName = (decoded['displayName'] as String?)?.trim() ?? '';
      final statsMap = decoded['stats'];
      final rawBadges = decoded['unlockedBadgeIds'] as List<Object?>? ?? const [];
      final rawClaimedEvents =
          decoded['claimedEventIds'] as List<Object?>? ?? const [];
      final rawBaselines =
          decoded['eventProgressBaselines'] as Map<String, Object?>?;
      final baselines = <String, int>{};
      if (rawBaselines != null) {
        for (final entry in rawBaselines.entries) {
          final v = (entry.value as num?)?.toInt();
          if (v != null && v >= 0) baselines[entry.key] = v;
        }
      }
      final rawOwned =
          decoded['permanentOwnedItemIds'] as List<Object?>? ?? const [];
      final rawRented = decoded['rentedItemExpiries'] as Map<String, Object?>?;
      final rawPerGame = decoded['perGameStats'] as Map<String, Object?>?;

      final rented = <String, int>{};
      if (rawRented != null) {
        for (final entry in rawRented.entries) {
          final v = (entry.value as num?)?.toInt();
          if (v != null && v > 0) rented[entry.key] = v;
        }
      }

      final perGame = <String, PlayerStats>{};
      if (rawPerGame != null) {
        for (final entry in rawPerGame.entries) {
          if (entry.value is Map<String, Object?>) {
            perGame[entry.key] = PlayerStats.fromJson(
              entry.value as Map<String, Object?>,
            );
          }
        }
      }

      return PlayerAccount(
        playerId: playerId,
        guestDeviceId: guestId,
        kind: AccountKind.byId(decoded['kind'] as String?),
        authProvider: AuthProviderKind.byId(decoded['authProvider'] as String?),
        displayName: rawName.isEmpty ? 'لاعب' : rawName,
        email: decoded['email'] as String?,
        authToken: decoded['authToken'] as String?,
        refreshToken: decoded['refreshToken'] as String?,
        avatarIndex: (decoded['avatarIndex'] as num?)?.toInt() ?? 0,
        rating: (decoded['rating'] as num?)?.toInt() ?? 1000,
        totalXp: (decoded['totalXp'] as num?)?.toInt() ?? 0,
        dailyMatchXp: (decoded['dailyMatchXp'] as num?)?.toInt() ?? 0,
        dailyXpDate: (decoded['dailyXpDate'] as String?) ?? '',
        isVip: (decoded['isVip'] as bool?) ?? false,
        vipUntilEpochMs: (decoded['vipUntilEpochMs'] as num?)?.toInt() ?? 0,
        cafeDinars:
            (decoded['cafeDinars'] as num?)?.toInt() ??
            CafeShopCatalog.starterWelcomeDinars,
        permanentOwnedItemIds: {
          for (final id in rawOwned)
            if (id is String && id.isNotEmpty) id,
        },
        rentedItemExpiries: rented,
        equippedTableId:
            (decoded['equippedTableId'] as String?) ?? 'table_classic_green',
        equippedFrameId:
            (decoded['equippedFrameId'] as String?) ?? 'frame_none',
        equippedDominoSkinId:
            (decoded['equippedDominoSkinId'] as String?) ?? 'tile_ivory',
        equippedCafePropId:
            (decoded['equippedCafePropId'] as String?) ?? 'prop_estekan_tea',
        doubleXpUntilEpochMs:
            (decoded['doubleXpUntilEpochMs'] as num?)?.toInt() ?? 0,
        dailyCapBoostXp: (decoded['dailyCapBoostXp'] as num?)?.toInt() ?? 0,
        dailyCapBoostDate: (decoded['dailyCapBoostDate'] as String?) ?? '',
        ratingShieldCharges:
            (decoded['ratingShieldCharges'] as num?)?.toInt() ?? 0,
        extraTournamentTickets:
            (decoded['extraTournamentTickets'] as num?)?.toInt() ?? 0,
        tournamentsPlayed:
            (decoded['tournamentsPlayed'] as num?)?.toInt() ?? 0,
        tournamentsWon: (decoded['tournamentsWon'] as num?)?.toInt() ?? 0,
        lastFreeTournamentDate:
            (decoded['lastFreeTournamentDate'] as String?) ?? '',
        claimedEventIds: {
          for (final ev in rawClaimedEvents)
            if (ev is String && ev.isNotEmpty) ev,
        },
        eventProgressBaselines: baselines,
        unlockedBadgeIds: {
          for (final b in rawBadges)
            if (b is String && b.isNotEmpty) b,
        },
        stats: statsMap is Map<String, Object?>
            ? PlayerStats.fromJson(statsMap)
            : const PlayerStats(),
        perGameStats: perGame,
      );
    } catch (_) {
      return null;
    }
  }
}
