import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../data/player_account.dart';

/// Stored server-side record of a registered account, including moderation
/// state (temporary ban window or account cancellation). Pure Dart.
class StoredServerAccount {
  const StoredServerAccount({
    required this.account,
    required this.passwordSalt,
    required this.passwordHash,
    this.bannedUntilEpochMs = 0,
    this.banReason = '',
    this.isCancelled = false,
  });

  final PlayerAccount account;
  final String passwordSalt;
  final String passwordHash;
  final int bannedUntilEpochMs;
  final String banReason;
  final bool isCancelled;

  bool isBannedNow([DateTime? now]) {
    if (isCancelled) return true;
    final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return bannedUntilEpochMs > ms;
  }

  String? activeAccessError([DateTime? now]) {
    if (isCancelled) {
      return 'تم إلغاء هذا الحساب من قبل إدارة المقهى';
    }
    final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
    if (bannedUntilEpochMs > ms) {
      final until = DateTime.fromMillisecondsSinceEpoch(bannedUntilEpochMs);
      final dateStr =
          '${until.year}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')} '
          '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';
      final reasonPart = banReason.isEmpty ? '' : ' (السبب: $banReason)';
      return 'حسابك محظور مؤقتاً حتى $dateStr$reasonPart';
    }
    return null;
  }

  StoredServerAccount copyWith({
    PlayerAccount? account,
    String? passwordSalt,
    String? passwordHash,
    int? bannedUntilEpochMs,
    String? banReason,
    bool? isCancelled,
  }) => StoredServerAccount(
    account: account ?? this.account,
    passwordSalt: passwordSalt ?? this.passwordSalt,
    passwordHash: passwordHash ?? this.passwordHash,
    bannedUntilEpochMs: bannedUntilEpochMs ?? this.bannedUntilEpochMs,
    banReason: banReason ?? this.banReason,
    isCancelled: isCancelled ?? this.isCancelled,
  );

  Map<String, Object?> toJson() => {
    'account': account.toJson(),
    'passwordSalt': passwordSalt,
    'passwordHash': passwordHash,
    'bannedUntilEpochMs': bannedUntilEpochMs,
    'banReason': banReason,
    'isCancelled': isCancelled,
  };

  Map<String, Object?> toAdminSummaryJson([DateTime? now]) => {
    'playerId': account.playerId,
    'displayName': account.displayName,
    'email': account.email ?? '',
    'provider': account.authProvider.id,
    'level': account.level,
    'rating': account.rating,
    'cafeDinars': account.cafeDinars,
    'isVip': account.isVipActive(now),
    'matchesPlayed': account.stats.matchesPlayed,
    'matchesWon': account.stats.matchesWon,
    'tournamentsWon': account.tournamentsWon,
    'isBanned': isBannedNow(now),
    'isCancelled': isCancelled,
    'bannedUntilEpochMs': bannedUntilEpochMs,
    'banReason': banReason,
  };

  factory StoredServerAccount.fromJson(Map<String, Object?> json) {
    final accMap = json['account'] as Map<String, Object?>? ?? const {};
    final decoded =
        PlayerAccount.tryDecode(jsonEncode(accMap)) ??
        PlayerAccount.createDefaultGuest();
    return StoredServerAccount(
      account: decoded,
      passwordSalt: (json['passwordSalt'] as String?) ?? '',
      passwordHash: (json['passwordHash'] as String?) ?? '',
      bannedUntilEpochMs: (json['bannedUntilEpochMs'] as num?)?.toInt() ?? 0,
      banReason: (json['banReason'] as String?) ?? '',
      isCancelled: (json['isCancelled'] as bool?) ?? false,
    );
  }
}

/// Authoritative account, moderation, & leaderboard store for the Pure-Dart
/// **المقهى** Online Server.
class ServerAccountStore {
  ServerAccountStore({this.storageFilePath}) {
    _loadFromDisk();
  }

  final String? storageFilePath;
  final Random _random = Random.secure();

  final Map<String, StoredServerAccount> _byEmail = {};
  final Map<String, StoredServerAccount> _byUserId = {};
  final Map<String, String> _tokenToUserId = {};

