import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data' show BytesBuilder;

import '../ai/ai_difficulty.dart';
import '../data/cafe_events_and_tournaments.dart';
import '../data/player_account.dart';
import '../engine/game_rules_config.dart';
import '../network/protocol/connection_channel.dart';
import '../network/protocol/wire_messages.dart';
import '../network/session/authoritative_room_host.dart';
import '../network/transport/peer_transport.dart';
import 'server_account_store.dart';
import 'server_live_ops_store.dart';

/// Pure-Dart authoritative Online Domino Server (`HttpServer` + `WebSocket`).
///
/// Handles:
/// - REST Authentication & Guest Account Linking (`/api/auth/register`,
///   `/api/auth/login`, `/api/profile/sync`, `/api/leaderboard`, `/health`)
/// - Online Friends Rooms by 4-digit Room Code (`WS /ws?mode=host|join...`)
/// - Online Random Matchmaking queues (`WS /ws?mode=matchmaking...`)
/// - Reuses [AuthoritativeRoomHost] in server RAM for sub-30ms move latency
///   and 100% anti-cheat hand/boneyard masking.
class DominoOnlineServer {
  DominoOnlineServer({
    String? storageFilePath,
    String? adminSecret,
    Random? random,
  }) : accounts = ServerAccountStore(storageFilePath: storageFilePath),
       liveOps = ServerLiveOpsStore(
         storageFilePath: storageFilePath == null || storageFilePath.isEmpty
             ? null
             : '$storageFilePath.liveops.json',
       ),
       adminSecret =
           adminSecret ??
           Platform.environment['ADMIN_SECRET'] ??
           'maqha_admin_2026',
       _random = random ?? Random();

  final ServerAccountStore accounts;
  final ServerLiveOpsStore liveOps;
  final String adminSecret;
  final Random _random;

  HttpServer? _httpServer;
  final Map<String, _HostedOnlineRoom> _roomsByCode = {};
  final Map<String, List<int>> _rateBuckets = {};
  int _nextPeerSeq = 1;

  /// Protects `/api/*` and `/ws` from spam/flood attacks (max [maxRequests] per
  /// 10-second sliding window per IP/peer key).
  bool _allowRate(String key, {int maxRequests = 45}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowStart = now - 10000;
    final bucket = _rateBuckets.putIfAbsent(key, () => <int>[])
      ..removeWhere((ts) => ts < windowStart);
    if (bucket.length >= maxRequests) return false;
    bucket.add(now);
    return true;
  }

  int get port => _httpServer?.port ?? 0;
  int get activeRoomCount => _roomsByCode.length;

