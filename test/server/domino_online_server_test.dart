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
}
