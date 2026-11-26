import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/sound_service.dart';
import '../data/game_data_center.dart';
import '../engine/board.dart';
import '../engine/domino_piece.dart';
import '../engine/game_rules_config.dart';
import '../engine/round_result.dart';
import '../network/protocol/connection_channel.dart';
import '../network/protocol/wire_messages.dart';
import '../network/session/authoritative_room_host.dart';
import '../network/session/room_client_session.dart';
import '../network/transport/online_ws_transport.dart';
import '../network/transport/peer_transport.dart';
import '../network/transport/transport_factory.dart';
import 'match_controller.dart';

/// Immutable UI state of an active Local (Wi-Fi / Offline Wi-Fi / Bluetooth)
/// or future Phase 7 Online multiplayer room.
class MultiplayerSessionState {
  const MultiplayerSessionState({
    this.channel = SessionChannel.localWifi,
    this.isHost = false,
    this.connecting = false,
    this.scanning = false,
    this.discoveredRooms = const [],
    this.lobby,
    this.matchView,
    this.endpointLabel,
    this.errorMessage,
    this.roomClosed = false,
  });

  final SessionChannel channel;
  final bool isHost;
  final bool connecting;
  final bool scanning;
  final List<DiscoveredRoom> discoveredRooms;
  final RoomLobbyState? lobby;
  final MatchViewState? matchView;
  final String? endpointLabel;
  final String? errorMessage;
  final bool roomClosed;

  bool get inLobby => lobby != null && matchView == null && !roomClosed;
  bool get inMatch => matchView != null && !roomClosed;

  MultiplayerSessionState copyWith({
    SessionChannel? channel,
    bool? isHost,
    bool? connecting,
    bool? scanning,
    List<DiscoveredRoom>? discoveredRooms,
    RoomLobbyState? lobby,
    bool clearLobby = false,
    MatchViewState? matchView,
    bool clearMatchView = false,
    String? endpointLabel,
    String? errorMessage,
    bool clearError = false,
    bool? roomClosed,
  }) {
    return MultiplayerSessionState(
      channel: channel ?? this.channel,
      isHost: isHost ?? this.isHost,
      connecting: connecting ?? this.connecting,
      scanning: scanning ?? this.scanning,
      discoveredRooms: discoveredRooms ?? this.discoveredRooms,
      lobby: clearLobby ? null : (lobby ?? this.lobby),
      matchView: clearMatchView ? null : (matchView ?? this.matchView),
      endpointLabel: endpointLabel ?? this.endpointLabel,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      roomClosed: roomClosed ?? this.roomClosed,
    );
  }
}

/// Riverpod controller bridging the unified [GameDataCenter], the 3 Local
/// Multiplayer transports (plus future Online transport), [RoomLobbyScreen],
/// and [GameScreen].
class MultiplayerSessionController extends Notifier<MultiplayerSessionState> {
  AuthoritativeRoomHost? _host;
  RoomClientSession? _client;
  PeerClientTransport? _scanner;

  StreamSubscription<List<DiscoveredRoom>>? _scanSub;
  final List<StreamSubscription<Object?>> _sessionSubs = [];
  int _recordedMatchCount = 0;

  @override
  MultiplayerSessionState build() {
    ref.onDispose(_disposeAllSync);
    return const MultiplayerSessionState();
  }

  /// Switches the selected Local Multiplayer channel (`wifiOffline`,
  /// `bluetooth`, or `localWifi`) and restarts room scanning if active.
  Future<void> selectChannel(SessionChannel channel) async {
    if (state.channel == channel && state.scanning) return;
    await stopScanning();
    state = state.copyWith(
      channel: channel,
      discoveredRooms: const [],
      clearError: true,
    );
    await startScanning();
  }