  /// Starts listening on [address] and [bindPort] (pass `0` for an ephemeral
  /// port in automated tests).
  Future<int> start({
    Object? address,
    int bindPort = 8080,
  }) async {
    final srv = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      bindPort,
    );
    _httpServer = srv;
    srv.listen(_handleHttpRequest, onError: (_) {});
    return srv.port;
  }

  Future<void> stop() async {
    for (final r in _roomsByCode.values.toList()) {
      await r.dispose();
    }
    _roomsByCode.clear();
    await _httpServer?.close(force: true);
    _httpServer = null;
  }

  Future<void> _handleHttpRequest(HttpRequest req) async {
    req.response.headers.set('Access-Control-Allow-Origin', '*');
    req.response.headers.set('X-Content-Type-Options', 'nosniff');
    req.response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    req.response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );

    if (req.method == 'OPTIONS') {
      req.response.statusCode = HttpStatus.noContent;
      await req.response.close();
      return;
    }

    final path = req.uri.path;
    final clientIp =
        req.connectionInfo?.remoteAddress.address ?? '127.0.0.1';
    if (!_allowRate('http:$clientIp')) {
      await _writeJson(req, HttpStatus.tooManyRequests, {
        'error': 'طلبات كثيرة جداً، يرجى الانتظار قليلاً',
      });
      return;
    }

    try {
      if (path == '/ws' && WebSocketTransformer.isUpgradeRequest(req)) {
        await _handleWebSocketUpgrade(req);
        return;
      }

      if (req.method == 'GET' && path == '/health') {
        await _writeJson(req, HttpStatus.ok, {
          'ok': true,
          'activeRooms': _roomsByCode.length,
        });
        return;
      }

      if (req.method == 'GET' && path == '/api/leaderboard') {
        final top = accounts.topLeaderboard();
        await _writeJson(req, HttpStatus.ok, {
          'leaders': [for (final p in top) p.toJson()],
        });
        return;
      }

      if (req.method == 'POST' && path == '/api/auth/register') {
        final body = await _readJsonBody(req);
        final guest = PlayerAccount.tryDecode(
          body['guestAccount'] is Map<String, Object?>
              ? jsonEncode(body['guestAccount'])
              : null,
        );
        final created = accounts.register(
          displayName: (body['displayName'] as String?) ?? '',
          email: (body['email'] as String?) ?? '',
          password: (body['password'] as String?) ?? '',
          guestAccount: guest,
        );
        await _writeJson(req, HttpStatus.ok, {'account': created.toJson()});
        return;
      }

      if (req.method == 'POST' && path == '/api/auth/login') {
        final body = await _readJsonBody(req);
        final guest = PlayerAccount.tryDecode(
          body['guestAccount'] is Map<String, Object?>
              ? jsonEncode(body['guestAccount'])
              : null,
        );
        final loggedIn = accounts.login(
          email: (body['email'] as String?) ?? '',
          password: (body['password'] as String?) ?? '',
          guestAccount: guest,
        );
        await _writeJson(req, HttpStatus.ok, {'account': loggedIn.toJson()});
        return;
      }

      if (req.method == 'POST' && path == '/api/auth/oauth') {
        final body = await _readJsonBody(req);
        final guest = PlayerAccount.tryDecode(
          body['guestAccount'] is Map<String, Object?>
              ? jsonEncode(body['guestAccount'])
              : null,
        );
        final googleAcc = accounts.loginOrRegisterGoogle(
          googleEmail: (body['providerUid'] as String?) ?? '',
          displayName: (body['displayName'] as String?) ?? '',
          guestAccount: guest,
        );
        await _writeJson(req, HttpStatus.ok, {'account': googleAcc.toJson()});
        return;
      }

      if (req.method == 'POST' && path == '/api/profile/sync') {
        final token = req.headers.value(HttpHeaders.authorizationHeader) ?? '';
        final body = await _readJsonBody(req);
        final clientAcc = PlayerAccount.tryDecode(
          body['account'] is Map<String, Object?>
              ? jsonEncode(body['account'])
              : null,
        );
        if (clientAcc == null) {
          await _writeJson(req, HttpStatus.badRequest, {
            'error': 'بيانات الحساب غير صالحة',
          });
          return;
        }
        final synced = accounts.syncAccount(
          token: token,
          clientAccount: clientAcc,
        );
        if (synced == null) {
          await _writeJson(req, HttpStatus.unauthorized, {
            'error': 'جلسة الدخول منتهية',
          });
          return;
        }
        await _writeJson(req, HttpStatus.ok, {'account': synced.toJson()});
        return;
      }

      if (req.method == 'POST' && path == '/api/account/delete-self') {
        final token = req.headers.value(HttpHeaders.authorizationHeader) ?? '';
        final verified = accounts.verifyToken(token);
        if (verified == null) {
          await _writeJson(req, HttpStatus.unauthorized, {
            'error': 'جلسة الدخول غير صالحة',
          });
          return;
        }
        final deleted = accounts.cancelAndDeleteAccount(verified.playerId);
        await _writeJson(req, HttpStatus.ok, {'deleted': deleted});
        return;
      }

      if (req.method == 'GET' && path == '/api/rooms') {
        final pc = int.tryParse(req.uri.queryParameters['playerCount'] ?? '');
        final rooms = [
          for (final r in _roomsByCode.values)
            if (!r.isFull && (pc == null || r.host.playerCount == pc))
              r.toDiscoveredRoom().toJson(),
        ];
        await _writeJson(req, HttpStatus.ok, {'rooms': rooms});
        return;
      }

      // Public LiveOps feed: active seasonal/monthly Events & Tournament tiers
      if (req.method == 'GET' && path == '/api/live-ops') {
        final dateOverride = req.uri.queryParameters['date'];
        await _writeJson(req, HttpStatus.ok, {
          'events': [
            for (final e in liveOps.activeEvents(dateOverride)) e.toJson(),
          ],
          'tournaments': [
            for (final t in liveOps.activeTournaments) t.toJson(),
          ],
        });
        return;
      }

      // Built-in Arabic Web Admin Dashboard (`/admin`)
      if (req.method == 'GET' && path == '/admin') {
        req.response.statusCode = HttpStatus.ok;
        req.response.headers.set('X-Frame-Options', 'DENY');
        req.response.headers.contentType = ContentType.html;
        req.response.write(kAdminDashboardHtml);
        await req.response.close();
        return;
      }

      // Protected Admin LiveOps API (`/api/admin/*`)
      if (path.startsWith('/api/admin/')) {
        final auth =
            req.headers
                .value(HttpHeaders.authorizationHeader)
                ?.replaceFirst('Bearer ', '')
                .trim() ??
            '';
        if (auth != adminSecret) {
          await _writeJson(req, HttpStatus.unauthorized, {
            'error': 'مفتاح الإدارة ADMIN_SECRET غير صحيح',
          });
          return;
        }

        if (req.method == 'GET' && path == '/api/admin/overview') {
          final search = req.uri.queryParameters['q'];
          await _writeJson(req, HttpStatus.ok, {
            'stats': {
              'totalAccounts': accounts.totalAccountCount,
              'bannedAccounts': accounts.activeBannedCount(),
              'activeRooms': _roomsByCode.length,
              'activeEvents': liveOps.activeEvents().length,
              'activeTournaments': liveOps.activeTournaments.length,
            },
            'accounts': accounts.listAccountsForAdmin(search: search),
            'rooms': [
              for (final r in _roomsByCode.values) r.toDiscoveredRoom().toJson(),
            ],
            'events': [for (final e in liveOps.allEvents) e.toJson()],
            'tournaments': [
              for (final t in liveOps.allTournaments) t.toJson(),
            ],
          });
          return;
        }

        if (req.method == 'POST' && path == '/api/admin/accounts/ban') {
          final body = await _readJsonBody(req);
          final userId = (body['userId'] as String?) ?? '';
          final hours = (body['durationHours'] as num?)?.toInt() ?? 24;
          final reason = (body['reason'] as String?) ?? '';
          final banned = accounts.banAccount(
            userId: userId,
            durationHours: hours,
            reason: reason,
          );
          if (banned == null) {
            await _writeJson(req, HttpStatus.notFound, {
              'error': 'الحساب غير موجود',
            });
            return;
          }
          await _writeJson(req, HttpStatus.ok, {
            'account': banned.toAdminSummaryJson(),
          });
          return;
        }

        if (req.method == 'POST' && path == '/api/admin/accounts/unban') {
          final body = await _readJsonBody(req);
          final unbanned = accounts.unbanAccount(
            (body['userId'] as String?) ?? '',
          );
          await _writeJson(req, HttpStatus.ok, {
            'account': unbanned?.toAdminSummaryJson(),
          });
          return;
        }

        if (req.method == 'POST' && path == '/api/admin/accounts/delete') {
          final body = await _readJsonBody(req);
          final deleted = accounts.cancelAndDeleteAccount(
            (body['userId'] as String?) ?? '',
          );
          await _writeJson(req, HttpStatus.ok, {'deleted': deleted});
          return;
        }

        if (req.method == 'POST' && path == '/api/admin/accounts/update') {
          final body = await _readJsonBody(req);
          final updated = accounts.updateAccountByAdmin(
            userId: (body['userId'] as String?) ?? '',
            cafeDinars: (body['cafeDinars'] as num?)?.toInt(),
            rating: (body['rating'] as num?)?.toInt(),
            isVip: body['isVip'] as bool?,
          );
          await _writeJson(req, HttpStatus.ok, {
            'account': updated?.toAdminSummaryJson(),
          });
          return;
        }

        if (req.method == 'POST' && path == '/api/admin/rooms/close') {
          final body = await _readJsonBody(req);
          final code = (body['roomCode'] as String?) ?? '';
          final room = _roomsByCode.remove(code);
          if (room != null) await room.dispose();
          await _writeJson(req, HttpStatus.ok, {'closed': room != null});
          return;
        }

        if (req.method == 'GET' && path == '/api/admin/live-ops') {
          await _writeJson(req, HttpStatus.ok, {
            'events': [for (final e in liveOps.allEvents) e.toJson()],
            'tournaments': [
              for (final t in liveOps.allTournaments) t.toJson(),
            ],
          });
          return;
        }

        if (req.method == 'POST' && path == '/api/admin/events/upsert') {
          final body = await _readJsonBody(req);
          final ev = CafeEventDefinition.fromJson(body);
          liveOps.upsertEvent(ev);
          await _writeJson(req, HttpStatus.ok, {'event': ev.toJson()});
          return;
        }

        if (req.method == 'POST' && path == '/api/admin/events/delete') {
          final body = await _readJsonBody(req);
          final deleted = liveOps.deleteEvent((body['id'] as String?) ?? '');
          await _writeJson(req, HttpStatus.ok, {'deleted': deleted});
          return;
        }

        if (req.method == 'POST' && path == '/api/admin/tournaments/upsert') {
          final body = await _readJsonBody(req);
          final cup = CafeTournamentTier.fromJson(body);
          liveOps.upsertTournament(cup);
          await _writeJson(req, HttpStatus.ok, {'tournament': cup.toJson()});
          return;
        }

        if (req.method == 'POST' && path == '/api/admin/tournaments/delete') {
          final body = await _readJsonBody(req);
          final deleted = liveOps.deleteTournament(
            (body['id'] as String?) ?? '',
          );
          await _writeJson(req, HttpStatus.ok, {'deleted': deleted});
          return;
        }
      }

      await _writeJson(req, HttpStatus.notFound, {'error': 'Not found'});
    } catch (e) {
      final msg = e
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Invalid argument(s): ', '');
      await _writeJson(req, HttpStatus.badRequest, {'error': msg});
    }
  }

  // ---------------------------------------------------------------------------
  // WebSocket Room Hosting & Joining
  // ---------------------------------------------------------------------------

  Future<void> _handleWebSocketUpgrade(HttpRequest req) async {
    final qp = req.uri.queryParameters;
    final mode = qp['mode'] ?? 'join'; // 'host', 'join', or 'matchmaking'
    final ws = await WebSocketTransformer.upgrade(req);
    ws.pingInterval = const Duration(seconds: 15);
    final peerId = 'ws_${_nextPeerSeq++}';

    // Reject banned or cancelled accounts from opening or joining online rooms:
    final accessErr = accounts.checkPlayerAccessError(qp['playerId']);
    if (accessErr != null) {
      ws.add(
        WireEnvelope(
          type: WireEnvelope.tError,
          data: {'message': accessErr},
        ).encode(),
      );
      await ws.close(4003, accessErr);
      return;
    }

    if (mode == 'matchmaking') {
      final playerCount = (int.tryParse(qp['playerCount'] ?? '4') == 2) ? 2 : 4;
      final targetScore = int.tryParse(qp['targetScore'] ?? '151') ?? 151;
      final aiDiff = AiDifficulty.byId(qp['aiDifficulty']);
      final playerId = qp['playerId'] ?? 'mm_$peerId';
      final displayName = qp['displayName'] ?? 'لاعب';
      final isGuest = qp['isGuest'] != 'false';
      final autoStartMs =
          int.tryParse(qp['autoStartAfterMs'] ?? '3200') ?? 3200;

      // 1. Check if there is an existing matchmaking room this player can
      //    reconnect to, join in lobby, or hot-join mid-match (< 65% score).
      _HostedOnlineRoom? targetRoom;
      for (final r in _roomsByCode.values) {
        if (r.isMatchmaking &&
            r.host.playerCount == playerCount &&
            r.canAcceptMatchmakingJoin(playerId)) {
          targetRoom = r;
          break;
        }
      }

      if (targetRoom != null) {
        targetRoom.transport.attachClientSocket(peerId, ws);
        return;
      }

      // 2. Otherwise create a new matchmaking room and start its auto-fill timer.
      final code = _generateUniqueRoomCode();
      final transport = _ServerWsHostTransport(
        roomCode: code,
        channel: SessionChannel.onlineRandom,
      );
      final hostProfile = PublicPlayerProfile(
        playerId: playerId,
        displayName: displayName,
        isGuest: isGuest,
      );
      final roomHost = AuthoritativeRoomHost(
        transport: transport,
        hostProfile: hostProfile,
        playerCount: playerCount,
        rules: GameRulesConfig(
          targetScore: targetScore,
          aiDifficulty: aiDiff,
        ),
        random: _random,
      );

      final hosted = _HostedOnlineRoom(
        roomCode: code,
        host: roomHost,
        transport: transport,
        creatorWs: ws,
        isMatchmaking: true,
        autoStartDelay: Duration(milliseconds: autoStartMs),
        onEmpty: () {
          _roomsByCode.remove(code);
        },
      );
      _roomsByCode[code] = hosted;
      await hosted.start();
      return;
    }

    if (mode == 'host') {
      final playerCount = (int.tryParse(qp['playerCount'] ?? '4') == 2) ? 2 : 4;
      final targetScore = int.tryParse(qp['targetScore'] ?? '151') ?? 151;
      final aiDiff = AiDifficulty.byId(qp['aiDifficulty']);
      final hostId = qp['playerId'] ?? 'host_$peerId';
      final hostName = qp['displayName'] ?? 'مضيف';
      final isGuest = qp['isGuest'] != 'false';

      final code = _generateUniqueRoomCode();

      final transport = _ServerWsHostTransport(
        roomCode: code,
        channel: SessionChannel.onlineRoom,
      );

      final hostProfile = PublicPlayerProfile(
        playerId: hostId,
        displayName: hostName,
        isGuest: isGuest,
      );

      final roomHost = AuthoritativeRoomHost(
        transport: transport,
        hostProfile: hostProfile,
        playerCount: playerCount,
        rules: GameRulesConfig(
          targetScore: targetScore,
          aiDifficulty: aiDiff,
        ),
        random: _random,
      );

      final hosted = _HostedOnlineRoom(
        roomCode: code,
        host: roomHost,
        transport: transport,
        creatorWs: ws,
        onEmpty: () {
          _roomsByCode.remove(code);
        },
      );
      _roomsByCode[code] = hosted;
      await hosted.start();
      return;
    }

    // Joining an existing room by 4-digit roomCode:
    final roomCode = (qp['roomCode'] ?? '').trim();
    final hosted = _roomsByCode[roomCode];
    if (hosted == null) {
      ws.add(
        const WireEnvelope(
          type: WireEnvelope.tError,
          data: {'message': 'لم يتم العثور على الغرفة المطلوبة على السيرفر'},
        ).encode(),
      );
      await ws.close();
      return;
    }

    hosted.transport.attachClientSocket(peerId, ws);
  }

  String _generateUniqueRoomCode() {
    for (var i = 0; i < 50; i++) {
      final candidate = (1000 + _random.nextInt(9000)).toString();
      if (!_roomsByCode.containsKey(candidate)) return candidate;
    }
    return (1000 + _random.nextInt(9000)).toString();
  }

  /// Reads JSON request body with a strict `2.5 MB` size cap to prevent memory
  /// exhaustion while still allowing uploaded Base64 sponsor images from `/admin`.
  Future<Map<String, Object?>> _readJsonBody(HttpRequest req) async {
    const maxBytes = 2621440; // 2.5 MB
    final builder = BytesBuilder(copy: false);
    await for (final chunk in req) {
      if (builder.length + chunk.length > maxBytes) {
        throw StateError('حجم البيانات المرسلة كبير جداً (الحد الأقصى 2.5MB)');
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) return const {};
    final decoded = jsonDecode(utf8.decode(bytes));
    return decoded is Map<String, Object?> ? decoded : const {};
  }

  Future<void> _writeJson(
    HttpRequest req,
    int status,
    Map<String, Object?> body,
  ) async {
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }
}

