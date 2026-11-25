import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/data/player_account.dart';
import 'package:iraqi_domino/engine/domino_piece.dart';
import 'package:iraqi_domino/engine/game_rules_config.dart';
import 'package:iraqi_domino/network/protocol/connection_channel.dart';
import 'package:iraqi_domino/network/protocol/seat_mapper.dart';
import 'package:iraqi_domino/network/session/authoritative_room_host.dart';
import 'package:iraqi_domino/network/session/room_client_session.dart';
import 'package:iraqi_domino/network/transport/lan_socket_transport.dart';
import 'package:iraqi_domino/network/transport/peer_transport.dart';

Future<void> _pumpMicrotasks([int cycles = 6]) async {
  for (var i = 0; i < cycles; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('QuickConnectCodec round-trips IPv4 and port cleanly', () {
    final code = QuickConnectCodec.encode('192.168.43.1', 49152);
    expect(code, contains('-'));
    final decoded = QuickConnectCodec.tryDecode(code);
    expect(decoded, isNotNull);
    expect(decoded!.host, '192.168.43.1');
    expect(decoded.port, 49152);
  });

  test('SeatMapper rotates 4-player seats and team scores accurately', () {
    // Canonical seat 1 (Team 1) views themselves at local seat 0:
    // canonical 1 -> local 0 (me)
    // canonical 2 -> local 1 (right opponent)
    // canonical 3 -> local 2 (partner, top!)
    // canonical 0 -> local 3 (left opponent)
    expect(
      SeatMapper.toLocalSeat(
        canonicalSeat: 3,
        viewerCanonicalSeat: 1,
        playerCount: 4,
      ),
      2,
    );
    expect(
      SeatMapper.rotateTeamScores(
        [45, 90],
        viewerCanonicalSeat: 1,
        playerCount: 4,
      ),
      [90, 45],
    );
  });

  for (final channel in SessionChannel.localChannels) {
    test(
      'Full 4-player lobby, seat switch, anti-cheat masking, bot takeover & reconnect ($channel)',
      () async {
        final bus = InMemoryTransportBus();
        addTearDown(bus.dispose);

        const hostProfile = PublicPlayerProfile(
          playerId: 'usr_host',
          displayName: 'المضيف أحمد',
          isGuest: false,
        );
        const friendProfile = PublicPlayerProfile(
          playerId: 'guest_friend',
          displayName: 'الصديق زيد',
          isGuest: true,
        );

        final host = AuthoritativeRoomHost(
          transport: bus.createHost(channel: channel, roomCode: '7788'),
          hostProfile: hostProfile,
          playerCount: 4,
          rules: const GameRulesConfig(targetScore: 151),
          random: Random(42),
          aiDelay: const Duration(milliseconds: 20),
          passDelay: const Duration(milliseconds: 20),
        );
        addTearDown(host.dispose);

        await host.startRoom();

        final client = RoomClientSession(
          transport: bus.createClient(channel: channel),
          playerProfile: friendProfile,
        );

        await client.connectAndJoin(codeOrEndpoint: '7788');
        await _pumpMicrotasks();

        // Friend initially sits at canonical seat 1; switches to seat 2 to
        // become Host's partner!
        expect(client.currentLobby, isNotNull);
        expect(client.currentLobby!.seatOfPlayer('guest_friend'), 1);

        await client.pickSeat(2);
        await _pumpMicrotasks();
        expect(host.currentLobby!.seatOfPlayer('guest_friend'), 2);

        // Start match: seats 0 & 2 are humans, seats 1 & 3 are AI bots.
        host.startMatch();
        await _pumpMicrotasks();

        final hostSnap = host.currentHostPayload!;
        final friendSnap = client.currentMatch!;

        // Each player sees themselves at local seat 0 and their partner at seat 2!
        expect(hostSnap.seats[0].playerId, 'usr_host');
        expect(hostSnap.seats[2].playerId, 'guest_friend');
        expect(friendSnap.seats[0].playerId, 'guest_friend');
        expect(friendSnap.seats[2].playerId, 'usr_host');

        // Anti-cheat check: Friend's wire view has their real 7 tiles, while
        // other seats in `toMatchViewState()` only contain masked placeholders!
        expect(friendSnap.myHand.length, 7);
        expect(friendSnap.revealedHands, isNull);
        final friendView = friendSnap.toMatchViewState();
        expect(
          friendView.hands[2].every((p) => p == const DominoPiece(0, 0)),
          isTrue,
        );

        // Simulate friend disconnecting mid-match -> AI bot takes over seat 2!
        await client.dispose();
        await _pumpMicrotasks();
        expect(host.currentHostPayload!.seats[2].isBot, isTrue);
        expect(host.currentHostPayload!.seats[2].openForHumanJoin, isTrue);

        // Friend reconnects with the SAME playerId -> immediately reclaims seat 2!
        final reconnected = RoomClientSession(
          transport: bus.createClient(channel: channel),
          playerProfile: friendProfile,
        );
        addTearDown(reconnected.dispose);

        await reconnected.connectAndJoin(codeOrEndpoint: '7788');
        await _pumpMicrotasks();
        expect(host.currentHostPayload!.seats[2].isHuman, isTrue);
        expect(host.currentHostPayload!.seats[2].playerId, 'guest_friend');
        expect(reconnected.currentMatch, isNotNull);
      },
    );
  }

  test('Real TCP loopback socket syncs Host and Client over LanSocketTransport', () async {
    final hostTransport = LanSocketHostTransport(
      channel: SessionChannel.wifiOffline,
      enableUdpBeacon: false,
    );
    final clientTransport = LanSocketClientTransport(
      channel: SessionChannel.wifiOffline,
    );

    const hostProfile = PublicPlayerProfile(
      playerId: 'host_tcp',
      displayName: 'مضيف محلي',
      isGuest: true,
    );
    const joinerProfile = PublicPlayerProfile(
      playerId: 'joiner_tcp',
      displayName: 'منضم محلي',
      isGuest: true,
    );

    final host = AuthoritativeRoomHost(
      transport: hostTransport,
      hostProfile: hostProfile,
      playerCount: 2,
      rules: const GameRulesConfig(targetScore: 151),
      random: Random(7),
    );
    addTearDown(host.dispose);

    await host.startRoom();
    expect(RegExp(r'^\d{4}$').hasMatch(host.currentLobby!.roomCode), isTrue);

    // Connect over real OS loopback TCP port!
    final port = hostTransport.endpointLabel.split(':').last;
    final client = RoomClientSession(
      transport: clientTransport,
      playerProfile: joinerProfile,
    );
    addTearDown(client.dispose);

    await client.connectAndJoin(codeOrEndpoint: '127.0.0.1:$port');
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(client.currentLobby, isNotNull);
    expect(client.currentLobby!.humanCount, 2);

    host.startMatch();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(client.currentMatch, isNotNull);
    // 2-player boneyard masking: client knows 14 slots are present, zero pip leaks!
    expect(client.currentMatch!.boneyardCount, 14);
    expect(client.currentMatch!.boneyardSlotPresent.where((b) => b).length, 14);
  });
}