  /// Starts scanning for nearby or online open tables on the current channel.
  Future<void> startScanning({
    PeerClientTransport? customScanner,
    int playerCount = 4,
  }) async {
    await stopScanning();
    final PeerClientTransport transport;
    if (customScanner != null) {
      transport = customScanner;
    } else if (state.channel == SessionChannel.onlineRoom) {
      final profile = ref.read(gameDataCenterProvider.notifier).publicProfile;
      transport = OnlineWebSocketClientTransport(
        playerProfile: profile,
        playerCount: playerCount,
      );
    } else {
      transport = TransportFactory.createClient(state.channel);
    }
    _scanner = transport;
    state = state.copyWith(
      scanning: true,
      discoveredRooms: const [],
      clearError: true,
    );

    _scanSub = transport.discoveredRooms.listen((rooms) {
      state = state.copyWith(discoveredRooms: rooms);
    });

    try {
      await transport.startDiscovery();
    } catch (e) {
      state = state.copyWith(
        scanning: false,
        errorMessage: _cleanError(e),
      );
    }
  }

  Future<void> stopScanning() async {
    await _scanSub?.cancel();
    _scanSub = null;
    final sc = _scanner;
    _scanner = null;
    if (sc != null) {
      try {
        await sc.disconnect();
      } catch (_) {}
    }
    if (state.scanning) {
      state = state.copyWith(scanning: false);
    }
  }

  /// Creates and advertises a new room as Host using the player's public
  /// identity from [GameDataCenter].
  Future<bool> hostRoom({
    required SessionChannel channel,
    required int playerCount,
    required GameRulesConfig rules,
    PeerHostTransport? customTransport,
  }) async {
    await leaveSession();
    state = state.copyWith(
      channel: channel,
      isHost: true,
      connecting: true,
      clearError: true,
      roomClosed: false,
    );

    try {
      final profile = ref.read(gameDataCenterProvider.notifier).publicProfile;
      final transport =
          customTransport ?? TransportFactory.createHost(channel);
      final host = AuthoritativeRoomHost(
        transport: transport,
        hostProfile: profile,
        playerCount: playerCount,
        rules: rules,
      );
      _host = host;
      _recordedMatchCount = 0;

      _sessionSubs.add(
        host.lobbyStream.listen((lobby) {
          state = state.copyWith(
            lobby: lobby,
            endpointLabel: transport.endpointLabel,
          );
        }),
      );
      _sessionSubs.add(
        host.hostMatchStream.listen(_onMatchPayload),
      );

      final initialLobby = await host.startRoom();
      state = state.copyWith(
        connecting: false,
        lobby: initialLobby,
        endpointLabel: transport.endpointLabel,
      );
      return true;
    } catch (e) {
      await leaveSession();
      state = state.copyWith(
        connecting: false,
        errorMessage: _cleanError(e),
      );
      return false;
    }
  }

  /// Creates a new online room on [DominoOnlineServer] via WebSocket and acts
  /// as the room's Host in [RoomLobbyScreen].
  Future<bool> hostOnlineRoom({
    required int playerCount,
    required GameRulesConfig rules,
  }) async {
    await leaveSession();
    state = state.copyWith(
      channel: SessionChannel.onlineRoom,
      isHost: true,
      connecting: true,
      clearError: true,
      roomClosed: false,
    );

    try {
      final profile = ref.read(gameDataCenterProvider.notifier).publicProfile;
      final transport = OnlineWebSocketClientTransport(
        playerProfile: profile,
        playerCount: playerCount,
        isHostingRoom: true,
        hostRules: rules,
      );
      final client = RoomClientSession(
        transport: transport,
        playerProfile: profile,
      );
      _client = client;
      _recordedMatchCount = 0;

      _sessionSubs.add(
        client.lobbyStream.listen((lobby) {
          state = state.copyWith(
            connecting: false,
            lobby: lobby,
            endpointLabel: OnlineServerManager.baseUrl,
          );
        }),
      );
      _sessionSubs.add(client.matchStream.listen(_onMatchPayload));
      _sessionSubs.add(
        client.errorStream.listen((msg) {
          state = state.copyWith(errorMessage: msg);
        }),
      );
      _sessionSubs.add(
        client.closedStream.listen((_) {
          state = state.copyWith(roomClosed: true);
        }),
      );

      await client.connectAndJoin();
      state = state.copyWith(connecting: false);
      return true;
    } catch (e) {
      await leaveSession();
      state = state.copyWith(
        connecting: false,
        errorMessage: _cleanError(e),
      );
      return false;
    }
  }

