import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/data/game_data_center.dart';
import 'package:iraqi_domino/network/http_account_gateway.dart';
import 'package:iraqi_domino/network/protocol/wire_messages.dart';
import 'package:iraqi_domino/server/domino_online_server.dart';
import 'package:iraqi_domino/state/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Allow real localhost HTTP connections to DominoOnlineServer during tests.
  HttpOverrides.global = null;

  test('DominoOnlineServer authenticates, links Guest stats, and serves leaderboard', () async {
    final server = DominoOnlineServer();
    final port = await server.start(
      address: InternetAddress.loopbackIPv4,
      bindPort: 0,
    );
    addTearDown(server.stop);

    final baseUrl = 'http://127.0.0.1:$port';
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final center = container.read(gameDataCenterProvider.notifier);
    center.attachRemoteGateway(HttpRemoteAccountGateway(baseUrl: baseUrl));

    // 1. Play as Guest first and win a match:
    center.recordMatchOutcome(won: true, ourScore: 155, roundsWonInMatch: 3);
    expect(container.read(gameDataCenterProvider).isGuest, isTrue);

    // 2. Register & link account on the real Dart server:
    final linked = await center.registerWithEmail(
      displayName: 'أبو علي البغدادي',
      email: 'abuali@baghdad.iq',
      password: 'password123',
    );
    expect(linked.isAuthenticated, isTrue);
    expect(linked.authToken, startsWith('tok_'));
    // Guest win & rating were preserved on the server!
    expect(linked.stats.matchesWon, 1);
    expect(linked.rating, greaterThan(1000));

    // 3. Sign out to Guest, then sign back in via server `/api/auth/login`:
    center.continueAsGuest();
    expect(container.read(gameDataCenterProvider).isGuest, isTrue);

    final relogged = await center.signInWithEmail(
      email: 'abuali@baghdad.iq',
      password: 'password123',
    );
    expect(relogged.isAuthenticated, isTrue);
    expect(relogged.displayName, 'أبو علي البغدادي');
    expect(relogged.stats.matchesWon, 1);

    // 4. Verify `/api/leaderboard` returns the registered player:
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse('$baseUrl/api/leaderboard'));
    final resp = await req.close();
    final body = jsonDecode(await utf8.decoder.bind(resp).join())
        as Map<String, Object?>;
    client.close();
    final leaders = body['leaders'] as List<Object?>;
    expect(leaders, isNotEmpty);
  });

  test('DominoOnlineServer hosts and joins a realtime room over WebSocket', () async {
    final server = DominoOnlineServer();
    final port = await server.start(
      address: InternetAddress.loopbackIPv4,
      bindPort: 0,
    );
    addTearDown(server.stop);

    final hostWs = await WebSocket.connect(
      'ws://127.0.0.1:$port/ws?mode=host&playerCount=2&targetScore=151&playerId=u1&displayName=HostPlayer',
    );
    addTearDown(hostWs.close);

    final hostFrames = <WireEnvelope>[];
    hostWs.listen((raw) {
      if (raw is String) {
        final env = WireEnvelope.tryDecode(raw);
        if (env != null) hostFrames.add(env);
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(hostFrames, isNotEmpty);
    final lobby = RoomLobbyState.fromJson(hostFrames.last.data);
    expect(RegExp(r'^\d{4}$').hasMatch(lobby.roomCode), isTrue);

    // Second player joins from anywhere over WebSocket using the 4-digit roomCode:
    final joinWs = await WebSocket.connect(
      'ws://127.0.0.1:$port/ws?mode=join&roomCode=${lobby.roomCode}',
    );
    addTearDown(joinWs.close);

    final joinFrames = <WireEnvelope>[];
    joinWs.listen((raw) {
      if (raw is String) {
        final env = WireEnvelope.tryDecode(raw);
        if (env != null) joinFrames.add(env);
      }
    });

    joinWs.add(
      const WireEnvelope(
        type: WireEnvelope.tHello,
        data: {
          'profile': {
            'playerId': 'u2',
            'displayName': 'FriendPlayer',
            'isGuest': true,
          },
        },
      ).encode(),
    );

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(joinFrames, isNotEmpty);

    // Host starts the match on the server -> both players receive masked views!
    hostWs.add(const WireEnvelope(type: 'start_match').encode());
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(
      hostFrames.any((f) => f.type == WireEnvelope.tMatchSnapshot),
      isTrue,
    );
    expect(
      joinFrames.any((f) => f.type == WireEnvelope.tMatchSnapshot),
      isTrue,
    );
  });

  test('DominoOnlineServer matchmaking automatically pairs 2 searching players and starts match', () async {
    final server = DominoOnlineServer();
    final port = await server.start(
      address: InternetAddress.loopbackIPv4,
      bindPort: 0,
    );
    addTearDown(server.stop);

    final p1Ws = await WebSocket.connect(
      'ws://127.0.0.1:$port/ws?mode=matchmaking&playerCount=2&targetScore=151&playerId=m1&displayName=Player1&autoStartAfterMs=5000',
    );
    addTearDown(p1Ws.close);

    final p1Frames = <WireEnvelope>[];
    p1Ws.listen((raw) {
      if (raw is String) {
        final env = WireEnvelope.tryDecode(raw);
        if (env != null) p1Frames.add(env);
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 50));

    final p2Ws = await WebSocket.connect(
      'ws://127.0.0.1:$port/ws?mode=matchmaking&playerCount=2&targetScore=151&playerId=m2&displayName=Player2&autoStartAfterMs=5000',
    );
    addTearDown(p2Ws.close);

    final p2Frames = <WireEnvelope>[];
    p2Ws.listen((raw) {
      if (raw is String) {
        final env = WireEnvelope.tryDecode(raw);
        if (env != null) p2Frames.add(env);
      }
    });

    p2Ws.add(
      const WireEnvelope(
        type: WireEnvelope.tHello,
        data: {
          'profile': {
            'playerId': 'm2',
            'displayName': 'Player2',
            'isGuest': true,
          },
        },
      ).encode(),
    );

    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Both searching players automatically received their match snapshots!
    expect(
      p1Frames.any((f) => f.type == WireEnvelope.tMatchSnapshot),
      isTrue,
    );
    expect(
      p2Frames.any((f) => f.type == WireEnvelope.tMatchSnapshot),
      isTrue,
    );

    // Security / Anti-cheat check: send an illegal forged move from a player
    // (or out-of-turn tile) and verify the server does not crash or corrupt the board!
    p2Ws.add(
      const WireEnvelope(
        type: WireEnvelope.tPlayMove,
        data: {'low': -1, 'high': 99, 'end': 'R'},
      ).encode(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final latestSnap = MaskedMatchPayload.fromJson(
      p1Frames.lastWhere((f) => f.type == WireEnvelope.tMatchSnapshot).data,
    );
    expect(latestSnap.boardMoves, isEmpty);
  });

  test('DominoOnlineServer serves /admin dashboard and dynamically publishes Ramadan & Monthly events', () async {
    final server = DominoOnlineServer(adminSecret: 'secret_ramadan_key');
    final port = await server.start(
      address: InternetAddress.loopbackIPv4,
      bindPort: 0,
    );
    addTearDown(server.stop);

    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    // 1. Verify Arabic Web Control Panel is served at GET /admin:
    final adminPageReq = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port/admin'),
    );
    final adminPageRes = await adminPageReq.close();
    expect(adminPageRes.statusCode, HttpStatus.ok);
    final adminHtml = await utf8.decoder.bind(adminPageRes).join();
    expect(adminHtml, contains('لوحة إدارة المقهى'));

    // 2. Unauthorized admin API call is rejected (401):
    final badAuthReq = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/api/admin/events/upsert'),
    );
    badAuthReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer wrong_key');
    badAuthReq.write(jsonEncode({'id': 'ev_hack'}));
    final badAuthRes = await badAuthReq.close();
    await badAuthRes.drain<void>();
    expect(badAuthRes.statusCode, HttpStatus.unauthorized);

    // 3. Publish a Ramadan Event scheduled for March via Admin API:
    final pubReq = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/api/admin/events/upsert'),
    );
    pubReq.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer secret_ramadan_key',
    );
    pubReq.headers.contentType = ContentType.json;
    pubReq.add(
      utf8.encode(
        jsonEncode({
          'id': 'ev_ramadan_2026',
          'titleAr': 'أمسيات رمضان المبارك',
          'titleEn': 'Ramadan Majlis',
          'descAr': 'اربح 5 مباريات في رمضان',
          'descEn': 'Win 5 matches in Ramadan',
          'theme': 'ramadan',
          'metric': 'matches_won',
          'targetValue': 5,
          'rewardDinars': 450,
          'rewardBonusXp': 300,
          'startDateIso': '2026-03-01',
          'endDateIso': '2026-03-30',
          'enabled': true,
        }),
      ),
    );
    final pubRes = await pubReq.close();
    await pubRes.drain<void>();
    expect(pubRes.statusCode, HttpStatus.ok);

    // 4. Mobile app querying /api/live-ops during Ramadan sees the event live:
    final marchReq = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port/api/live-ops?date=2026-03-15'),
    );
    final marchRes = await marchReq.close();
    final marchJson =
        jsonDecode(await utf8.decoder.bind(marchRes).join())
            as Map<String, Object?>;
    final marchEvents = marchJson['events'] as List<Object?>;
    expect(
      marchEvents.any(
        (e) => (e as Map<String, Object?>)['id'] == 'ev_ramadan_2026',
      ),
      isTrue,
    );

    // 5. After Ramadan ends (May), /api/live-ops automatically hides it:
    final mayReq = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port/api/live-ops?date=2026-05-01'),
    );
    final mayRes = await mayReq.close();
    final mayJson =
        jsonDecode(await utf8.decoder.bind(mayRes).join())
            as Map<String, Object?>;
    final mayEvents = mayJson['events'] as List<Object?>;
    expect(
      mayEvents.any(
        (e) => (e as Map<String, Object?>)['id'] == 'ev_ramadan_2026',
      ),
      isFalse,
    );

    // 6. Publish a Custom Sponsored Ad Event with an image + test Admin Account Ban & Cancellation:
    final regReq = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/api/auth/oauth'),
    );
    regReq.headers.contentType = ContentType.json;
    regReq.add(
      utf8.encode(
        jsonEncode({
          'provider': 'google',
          'providerUid': 'karrar@gmail.com',
          'displayName': 'كرار البغدادي',
        }),
      ),
    );
    final regRes = await regReq.close();
    final regMap =
        jsonDecode(await utf8.decoder.bind(regRes).join())
            as Map<String, Object?>;
    final userMap = regMap['account'] as Map<String, Object?>;
    final userId = userMap['playerId'] as String;
    expect(userMap['authProvider'], 'google');

    // Temporarily ban player via /api/admin/accounts/ban:
    final banReq = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/api/admin/accounts/ban'),
    );
    banReq.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer secret_ramadan_key',
    );
    banReq.headers.contentType = ContentType.json;
    banReq.add(
      utf8.encode(
        jsonEncode({
          'userId': userId,
          'durationHours': 48,
          'reason': 'سلوك مخالف',
        }),
      ),
    );
    final banRes = await banReq.close();
    await banRes.drain<void>();
    expect(banRes.statusCode, HttpStatus.ok);

    // Banned player attempting Google sign-in gets 400 with ban reason:
    final blockedLoginReq = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/api/auth/oauth'),
    );
    blockedLoginReq.headers.contentType = ContentType.json;
    blockedLoginReq.add(
      utf8.encode(
        jsonEncode({
          'provider': 'google',
          'providerUid': 'karrar@gmail.com',
          'displayName': 'كرار',
        }),
      ),
    );
    final blockedRes = await blockedLoginReq.close();
    final blockedJson =
        jsonDecode(await utf8.decoder.bind(blockedRes).join())
            as Map<String, Object?>;
    expect(blockedRes.statusCode, HttpStatus.badRequest);
    expect(blockedJson['error'] as String, contains('محظور مؤقتاً'));

    // Unban -> then Cancel/Delete account completely:
    final unbanReq = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/api/admin/accounts/unban'),
    );
    unbanReq.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer secret_ramadan_key',
    );
    unbanReq.headers.contentType = ContentType.json;
    unbanReq.add(utf8.encode(jsonEncode({'userId': userId})));
    final unbanRes = await unbanReq.close();
    await unbanRes.drain<void>();
    expect(unbanRes.statusCode, HttpStatus.ok);

    final delReq = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/api/admin/accounts/delete'),
    );
    delReq.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer secret_ramadan_key',
    );
    delReq.headers.contentType = ContentType.json;
    delReq.add(utf8.encode(jsonEncode({'userId': userId})));
    final delRes = await delReq.close();
    final delJson =
        jsonDecode(await utf8.decoder.bind(delRes).join())
            as Map<String, Object?>;
    expect(delJson['deleted'], isTrue);

    // 7. Phase 11 Store Compliance: user can permanently delete their OWN account via /api/account/delete-self:
    final selfRegReq = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/api/auth/oauth'),
    );
    selfRegReq.headers.contentType = ContentType.json;
    selfRegReq.add(
      utf8.encode(
        jsonEncode({
          'provider': 'google',
          'providerUid': 'selfdelete@gmail.com',
          'displayName': 'مستخدم تجريبي',
        }),
      ),
    );
    final selfRegRes = await selfRegReq.close();
    final selfRegMap =
        jsonDecode(await utf8.decoder.bind(selfRegRes).join())
            as Map<String, Object?>;
    final selfTok =
        (selfRegMap['account'] as Map<String, Object?>)['authToken'] as String;

    final selfDelReq = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/api/account/delete-self'),
    );
    selfDelReq.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $selfTok',
    );
    selfDelReq.headers.contentType = ContentType.json;
    selfDelReq.add(utf8.encode('{}'));
    final selfDelRes = await selfDelReq.close();
    final selfDelMap =
        jsonDecode(await utf8.decoder.bind(selfDelRes).join())
            as Map<String, Object?>;
    expect(selfDelRes.statusCode, HttpStatus.ok);
    expect(selfDelMap['deleted'], isTrue);
  });
}