/// Bridges one [AuthoritativeRoomHost] living in server RAM to its creator's
/// WebSocket AND all joining peer WebSockets.
class _HostedOnlineRoom {
  _HostedOnlineRoom({
    required this.roomCode,
    required this.host,
    required this.transport,
    required this.creatorWs,
    required this.onEmpty,
    this.isMatchmaking = false,
    this.autoStartDelay = const Duration(milliseconds: 3200),
  });

  final String roomCode;
  final AuthoritativeRoomHost host;
  final _ServerWsHostTransport transport;
  final WebSocket creatorWs;
  final void Function() onEmpty;
  final bool isMatchmaking;
  final Duration autoStartDelay;

  StreamSubscription<RoomLobbyState>? _lobbySub;
  StreamSubscription<MaskedMatchPayload>? _matchSub;
  StreamSubscription<Object?>? _creatorWsSub;
  Timer? _autoStartTimer;

  bool get isFull =>
      (host.currentLobby?.humanCount ?? 1) >= host.playerCount;

  bool canAcceptMatchmakingJoin(String playerId) {
    final lobby = host.currentLobby;
    if (lobby == null) return false;
    // Same player reconnecting to their seat:
    if (lobby.seatOfPlayer(playerId) != null) return true;
    // Pre-match lobby still filling up:
    if (!lobby.matchStarted && !isFull) return true;
    // Running match below 65% endgame cutoff with an open bot/disconnected seat:
    final snap = host.currentHostPayload;
    if (lobby.matchStarted &&
        snap != null &&
        snap.canAcceptHumanJoin &&
        lobby.humanCount < host.playerCount) {
      return true;
    }
    return false;
  }