  /// Joins an existing online room on [DominoOnlineServer] by 4-digit room
  /// number or discovered room card.
  Future<bool> joinOnlineRoom({
    required int playerCount,
    DiscoveredRoom? room,
    String? roomCode,
  }) async {
    final profile = ref.read(gameDataCenterProvider.notifier).publicProfile;
    final transport = OnlineWebSocketClientTransport(
      playerProfile: profile,
      playerCount: playerCount,
    );
    return joinRoom(
      channel: SessionChannel.onlineRoom,
      room: room,
      codeOrEndpoint: roomCode,
      customTransport: transport,
    );
  }

  /// Enters the server's Random Online Matchmaking queue (`mode=matchmaking`).
  /// Automatically pairs with searching humans (or hot-joins an open seat in an
  /// early/mid match), and fills remaining seats with [AiPersona] bots if needed.
  Future<bool> startOnlineMatchmaking({
    required int playerCount,
    required GameRulesConfig rules,
  }) async {
    await leaveSession();
    state = state.copyWith(
      channel: SessionChannel.onlineRandom,
      isHost: false,
      connecting: true,
      clearError: true,
      roomClosed: false,
    );

    try {
      final profile = ref.read(gameDataCenterProvider.notifier).publicProfile;
      final transport = OnlineWebSocketClientTransport(
        playerProfile: profile,
        playerCount: playerCount,
        isMatchmaking: true,
        hostRules: rules,
        channel: SessionChannel.onlineRandom,
      );
      final client = RoomClientSession(
        transport: transport,
        playerProfile: profile,
      );
      _client = client;
      _recordedMatchCount = 0;

      _sessionSubs.add(
        client.lobbyStream.listen((lobby) {
          state = state.copyWith(
            lobby: lobby,
            endpointLabel: OnlineServerManager.baseUrl,
          );
        }),
      );
      _sessionSubs.add(
        client.matchStream.listen((payload) {
          state = state.copyWith(connecting: false);
          _onMatchPayload(payload);
        }),
      );
      _sessionSubs.add(
        client.errorStream.listen((msg) {
          state = state.copyWith(connecting: false, errorMessage: msg);
        }),
      );
      _sessionSubs.add(
        client.closedStream.listen((_) {
          state = state.copyWith(connecting: false, roomClosed: true);
        }),
      );

      await client.connectAndJoin();
      return true;
    } catch (e) {
      await leaveSession();
      state = state.copyWith(
        connecting: false,
        errorMessage: _cleanError(e),
      );
      return false;
    }
  }

  /// Joins a discovered room or manual quick-connect code as a Client using
  /// the player's unified identity from [GameDataCenter].
  Future<bool> joinRoom({
    required SessionChannel channel,
    DiscoveredRoom? room,
    String? codeOrEndpoint,
    PeerClientTransport? customTransport,
  }) async {
    await leaveSession();
    state = state.copyWith(
      channel: channel,
      isHost: false,
      connecting: true,
      clearError: true,
      roomClosed: false,
    );

    try {
      final profile = ref.read(gameDataCenterProvider.notifier).publicProfile;
      final transport =
          customTransport ?? TransportFactory.createClient(channel);
      final client = RoomClientSession(
        transport: transport,
        playerProfile: profile,
      );
      _client = client;
      _recordedMatchCount = 0;

      _sessionSubs.add(
        client.lobbyStream.listen((lobby) {
          state = state.copyWith(connecting: false, lobby: lobby);
        }),
      );
      _sessionSubs.add(
        client.matchStream.listen(_onMatchPayload),
      );
      _sessionSubs.add(
        client.errorStream.listen((msg) {
          state = state.copyWith(errorMessage: msg);
        }),
      );
      _sessionSubs.add(
        client.closedStream.listen((_) {
          state = state.copyWith(roomClosed: true);
        }),
      );

      await client.connectAndJoin(
        room: room,
        codeOrEndpoint: codeOrEndpoint,
      );
      state = state.copyWith(connecting: false);
      return true;
    } catch (e) {
      await leaveSession();
      state = state.copyWith(
        connecting: false,
        errorMessage: _cleanError(e),
      );
      return false;
    }
  }

