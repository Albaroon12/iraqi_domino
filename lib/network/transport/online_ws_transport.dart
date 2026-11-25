import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../ai/ai_difficulty.dart';
import '../../data/player_account.dart';
import '../../engine/game_rules_config.dart';
import '../../server/domino_online_server.dart';
import '../protocol/connection_channel.dart';
import 'peer_transport.dart';

/// Manages the online server endpoint URL and automatically boots an embedded
/// local [DominoOnlineServer] when pointing at localhost if no external server
/// process is running yet (so testing on a phone/emulator works out of the box).
class OnlineServerManager {
  OnlineServerManager._();

  static String _baseUrl = 'http://127.0.0.1:8080';
  static DominoOnlineServer? _embeddedServer;

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return;
    _baseUrl = clean.endsWith('/')
        ? clean.substring(0, clean.length - 1)
        : clean;
  }

  static String get wsBaseUrl {
    if (_baseUrl.startsWith('https://')) {
      return 'wss://${_baseUrl.substring('https://'.length)}';
    }
    if (_baseUrl.startsWith('http://')) {
      return 'ws://${_baseUrl.substring('http://'.length)}';
    }
    return 'ws://$_baseUrl';
  }

  /// Ensures the target server is reachable; if pointing to `127.0.0.1` or
  /// `localhost` and nothing is listening yet, starts an embedded
  /// [DominoOnlineServer] automatically.
  static Future<void> ensureServerReady() async {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null) return;
    final isLocal = uri.host == '127.0.0.1' || uri.host == 'localhost';
    if (!isLocal) return;

    // Quick TCP probe to check if an external `dart run bin/server.dart` is live:
    final targetPort = uri.hasPort ? uri.port : 8080;
    try {
      final probe = await Socket.connect(
        '127.0.0.1',
        targetPort,
        timeout: const Duration(milliseconds: 250),
      );
      probe.destroy();
      return;
    } catch (_) {}

    if (_embeddedServer != null && _embeddedServer!.port > 0) {
      _baseUrl = 'http://127.0.0.1:${_embeddedServer!.port}';
      return;
    }

    final srv = DominoOnlineServer();
    try {
      final bound = await srv.start(bindPort: targetPort);
      _embeddedServer = srv;
      _baseUrl = 'http://127.0.0.1:$bound';
    } catch (_) {
      final bound = await srv.start(bindPort: 0);
      _embeddedServer = srv;
      _baseUrl = 'http://127.0.0.1:$bound';
    }
  }
}

/// WebSocket transport implementing [PeerClientTransport] against
/// [DominoOnlineServer] for both:
/// - Creating an online room on the server (`isHostingRoom: true`)
/// - Joining an online room by 4-digit room number or from the server's open list
class OnlineWebSocketClientTransport implements PeerClientTransport {
  OnlineWebSocketClientTransport({
    required this.playerProfile,
    required this.playerCount,
    this.isHostingRoom = false,
    this.isMatchmaking = false,
    this.hostRules = const GameRulesConfig(
      targetScore: 151,
      aiDifficulty: AiDifficulty.medium,
    ),
    this.channel = SessionChannel.onlineRoom,
  });

  final PublicPlayerProfile playerProfile;
  final int playerCount;
  final bool isHostingRoom;
  final bool isMatchmaking;
  final GameRulesConfig hostRules;

  @override
  final SessionChannel channel;

  WebSocket? _ws;
  Timer? _pollTimer;

  final _rooms = StreamController<List<DiscoveredRoom>>.broadcast();
  final _frames = StreamController<String>.broadcast();
  final _disconnected = StreamController<void>.broadcast();

  @override
  Stream<List<DiscoveredRoom>> get discoveredRooms => _rooms.stream;

  @override
  Stream<String> get frames => _frames.stream;

  @override
  Stream<void> get disconnected => _disconnected.stream;

  @override
  Future<void> startDiscovery() async {
    await stopDiscovery();
    await OnlineServerManager.ensureServerReady();
    await _fetchServerRooms();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _fetchServerRooms(),
    );
  }

  Future<void> _fetchServerRooms() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    try {
      final uri = Uri.parse(
        '${OnlineServerManager.baseUrl}/api/rooms?playerCount=$playerCount',
      );
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) return;
      final text = await utf8.decoder.bind(resp).join();
      final map = jsonDecode(text);
      if (map is! Map<String, Object?>) return;
      final list = map['rooms'] as List<Object?>? ?? const [];
      final parsed = <DiscoveredRoom>[
        for (final item in list)
          if (item is Map<String, Object?>) DiscoveredRoom.fromJson(item),
      ];
      if (!_rooms.isClosed) _rooms.add(parsed);
    } catch (_) {
      // Ignore transient polling failures.
    } finally {
      client.close();
    }
  }

  @override
  Future<void> stopDiscovery() async {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  Future<void> connect({DiscoveredRoom? room, String? codeOrEndpoint}) async {
    await stopDiscovery();
    await OnlineServerManager.ensureServerReady();

    final Uri wsUri;
    if (isMatchmaking) {
      wsUri = Uri.parse('${OnlineServerManager.wsBaseUrl}/ws').replace(
        queryParameters: {
          'mode': 'matchmaking',
          'playerCount': '$playerCount',
          'targetScore': '${hostRules.targetScore}',
          'aiDifficulty': hostRules.aiDifficulty.id,
          'playerId': playerProfile.playerId,
          'displayName': playerProfile.displayName,
          'isGuest': '${playerProfile.isGuest}',
        },
      );
    } else if (isHostingRoom) {
      wsUri = Uri.parse('${OnlineServerManager.wsBaseUrl}/ws').replace(
        queryParameters: {
          'mode': 'host',
          'playerCount': '$playerCount',
          'targetScore': '${hostRules.targetScore}',
          'aiDifficulty': hostRules.aiDifficulty.id,
          'playerId': playerProfile.playerId,
          'displayName': playerProfile.displayName,
          'isGuest': '${playerProfile.isGuest}',
        },
      );
    } else {
      final code = (room?.roomCode ?? codeOrEndpoint ?? '').trim();
      if (code.isEmpty) {
        throw ArgumentError('يرجى إدخال رقم الغرفة للانضمام عبر السيرفر');
      }
      wsUri = Uri.parse('${OnlineServerManager.wsBaseUrl}/ws').replace(
        queryParameters: {
          'mode': 'join',
          'roomCode': code,
        },
      );
    }

    final ws = await WebSocket.connect(wsUri.toString()).timeout(
      const Duration(seconds: 6),
    );
    ws.pingInterval = const Duration(seconds: 15);
    _ws = ws;

    ws.listen(
      (data) {
        if (data is String && data.isNotEmpty && !_frames.isClosed) {
          _frames.add(data);
        }
      },
      onDone: _onSocketClosed,
      onError: (_) => _onSocketClosed(),
      cancelOnError: true,
    );
  }

  void _onSocketClosed() {
    _ws?.close();
    _ws = null;
    if (!_disconnected.isClosed) _disconnected.add(null);
  }

  @override
  Future<void> send(String payload) async {
    final ws = _ws;
    if (ws == null) return;
    ws.add(payload);
  }

  @override
  Future<void> disconnect() async {
    await stopDiscovery();
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
    if (!_disconnected.isClosed) _disconnected.add(null);
  }
}
