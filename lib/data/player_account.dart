import 'dart:convert';
import 'dart:math';

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

/// Cumulative player statistics tracked centrally across Offline AI, all 3
/// Local Multiplayer channels, and Online matches. Pure Dart.
class PlayerStats {
  const PlayerStats({
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.roundsWon = 0,
    this.currentWinStreak = 0,
    this.bestWinStreak = 0,
    this.totalPointsScored = 0,
  });

  final int matchesPlayed;
  final int matchesWon;
  final int roundsWon;
  final int currentWinStreak;
  final int bestWinStreak;
  final int totalPointsScored;

  double get winRate =>
      matchesPlayed == 0 ? 0.0 : matchesWon / matchesPlayed;

  PlayerStats recordMatch({
    required bool won,
    required int ourScore,
    required int roundsWonInMatch,
  }) {
    final nextPlayed = matchesPlayed + 1;
    final nextWon = matchesWon + (won ? 1 : 0);
    final nextStreak = won ? currentWinStreak + 1 : 0;
    final nextBest = nextStreak > bestWinStreak ? nextStreak : bestWinStreak;
    return PlayerStats(
      matchesPlayed: nextPlayed,
      matchesWon: nextWon,
      roundsWon: roundsWon + roundsWonInMatch,
      currentWinStreak: nextStreak,
      bestWinStreak: nextBest,
      totalPointsScored: totalPointsScored + ourScore,
    );
  }

  Map<String, Object?> toJson() => {
    'matchesPlayed': matchesPlayed,
    'matchesWon': matchesWon,
    'roundsWon': roundsWon,
    'currentWinStreak': currentWinStreak,
    'bestWinStreak': bestWinStreak,
    'totalPointsScored': totalPointsScored,
  };

  factory PlayerStats.fromJson(Map<String, Object?> json) => PlayerStats(
    matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
    matchesWon: (json['matchesWon'] as num?)?.toInt() ?? 0,
    roundsWon: (json['roundsWon'] as num?)?.toInt() ?? 0,
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
  });

  final String playerId;
  final String displayName;
  final bool isGuest;
  final int avatarIndex;
  final int rating;

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'displayName': displayName,
    'isGuest': isGuest,
    'avatarIndex': avatarIndex,
    'rating': rating,
  };

  factory PublicPlayerProfile.fromJson(Map<String, Object?> json) {
    final rawName = (json['displayName'] as String?)?.trim() ?? '';
    return PublicPlayerProfile(
      playerId: (json['playerId'] as String?) ?? 'guest_unknown',
      displayName: rawName.isEmpty ? 'لاعب' : rawName,
      isGuest: (json['isGuest'] as bool?) ?? true,
      avatarIndex: (json['avatarIndex'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? 1000,
    );
  }
}

/// Complete player account model stored in the unified [GameDataCenter].
///
/// Supports seamless offline/online Guest play right now and direct account
/// linking / sign-in in Phase 7 without changing local or network game code.
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
    this.stats = const PlayerStats(),
  });

  /// Stable unique player ID used for seat ownership & reconnect recovery.
  final String playerId;

  /// Permanent device-scoped guest ID preserved even if the user signs in and
  /// later signs back out to Guest mode.
  final String guestDeviceId;

  final AccountKind kind;
  final AuthProviderKind authProvider;
  final String displayName;
  final String? email;
  final String? authToken;
  final String? refreshToken;
  final int avatarIndex;
  final int rating;
  final PlayerStats stats;

  bool get isGuest => kind == AccountKind.guest;
  bool get isAuthenticated => kind == AccountKind.authenticated;

  /// Generates a fresh Guest account with a stable random ID and short tag.
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
    );
  }

  PublicPlayerProfile toPublicProfile() => PublicPlayerProfile(
    playerId: playerId,
    displayName: displayName,
    isGuest: isGuest,
    avatarIndex: avatarIndex,
    rating: rating,
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
    PlayerStats? stats,
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
      stats: stats ?? this.stats,
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
    'stats': stats.toJson(),
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
        stats: statsMap is Map<String, Object?>
            ? PlayerStats.fromJson(statsMap)
            : const PlayerStats(),
      );
    } catch (_) {
      return null;
    }
  }
}