  int get totalAccountCount => _byUserId.length;

  int activeBannedCount([DateTime? now]) =>
      _byUserId.values.where((r) => r.isBannedNow(now)).length;

  /// Checks whether [playerId] is currently banned or cancelled before joining
  /// online rooms or matchmaking.
  String? checkPlayerAccessError(String? playerId, [DateTime? now]) {
    if (playerId == null || playerId.isEmpty) return null;
    final rec = _byUserId[playerId];
    return rec?.activeAccessError(now);
  }

  /// Registers a new email account (preserving Guest stats, Dinars, & items).
  PlayerAccount register({
    required String displayName,
    required String email,
    required String password,
    PlayerAccount? guestAccount,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = displayName.trim();
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw ArgumentError('البريد الإلكتروني غير صالح');
    }
    if (cleanName.length < 2) {
      throw ArgumentError('الاسم يجب أن يكون حرفين على الأقل');
    }
    if (password.length < 6) {
      throw ArgumentError('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
    }
    if (_byEmail.containsKey(cleanEmail)) {
      throw StateError('البريد الإلكتروني مسجل مسبقاً، يرجى تسجيل الدخول');
    }

    final userId = 'usr_${_randomHex(12)}';
    final salt = _randomHex(16);
    final hash = _hashPassword(password, salt);
    final token = 'tok_${_randomHex(24)}';
    final refresh = 'ref_${_randomHex(24)}';

    final mergedStats = guestAccount?.stats ?? const PlayerStats();
    final mergedRating = guestAccount != null && guestAccount.rating > 1000
        ? guestAccount.rating
        : 1000;

    final account = PlayerAccount(
      playerId: userId,
      guestDeviceId: guestAccount?.guestDeviceId ?? userId,
      kind: AccountKind.authenticated,
      authProvider: AuthProviderKind.email,
      displayName: cleanName,
      email: cleanEmail,
      authToken: token,
      refreshToken: refresh,
      avatarIndex: guestAccount?.avatarIndex ?? 0,
      rating: mergedRating,
      totalXp: guestAccount?.totalXp ?? 0,
      dailyMatchXp: guestAccount?.dailyMatchXp ?? 0,
      dailyXpDate: guestAccount?.dailyXpDate ?? '',
      isVip: guestAccount?.isVip ?? false,
      vipUntilEpochMs: guestAccount?.vipUntilEpochMs ?? 0,
      cafeDinars: guestAccount?.cafeDinars ?? 250,
      permanentOwnedItemIds: guestAccount?.permanentOwnedItemIds ?? const {},
      rentedItemExpiries: guestAccount?.rentedItemExpiries ?? const {},
      equippedTableId: guestAccount?.equippedTableId ?? 'table_classic_green',
      equippedFrameId: guestAccount?.equippedFrameId ?? 'frame_none',
      equippedDominoSkinId: guestAccount?.equippedDominoSkinId ?? 'tile_ivory',
      equippedCafePropId:
          guestAccount?.equippedCafePropId ?? 'prop_estekan_tea',
      doubleXpUntilEpochMs: guestAccount?.doubleXpUntilEpochMs ?? 0,
      dailyCapBoostXp: guestAccount?.dailyCapBoostXp ?? 0,
      dailyCapBoostDate: guestAccount?.dailyCapBoostDate ?? '',
      ratingShieldCharges: guestAccount?.ratingShieldCharges ?? 0,
      extraTournamentTickets: guestAccount?.extraTournamentTickets ?? 0,
      tournamentsPlayed: guestAccount?.tournamentsPlayed ?? 0,
      tournamentsWon: guestAccount?.tournamentsWon ?? 0,
      lastFreeTournamentDate: guestAccount?.lastFreeTournamentDate ?? '',
      claimedEventIds: guestAccount?.claimedEventIds ?? const {},
      eventProgressBaselines: guestAccount?.eventProgressBaselines ?? const {},
      unlockedBadgeIds: guestAccount?.unlockedBadgeIds ?? const {},
      stats: mergedStats,
      perGameStats: guestAccount?.perGameStats ?? const {},
    );

    final record = StoredServerAccount(
      account: account,
      passwordSalt: salt,
      passwordHash: hash,
    );
    _byEmail[cleanEmail] = record;
    _byUserId[userId] = record;
    _tokenToUserId[token] = userId;
    _saveToDisk();
    return account;
  }

  /// Signs in or registers via Google email (`AuthProviderKind.google`).
  PlayerAccount loginOrRegisterGoogle({
    required String googleEmail,
    required String displayName,
    PlayerAccount? guestAccount,
  }) {
    final cleanEmail = googleEmail.trim().toLowerCase();
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw ArgumentError('بريد Google غير صالح');
    }
    final existing = _byEmail[cleanEmail];
    if (existing != null) {
      final banErr = existing.activeAccessError();
      if (banErr != null) throw StateError(banErr);

      final token = 'tok_${_randomHex(24)}';
      final oldToken = existing.account.authToken;
      if (oldToken != null) _tokenToUserId.remove(oldToken);

      final updatedAcc = existing.account.copyWith(authToken: token);
      final nextRec = existing.copyWith(account: updatedAcc);
      _byEmail[cleanEmail] = nextRec;
      _byUserId[updatedAcc.playerId] = nextRec;
      _tokenToUserId[token] = updatedAcc.playerId;
      _saveToDisk();
      return updatedAcc;
    }

    final cleanName = displayName.trim().length >= 2
        ? displayName.trim()
        : cleanEmail.split('@').first;
    final userId = 'usr_g_${_randomHex(12)}';
    final token = 'tok_${_randomHex(24)}';
    final refresh = 'ref_${_randomHex(24)}';

    final account = (guestAccount ?? PlayerAccount.createDefaultGuest())
        .copyWith(
          playerId: userId,
          kind: AccountKind.authenticated,
          authProvider: AuthProviderKind.google,
          displayName: cleanName,
          email: cleanEmail,
          authToken: token,
          refreshToken: refresh,
        );

    final record = StoredServerAccount(
      account: account,
      passwordSalt: 'google_oauth',
      passwordHash: 'google_oauth',
    );
    _byEmail[cleanEmail] = record;
    _byUserId[userId] = record;
    _tokenToUserId[token] = userId;
    _saveToDisk();
    return account;
  }

