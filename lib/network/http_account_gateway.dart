import 'dart:convert';
import 'dart:io';

import '../data/game_data_center.dart';
import '../data/player_account.dart';

/// HTTP client implementation of [RemoteAccountGateway] connecting the mobile
/// app's unified [GameDataCenter] to [DominoOnlineServer].
class HttpRemoteAccountGateway implements RemoteAccountGateway {
  HttpRemoteAccountGateway({
    this.baseUrl = 'http://127.0.0.1:8080',
    this.timeout = const Duration(seconds: 5),
  });

  final String baseUrl;
  final Duration timeout;

  @override
  Future<PlayerAccount> authenticate({
    required AuthProviderKind provider,
    required String credentialToken,
    required PlayerAccount currentLocalAccount,
  }) async {
    final isRegister = credentialToken.startsWith('register:');
    final Uri uri;
    final Map<String, Object?> payload;

    if (provider == AuthProviderKind.google) {
      final colonIdx = credentialToken.indexOf(':');
      final providerUid = colonIdx > 0
          ? credentialToken.substring(0, colonIdx)
          : credentialToken;
      final displayName = colonIdx > 0
          ? credentialToken.substring(colonIdx + 1)
          : currentLocalAccount.displayName;
      uri = Uri.parse('$baseUrl/api/auth/oauth');
      payload = {
        'provider': provider.id,
        'providerUid': providerUid,
        'displayName': displayName,
        'guestAccount': currentLocalAccount.toJson(),
      };
    } else if (isRegister) {
      final parts = credentialToken.split(':');
      final name = parts.length > 1 ? parts[1] : currentLocalAccount.displayName;
      final email = parts.length > 2 ? parts[2] : '';
      final password = parts.length > 3 ? parts.sublist(3).join(':') : '';
      uri = Uri.parse('$baseUrl/api/auth/register');
      payload = {
        'displayName': name,
        'email': email,
        'password': password,
        'guestAccount': currentLocalAccount.toJson(),
      };
    } else {
      final colonIdx = credentialToken.indexOf(':');
      final email = colonIdx > 0
          ? credentialToken.substring(0, colonIdx)
          : credentialToken;
      final password = colonIdx > 0
          ? credentialToken.substring(colonIdx + 1)
          : '';
      uri = Uri.parse('$baseUrl/api/auth/login');
      payload = {
        'email': email,
        'password': password,
        'guestAccount': currentLocalAccount.toJson(),
      };
    }

    final res = await _postJson(uri, payload);
    final accMap = res['account'];
    if (accMap is Map<String, Object?>) {
      final decoded = PlayerAccount.tryDecode(jsonEncode(accMap));
      if (decoded != null) return decoded;
    }
    throw StateError((res['error'] as String?) ?? 'فشل توثيق الحساب مع السيرفر');
  }

  @override
  Future<void> syncAccount(PlayerAccount account) async {
    final token = account.authToken;
    if (token == null || token.isEmpty) return;
    final uri = Uri.parse('$baseUrl/api/profile/sync');
    await _postJson(
      uri,
      {'account': account.toJson()},
      authToken: token,
    );
  }

  @override
  Future<void> deleteOwnAccount(String authToken) async {
    if (authToken.isEmpty) return;
    final uri = Uri.parse('$baseUrl/api/account/delete-self');
    await _postJson(uri, const {}, authToken: authToken);
  }

  Future<Map<String, Object?>> _postJson(
    Uri uri,
    Map<String, Object?> body, {
    String? authToken,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.postUrl(uri).timeout(timeout);
      req.headers.contentType = ContentType.json;
      if (authToken != null && authToken.isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
      }
      req.add(utf8.encode(jsonEncode(body)));
      final resp = await req.close().timeout(timeout);
      final text = await utf8.decoder.bind(resp).join().timeout(timeout);
      final map = text.isEmpty ? const <String, Object?>{} : jsonDecode(text);
      if (resp.statusCode >= 400) {
        final err = map is Map<String, Object?> ? map['error'] : null;
        throw StateError((err as String?) ?? 'خطأ من السيرفر (${resp.statusCode})');
      }
      return map is Map<String, Object?> ? map : const {};
    } finally {
      client.close();
    }
  }
}
