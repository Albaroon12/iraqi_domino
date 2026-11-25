import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../data/player_account.dart';

/// Stored server-side record of a registered account. Pure Dart.
class StoredServerAccount {
  const StoredServerAccount({
    required this.account,
    required this.passwordSalt,
    required this.passwordHash,
  });

  final PlayerAccount account;
  final String passwordSalt;
  final String passwordHash;

  Map<String, Object?> toJson() => {
    'account': account.toJson(),
    'passwordSalt': passwordSalt,
    'passwordHash': passwordHash,
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
    );
  }
}

/// Authoritative account & leaderboard store for the Pure-Dart Domino Server.
///
/// Supports optional JSON disk persistence ([storageFilePath]) while keeping
/// active lookups in RAM for zero-latency authentication and WebSocket handshakes.
class ServerAccountStore {
  ServerAccountStore({this.storageFilePath}) {
    _loadFromDisk();
  }

  final String? storageFilePath;
  final Random _random = Random.secure();

  final Map<String, StoredServerAccount> _byEmail = {};
  final Map<String, StoredServerAccount> _byUserId = {};
  final Map<String, String> _tokenToUserId = {};

  /// Registers a new account (or upgrades a Guest account, preserving all
  /// accumulated wins, streaks, and rating).
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
      stats: mergedStats,
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

  /// Authenticates an existing account and merges any higher Guest stats from
  /// the device if upgrading.
  PlayerAccount login({
    required String email,
    required String password,
    PlayerAccount? guestAccount,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final existing = _byEmail[cleanEmail];
    if (existing == null) {
      throw StateError('الحساب غير موجود، يرجى إنشاء حساب جديد');
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
      guestDeviceId: guestAccount?.guestDeviceId ?? existing.account.guestDeviceId,
      stats: stats,
      rating: rating,
    );

    final record = StoredServerAccount(
      account: updated,
      passwordSalt: existing.passwordSalt,
      passwordHash: existing.passwordHash,
    );
    _byEmail[cleanEmail] = record;
    _byUserId[updated.playerId] = record;
    _tokenToUserId[token] = updated.playerId;
    _saveToDisk();
    return updated;
  }

  PlayerAccount? verifyToken(String? token) {
    if (token == null || token.isEmpty) return null;
    final clean = token.replaceFirst('Bearer ', '').trim();
    final userId = _tokenToUserId[clean];
    if (userId == null) return null;
    return _byUserId[userId]?.account;
  }

  /// Syncs updated stats/displayName from an authenticated client.
  PlayerAccount? syncAccount({
    required String token,
    required PlayerAccount clientAccount,
  }) {
    final verified = verifyToken(token);
    if (verified == null) return null;
    final existing = _byUserId[verified.playerId];
    if (existing == null) return null;

    final updated = verified.copyWith(
      displayName: clientAccount.displayName,
      avatarIndex: clientAccount.avatarIndex,
      rating: clientAccount.rating,
      stats: clientAccount.stats,
    );
    final record = StoredServerAccount(
      account: updated,
      passwordSalt: existing.passwordSalt,
      passwordHash: existing.passwordHash,
    );
    if (updated.email != null) {
      _byEmail[updated.email!] = record;
    }
    _byUserId[updated.playerId] = record;
    _saveToDisk();
    return updated;
  }

  /// Returns top players sorted by rating descending for the Home Leaderboard.
  List<PublicPlayerProfile> topLeaderboard({int limit = 20}) {
    final list = [
      for (final rec in _byUserId.values) rec.account.toPublicProfile(),
    ]..sort((a, b) => b.rating.compareTo(a.rating));
    return list.length <= limit ? list : list.sublist(0, limit);
  }

  String _randomHex(int length) => List.generate(
    length,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();

  /// Deterministic multi-round salted FNV-1a/64-bit mixing hash (pure Dart,
  /// zero third-party crypto package dependency).
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
          if (tok != null) _tokenToUserId[tok] = rec.account.playerId;
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