  /// Authenticates an existing email account (rejects banned/cancelled accounts).
  PlayerAccount login({
    required String email,
    required String password,
    PlayerAccount? guestAccount,
    DateTime? now,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final existing = _byEmail[cleanEmail];
    if (existing == null) {
      throw StateError('الحساب غير موجود، يرجى إنشاء حساب جديد');
    }
    final banErr = existing.activeAccessError(now);
    if (banErr != null) {
      throw StateError(banErr);
    }

    final checkHash = _hashPassword(password, existing.passwordSalt);
    if (checkHash != existing.passwordHash) {
      throw StateError('كلمة المرور غير صحيحة');
    }

    final token = 'tok_${_randomHex(24)}';
    final oldToken = existing.account.authToken;
    if (oldToken != null) _tokenToUserId.remove(oldToken);

    var stats = existing.account.stats;
    var rating = existing.account.rating;
    if (guestAccount != null &&
        guestAccount.isGuest &&
        guestAccount.stats.matchesPlayed > stats.matchesPlayed) {
      stats = guestAccount.stats;
      rating = max(rating, guestAccount.rating);
    }

    final updated = existing.account.copyWith(
      authToken: token,
      guestDeviceId:
          guestAccount?.guestDeviceId ?? existing.account.guestDeviceId,
      stats: stats,
      rating: rating,
    );

    final record = existing.copyWith(account: updated);
    _byEmail[cleanEmail] = record;
    _byUserId[updated.playerId] = record;
    _tokenToUserId[token] = updated.playerId;
    _saveToDisk();
    return updated;
  }

  PlayerAccount? verifyToken(String? token, [DateTime? now]) {
    if (token == null || token.isEmpty) return null;
    final clean = token.replaceFirst('Bearer ', '').trim();
    final userId = _tokenToUserId[clean];
    if (userId == null) return null;
    final rec = _byUserId[userId];
    if (rec == null || rec.isBannedNow(now)) return null;
    return rec.account;
  }

  /// Syncs updated stats/displayName from an authenticated client.
  PlayerAccount? syncAccount({
    required String token,
    required PlayerAccount clientAccount,
    DateTime? now,
  }) {
    final clean = token.replaceFirst('Bearer ', '').trim();
    final userId = _tokenToUserId[clean];
    if (userId == null) return null;
    final existing = _byUserId[userId];
    if (existing == null) return null;
    final banErr = existing.activeAccessError(now);
    if (banErr != null) {
      throw StateError(banErr);
    }

    final verified = existing.account;
    final updated = verified.copyWith(
      displayName: clientAccount.displayName,
      avatarIndex: clientAccount.avatarIndex,
      rating: clientAccount.rating,
      totalXp: clientAccount.totalXp,
      dailyMatchXp: clientAccount.dailyMatchXp,
      dailyXpDate: clientAccount.dailyXpDate,
      isVip: clientAccount.isVip,
      vipUntilEpochMs: clientAccount.vipUntilEpochMs,
      cafeDinars: clientAccount.cafeDinars,
      permanentOwnedItemIds: clientAccount.permanentOwnedItemIds,
      rentedItemExpiries: clientAccount.rentedItemExpiries,
      equippedTableId: clientAccount.equippedTableId,
      equippedFrameId: clientAccount.equippedFrameId,
      equippedDominoSkinId: clientAccount.equippedDominoSkinId,
      equippedCafePropId: clientAccount.equippedCafePropId,
      doubleXpUntilEpochMs: clientAccount.doubleXpUntilEpochMs,
      dailyCapBoostXp: clientAccount.dailyCapBoostXp,
      dailyCapBoostDate: clientAccount.dailyCapBoostDate,
      ratingShieldCharges: clientAccount.ratingShieldCharges,
      extraTournamentTickets: clientAccount.extraTournamentTickets,
      tournamentsPlayed: clientAccount.tournamentsPlayed,
      tournamentsWon: clientAccount.tournamentsWon,
      lastFreeTournamentDate: clientAccount.lastFreeTournamentDate,
      claimedEventIds: clientAccount.claimedEventIds,
      eventProgressBaselines: clientAccount.eventProgressBaselines,
      unlockedBadgeIds: clientAccount.unlockedBadgeIds,
      stats: clientAccount.stats,
      perGameStats: clientAccount.perGameStats,
    );
    final record = existing.copyWith(account: updated);
    if (updated.email != null) {
      _byEmail[updated.email!] = record;
    }
    _byUserId[updated.playerId] = record;
    _saveToDisk();
    return updated;
  }

  /// Returns top non-banned players sorted by rating descending.
  List<PublicPlayerProfile> topLeaderboard({int limit = 20, DateTime? now}) {
    final list = [
      for (final rec in _byUserId.values)
        if (!rec.isBannedNow(now)) rec.account.toPublicProfile(now),
    ]..sort((a, b) => b.rating.compareTo(a.rating));
    return list.length <= limit ? list : list.sublist(0, limit);
  }

  // ---------------------------------------------------------------------------
  // Admin Moderation Controls (Players, Temporary Bans, Account Cancellation)
  // ---------------------------------------------------------------------------

  List<Map<String, Object?>> listAccountsForAdmin({
    String? search,
    DateTime? now,
  }) {
    final q = search?.trim().toLowerCase() ?? '';
    final list = [
      for (final rec in _byUserId.values)
        if (q.isEmpty ||
            rec.account.displayName.toLowerCase().contains(q) ||
            (rec.account.email?.toLowerCase().contains(q) ?? false) ||
            rec.account.playerId.toLowerCase().contains(q))
          rec.toAdminSummaryJson(now),
    ];
    list.sort(
      (a, b) => ((b['rating'] as int?) ?? 0).compareTo(
        (a['rating'] as int?) ?? 0,
      ),
    );
    return list;
  }

  /// Temporarily bans [userId] for [durationHours] with an explicit [reason],
  /// revoking active auth tokens immediately.
  StoredServerAccount? banAccount({
    required String userId,
    required int durationHours,
    String reason = '',
    DateTime? now,
  }) {
    final existing = _byUserId[userId];
    if (existing == null) return null;
    final ts = now ?? DateTime.now();
    final untilMs =
        ts.millisecondsSinceEpoch +
        Duration(hours: max(1, durationHours)).inMilliseconds;

    final tok = existing.account.authToken;
    if (tok != null) _tokenToUserId.remove(tok);

    final updated = existing.copyWith(
      bannedUntilEpochMs: untilMs,
      banReason: reason.trim(),
    );
    _byUserId[userId] = updated;
    if (updated.account.email != null) {
      _byEmail[updated.account.email!] = updated;
    }
    _saveToDisk();
    return updated;
  }

  /// Lifts any temporary ban or cancellation on [userId].
  StoredServerAccount? unbanAccount(String userId) {
    final existing = _byUserId[userId];
    if (existing == null) return null;
    final updated = existing.copyWith(
      bannedUntilEpochMs: 0,
      banReason: '',
      isCancelled: false,
    );
    _byUserId[userId] = updated;
    if (updated.account.email != null) {
      _byEmail[updated.account.email!] = updated;
    }
    _saveToDisk();
    return updated;
  }

  /// Permanently cancels & removes [userId] from the server and revokes tokens.
  bool cancelAndDeleteAccount(String userId) {
    final existing = _byUserId.remove(userId);
    if (existing == null) return false;
    final email = existing.account.email;
    if (email != null) _byEmail.remove(email);
    _tokenToUserId.removeWhere((_, uid) => uid == userId);
    _saveToDisk();
    return true;
  }

  /// Allows the admin panel to adjust Dinars, Rating, or VIP status directly.
  StoredServerAccount? updateAccountByAdmin({
    required String userId,
    int? cafeDinars,
    int? rating,
    bool? isVip,
  }) {
    final existing = _byUserId[userId];
    if (existing == null) return null;
    final nextAcc = existing.account.copyWith(
      cafeDinars: cafeDinars != null ? max(0, cafeDinars) : null,
      rating: rating?.clamp(100, 9999),
      isVip: isVip,
    );
    final updated = existing.copyWith(account: nextAcc);
    _byUserId[userId] = updated;
    if (nextAcc.email != null) _byEmail[nextAcc.email!] = updated;
    _saveToDisk();
    return updated;
  }

  String _randomHex(int length) => List.generate(
    length,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();

  static String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt::iraqi_domino::$password');
    var h1 = 0xCBF29CE484222325;
    var h2 = 0x84222325CBF29CE4;
    for (var round = 0; round < 1024; round++) {
      for (final b in bytes) {
        h1 ^= (b + round) & 0xFF;
        h1 = (h1 * 0x100000001B3) & 0x7FFFFFFFFFFFFFFF;
        h2 ^= ((b ^ round) & 0xFF);
        h2 = (h2 * 0x100000001B3) & 0x7FFFFFFFFFFFFFFF;
      }
    }
    return '${h1.toRadixString(16).padLeft(16, '0')}${h2.toRadixString(16).padLeft(16, '0')}';
  }

  void _loadFromDisk() {
    final path = storageFilePath;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final map = jsonDecode(file.readAsStringSync());
      if (map is! Map<String, Object?>) return;
      final list = map['accounts'] as List<Object?>? ?? const [];
      for (final item in list) {
        if (item is Map<String, Object?>) {
          final rec = StoredServerAccount.fromJson(item);
          final email = rec.account.email;
          if (email != null) _byEmail[email] = rec;
          _byUserId[rec.account.playerId] = rec;
          final tok = rec.account.authToken;
          if (tok != null && !rec.isBannedNow()) {
            _tokenToUserId[tok] = rec.account.playerId;
          }
        }
      }
    } catch (_) {}
  }

  void _saveToDisk() {
    final path = storageFilePath;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      file.writeAsStringSync(
        jsonEncode({
          'accounts': [for (final r in _byUserId.values) r.toJson()],
        }),
      );
    } catch (_) {}
  }
}