  DiscoveredRoom toDiscoveredRoom() => DiscoveredRoom(
    roomId: 'online_$roomCode',
    roomCode: roomCode,
    hostName: host.hostProfile.displayName,
    channel: SessionChannel.onlineRoom,
    playerCount: host.playerCount,
    occupiedHumans: host.currentLobby?.humanCount ?? 1,
    targetScore: host.rules.targetScore,
    endpoint: roomCode,
    lastSeenMs: DateTime.now().millisecondsSinceEpoch,
  );

  Future<void> start() async {
    // Forward server-side Host lobby & match snapshots to the creator's phone!
    _lobbySub = host.lobbyStream.listen((lobby) {
      _sendToCreator(
        WireEnvelope(
          type: WireEnvelope.tLobbyState,
          data: lobby.toJson(),
        ).encode(),
      );
      if (isMatchmaking &&
          !lobby.matchStarted &&
          lobby.humanCount >= host.playerCount) {
        _autoStartTimer?.cancel();
        scheduleMicrotask(host.startMatch);
      }
    });
    _matchSub = host.hostMatchStream.listen((snap) {
      _sendToCreator(
        WireEnvelope(
          type: WireEnvelope.tMatchSnapshot,
          data: snap.toJson(),
        ).encode(),
      );
    });

    await host.startRoom();
    if (host.currentLobby != null) {
      _sendToCreator(
        WireEnvelope(
          type: WireEnvelope.tLobbyState,
          data: host.currentLobby!.toJson(),
        ).encode(),
      );
    }

    if (isMatchmaking) {
      _autoStartTimer = Timer(autoStartDelay, () {
        if (host.currentLobby != null && !host.currentLobby!.matchStarted) {
          host.startMatch();
        }
      });
    }

    // Listen to commands sent by the room creator (pickSeat, start_match, play_move, etc.)
    _creatorWsSub = creatorWs.listen(
      (raw) {
        if (raw is! String) return;
        final env = WireEnvelope.tryDecode(raw);
        if (env == null) return;
        switch (env.type) {
          case 'start_match':
            host.startMatch();
          case WireEnvelope.tPickSeat:
            final s = (env.data['seat'] as num?)?.toInt();
            if (s != null) host.hostPickSeat(s);
          case WireEnvelope.tPlayMove:
            final low = (env.data['low'] as num?)?.toInt();
            final high = (env.data['high'] as num?)?.toInt();
            final endStr = env.data['end'] as String?;
            if (low != null && high != null && endStr != null) {
              final l = low <= high ? low : high;
              final h = low <= high ? high : low;
              if (l < 0 || h > 6) return;
              // Re-use hostPlayMove via tPlayMove routing:
              transport.injectFrameFromCreator(
                host.hostProfile.playerId,
                l,
                h,
                endStr,
                host,
              );
            }
          case WireEnvelope.tDrawSlot:
            final slot = (env.data['slot'] as num?)?.toInt();
            if (slot != null) host.hostDrawSlot(slot);
          case WireEnvelope.tResetMatch:
            host.hostResetMatch();
        }
      },
      onDone: () {
        dispose();
        onEmpty();
      },
      onError: (_) {
        dispose();
        onEmpty();
      },
    );
  }