  void _onMatchPayload(MaskedMatchPayload payload) {
    final sound = ref.read(soundServiceProvider);
    switch (payload.soundEvent) {
      case 'place':
        sound.playTilePlace();
      case 'draw':
        sound.playTileDraw();
      case 'pass':
        sound.playPass();
    }

    final view = payload.toMatchViewState();

    // Record finished match outcome into the unified GameDataCenter once per match!
    if (view.isMatchOver && view.showResultPending) {
      final completedId = view.history.length;
      if (completedId > _recordedMatchCount) {
        _recordedMatchCount = completedId;
        final won = view.matchWinnerTeam == 0;
        var roundsWon = 0;
        var roundsLost = 0;
        var dominoWins = 0;
        var blockedWins = 0;
        var highestRound = 0;
        for (final rec in view.history) {
          final r = rec.result;
          if (r.winnerTeam == 0) {
            roundsWon++;
            if (r.kind == RoundEndKind.domino) dominoWins++;
            if (r.kind == RoundEndKind.blocked) blockedWins++;
            if (r.points > highestRound) highestRound = r.points;
          } else if (r.winnerTeam == 1) {
            roundsLost++;
          }
        }
        final isOnlineChannel =
            state.channel == SessionChannel.onlineRoom ||
            state.channel == SessionChannel.onlineRandom;
        ref.read(gameDataCenterProvider.notifier).recordMatchOutcome(
              won: won,
              ourScore: view.scores[0],
              opponentScore: view.scores[1],
              roundsWonInMatch: roundsWon,
              roundsLostInMatch: roundsLost,
              dominoWinsInMatch: dominoWins,
              blockedWinsInMatch: blockedWins,
              highestRoundPoints: highestRound,
              isOnlineMatch: isOnlineChannel,
            );
      }
    } else if (!view.isMatchOver && view.history.isEmpty) {
      _recordedMatchCount = 0;
    }

    state = state.copyWith(matchView: view);
  }

  // ---------------------------------------------------------------------------
  // Lobby & Match Actions (identical API for Host & Client!)
  // ---------------------------------------------------------------------------

  void pickSeat(int canonicalSeat) {
    if (_host != null) {
      _host!.hostPickSeat(canonicalSeat);
    } else {
      _client?.pickSeat(canonicalSeat);
    }
  }

  void toggleReady() {
    _client?.toggleReady();
  }

  void startMatchFromHost() {
    if (_host != null) {
      _host!.startMatch();
    } else if (state.isHost) {
      _client?.requestStartMatch();
    }
  }

  void playHumanMove(DominoPiece piece, BoardEnd end) {
    if (_host != null) {
      _host!.hostPlayMove(piece, end);
    } else {
      _client?.playMove(piece, end);
    }
  }

  void drawHumanTile(int slotIndex) {
    if (_host != null) {
      _host!.hostDrawSlot(slotIndex);
    } else {
      _client?.drawSlot(slotIndex);
    }
  }

  void resetMatch() {
    if (_host != null) {
      _host!.hostResetMatch();
    } else {
      _client?.requestResetMatch();
    }
  }

  Future<void> leaveSession() async {
    await stopScanning();
    for (final s in _sessionSubs) {
      await s.cancel();
    }
    _sessionSubs.clear();

    final h = _host;
    _host = null;
    if (h != null) await h.dispose();

    final c = _client;
    _client = null;
    if (c != null) await c.dispose();

    state = MultiplayerSessionState(channel: state.channel);
  }

  void _disposeAllSync() {
    _scanSub?.cancel();
    _scanner?.disconnect();
    for (final s in _sessionSubs) {
      s.cancel();
    }
    _sessionSubs.clear();
    _host?.dispose();
    _client?.dispose();
  }

  String _cleanError(Object e) {
    final s = e.toString();
    return s
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }
}

final multiplayerSessionProvider =
    NotifierProvider<MultiplayerSessionController, MultiplayerSessionState>(
      MultiplayerSessionController.new,
    );