  void _sendToCreator(String frame) {
    try {
      creatorWs.add(frame);
    } catch (_) {}
  }

  Future<void> dispose() async {
    _autoStartTimer?.cancel();
    await _lobbySub?.cancel();
    await _matchSub?.cancel();
    await _creatorWsSub?.cancel();
    await host.dispose();
    try {
      await creatorWs.close();
    } catch (_) {}
  }
}

class _ServerWsHostTransport implements PeerHostTransport {
  _ServerWsHostTransport({
    required this.roomCode,
    required this.channel,
  });

  @override
  final String roomCode;

  @override
  final SessionChannel channel;

  @override
  String get endpointLabel => 'ws://$roomCode';

  final Map<String, WebSocket> _peers = {};
  final _frames = StreamController<PeerInboundFrame>.broadcast();
  final _connected = StreamController<String>.broadcast();
  final _disconnected = StreamController<String>.broadcast();

  @override
  Stream<PeerInboundFrame> get frames => _frames.stream;

  @override
  Stream<String> get peerConnected => _connected.stream;

  @override
  Stream<String> get peerDisconnected => _disconnected.stream;

  void attachClientSocket(String peerId, WebSocket ws) {
    _peers[peerId] = ws;
    if (!_connected.isClosed) _connected.add(peerId);

    ws.listen(
      (data) {
        if (data is String && data.isNotEmpty && !_frames.isClosed) {
          _frames.add(PeerInboundFrame(peerId: peerId, payload: data));
        }
      },
      onDone: () => _dropPeer(peerId),
      onError: (_) => _dropPeer(peerId),
      cancelOnError: true,
    );
  }

  void injectFrameFromCreator(
    String hostPlayerId,
    int low,
    int high,
    String endStr,
    AuthoritativeRoomHost host,
  ) {
    // Route directly to hostPlayMove via DominoPiece & BoardEnd:
    final piece = host.currentHostPayload?.myMoves
        .map((m) => m.piece)
        .firstWhere(
          (p) => p.low == low && p.high == high,
          orElse: () =>
              throw StateError('Move piece not in host legal moves'),
        );
    if (piece != null) {
      final end = host.currentHostPayload!.myMoves
          .firstWhere(
            (m) =>
                m.piece == piece &&
                (endStr == 'L' ? m.end.name == 'left' : m.end.name == 'right'),
          )
          .end;
      host.hostPlayMove(piece, end);
    }
  }

  void _dropPeer(String peerId) {
    final ws = _peers.remove(peerId);
    if (ws != null) {
      try {
        ws.close();
      } catch (_) {}
      if (!_disconnected.isClosed) _disconnected.add(peerId);
    }
  }

  @override
  Future<String> start({
    required String hostName,
    required int playerCount,
    required int targetScore,
    String? preferredRoomCode,
  }) async {
    return roomCode;
  }

  @override
  void updateAdvertisement({required int occupiedHumans}) {}

  @override
  Future<void> sendToPeer(String peerId, String payload) async {
    final ws = _peers[peerId];
    if (ws == null) return;
    try {
      ws.add(payload);
    } catch (_) {
      _dropPeer(peerId);
    }
  }

  @override
  Future<void> broadcast(String payload) async {
    for (final entry in _peers.entries.toList()) {
      try {
        entry.value.add(payload);
      } catch (_) {
        _dropPeer(entry.key);
      }
    }
  }

  @override
  Future<void> stop() async {
    for (final ws in _peers.values.toList()) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _peers.clear();
    await _frames.close();
    await _connected.close();
    await _disconnected.close();
  }
}
