import 'dart:async';

import '../protocol/connection_channel.dart';

/// Metadata advertised by an open local or online room before joining.
class DiscoveredRoom {
  const DiscoveredRoom({
    required this.roomId,
    required this.roomCode,
    required this.hostName,
    required this.channel,
    required this.playerCount,
    required this.occupiedHumans,
    required this.targetScore,
    required this.endpoint,
    required this.lastSeenMs,
  });

  final String roomId;
  final String roomCode;
  final String hostName;
  final SessionChannel channel;
  final int playerCount;
  final int occupiedHumans;
  final int targetScore;

  /// Transport-specific address (e.g. `192.168.1.12:41920` or Bluetooth MAC /
  /// Multipeer peer ID).
  final String endpoint;
  final int lastSeenMs;

  Map<String, Object?> toJson() => {
    'roomId': roomId,
    'roomCode': roomCode,
    'hostName': hostName,
    'channel': channel.id,
    'playerCount': playerCount,
    'occupiedHumans': occupiedHumans,
    'targetScore': targetScore,
    'endpoint': endpoint,
    'lastSeenMs': lastSeenMs,
  };

  factory DiscoveredRoom.fromJson(Map<String, Object?> json) => DiscoveredRoom(
    roomId: (json['roomId'] as String?) ?? '',
    roomCode: (json['roomCode'] as String?) ?? '',
    hostName: (json['hostName'] as String?) ?? 'مضيف',
    channel: SessionChannel.byId(json['channel'] as String?),
    playerCount: (json['playerCount'] as num?)?.toInt() ?? 4,
    occupiedHumans: (json['occupiedHumans'] as num?)?.toInt() ?? 1,
    targetScore: (json['targetScore'] as num?)?.toInt() ?? 151,
    endpoint: (json['endpoint'] as String?) ?? '',
    lastSeenMs: (json['lastSeenMs'] as num?)?.toInt() ?? 0,
  );
}

/// Incoming JSON frame received by the Host from a connected peer [peerId].
class PeerInboundFrame {
  const PeerInboundFrame({required this.peerId, required this.payload});

  final String peerId;
  final String payload;
}

/// Transport-agnostic Host server interface implemented identically by:
/// - Local Wi-Fi (`LanWifiHostTransport`)
/// - Offline Wi-Fi / Hotspot / Wi-Fi Direct (`LanWifiHostTransport` + P2P)
/// - Bluetooth (`NativeP2pHostTransport`)
/// - In-memory test bus (`InMemoryHostTransport`)
/// - Future Phase 7 Online WebSocket room worker
abstract interface class PeerHostTransport {
  SessionChannel get channel;

  /// Human-shareable room code (4-6 chars) or quick-connect token.
  String get roomCode;

  /// Direct endpoint description (e.g. IP:Port or Bluetooth name) for UI info.
  String get endpointLabel;

  Stream<PeerInboundFrame> get frames;
  Stream<String> get peerConnected;
  Stream<String> get peerDisconnected;

  /// Starts advertising/listening and returns the shareable [roomCode].
  Future<String> start({
    required String hostName,
    required int playerCount,
    required int targetScore,
    String? preferredRoomCode,
  });

  /// Updates advertised human occupancy count for room browsers.
  void updateAdvertisement({required int occupiedHumans});

  /// Sends a serialized UTF-8 JSON line to a single connected [peerId].
  Future<void> sendToPeer(String peerId, String payload);

  /// Sends a serialized UTF-8 JSON line to all connected peers.
  Future<void> broadcast(String payload);

  Future<void> stop();
}

/// Transport-agnostic Client interface used by joining peers across all 3 local
/// channels and Phase 7 Online rooms.
abstract interface class PeerClientTransport {
  SessionChannel get channel;

  Stream<List<DiscoveredRoom>> get discoveredRooms;
  Stream<String> get frames;
  Stream<void> get disconnected;

  /// Begins scanning/browsing for nearby open rooms on [channel].
  Future<void> startDiscovery();

  Future<void> stopDiscovery();

  /// Connects to a discovered [room] or direct [codeOrEndpoint].
  Future<void> connect({DiscoveredRoom? room, String? codeOrEndpoint});

  /// Sends a serialized UTF-8 JSON line to the Host/Server.
  Future<void> send(String payload);

  Future<void> disconnect();
}

// -----------------------------------------------------------------------------
// Deterministic In-Memory Transport Hub (for fast unit tests & local simulation)
// -----------------------------------------------------------------------------

/// In-memory message bus implementing [PeerHostTransport] and
/// [PeerClientTransport] with zero OS sockets, used for unit & integration
/// testing of the full multiplayer engine.
class InMemoryTransportBus {
  final Map<String, _InMemoryHostNode> _hostsByCode = {};
  final StreamController<void> _directoryChanges =
      StreamController<void>.broadcast();

  PeerHostTransport createHost({
    SessionChannel channel = SessionChannel.localWifi,
    String roomCode = '1042',
  }) {
    return _InMemoryHostNode(this, channel: channel, roomCode: roomCode);
  }

  PeerClientTransport createClient({
    SessionChannel channel = SessionChannel.localWifi,
  }) {
    return _InMemoryClientNode(this, channel: channel);
  }

  List<DiscoveredRoom> roomsFor(SessionChannel channel) => [
    for (final h in _hostsByCode.values)
      if (h.channel == channel && h._running) h._advertisement,
  ];

  void _notifyDirectory() {
    if (!_directoryChanges.isClosed) _directoryChanges.add(null);
  }

  void dispose() {
    _directoryChanges.close();
  }
}

class _InMemoryHostNode implements PeerHostTransport {
  _InMemoryHostNode(
    this._bus, {
    required this.channel,
    required String roomCode,
  }) : _initialRoomCode = roomCode;

  final InMemoryTransportBus _bus;

  @override
  final SessionChannel channel;

  @override
  String get roomCode => _activeCode;

  late String _activeCode = _initialRoomCode;
  final String _initialRoomCode;

  @override
  String get endpointLabel => 'mem://$_activeCode';

  final _frames = StreamController<PeerInboundFrame>.broadcast();
  final _connected = StreamController<String>.broadcast();
  final _disconnected = StreamController<String>.broadcast();
  final Map<String, _InMemoryClientNode> _peers = {};

  bool _running = false;
  late DiscoveredRoom _advertisement;

  @override
  Stream<PeerInboundFrame> get frames => _frames.stream;

  @override
  Stream<String> get peerConnected => _connected.stream;

  @override
  Stream<String> get peerDisconnected => _disconnected.stream;

  @override
  Future<String> start({
    required String hostName,
    required int playerCount,
    required int targetScore,
    String? preferredRoomCode,
  }) async {
    _running = true;
    if (_initialRoomCode.isEmpty &&
        preferredRoomCode != null &&
        preferredRoomCode.isNotEmpty) {
      _activeCode = preferredRoomCode;
    } else {
      _activeCode = _initialRoomCode;
    }
    _advertisement = DiscoveredRoom(
      roomId: 'room_$_activeCode',
      roomCode: _activeCode,
      hostName: hostName,
      channel: channel,
      playerCount: playerCount,
      occupiedHumans: 1,
      targetScore: targetScore,
      endpoint: endpointLabel,
      lastSeenMs: DateTime.now().millisecondsSinceEpoch,
    );
    _bus._hostsByCode[_activeCode] = this;
    _bus._notifyDirectory();
    return _activeCode;
  }

  @override
  void updateAdvertisement({required int occupiedHumans}) {
    if (!_running) return;
    _advertisement = DiscoveredRoom(
      roomId: _advertisement.roomId,
      roomCode: _advertisement.roomCode,
      hostName: _advertisement.hostName,
      channel: channel,
      playerCount: _advertisement.playerCount,
      occupiedHumans: occupiedHumans,
      targetScore: _advertisement.targetScore,
      endpoint: endpointLabel,
      lastSeenMs: DateTime.now().millisecondsSinceEpoch,
    );
    _bus._notifyDirectory();
  }

  @override
  Future<void> sendToPeer(String peerId, String payload) async {
    final client = _peers[peerId];
    if (client != null && !client._frames.isClosed) {
      scheduleMicrotask(() {
        if (!client._frames.isClosed) client._frames.add(payload);
      });
    }
  }

  @override
  Future<void> broadcast(String payload) async {
    for (final peerId in _peers.keys.toList()) {
      await sendToPeer(peerId, payload);
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    _bus._hostsByCode.remove(_activeCode);
    _bus._notifyDirectory();
    for (final c in _peers.values.toList()) {
      c._notifyHostClosed();
    }
    _peers.clear();
    await _frames.close();
    await _connected.close();
    await _disconnected.close();
  }
}

class _InMemoryClientNode implements PeerClientTransport {
  _InMemoryClientNode(this._bus, {required this.channel});

  static int _nextPeerSeq = 1;

  final InMemoryTransportBus _bus;
  final String _peerId = 'mem_peer_${_nextPeerSeq++}';

  @override
  final SessionChannel channel;

  final _rooms = StreamController<List<DiscoveredRoom>>.broadcast();
  final _frames = StreamController<String>.broadcast();
  final _disconnected = StreamController<void>.broadcast();
  StreamSubscription<void>? _dirSub;
  _InMemoryHostNode? _host;

  @override
  Stream<List<DiscoveredRoom>> get discoveredRooms => _rooms.stream;

  @override
  Stream<String> get frames => _frames.stream;

  @override
  Stream<void> get disconnected => _disconnected.stream;

  @override
  Future<void> startDiscovery() async {
    await _dirSub?.cancel();
    _dirSub = _bus._directoryChanges.stream.listen((_) {
      if (!_rooms.isClosed) _rooms.add(_bus.roomsFor(channel));
    });
    scheduleMicrotask(() {
      if (!_rooms.isClosed) _rooms.add(_bus.roomsFor(channel));
    });
  }

  @override
  Future<void> stopDiscovery() async {
    await _dirSub?.cancel();
    _dirSub = null;
  }

  @override
  Future<void> connect({DiscoveredRoom? room, String? codeOrEndpoint}) async {
    final code = room?.roomCode ?? codeOrEndpoint?.replaceFirst('mem://', '');
    final host = code == null ? null : _bus._hostsByCode[code];
    if (host == null || !host._running) {
      throw StateError('Room not found: $code');
    }
    _host = host;
    host._peers[_peerId] = this;
    if (!host._connected.isClosed) host._connected.add(_peerId);
  }

  @override
  Future<void> send(String payload) async {
    final host = _host;
    if (host == null || !host._running) return;
    scheduleMicrotask(() {
      if (!host._frames.isClosed) {
        host._frames.add(PeerInboundFrame(peerId: _peerId, payload: payload));
      }
    });
  }

  void _notifyHostClosed() {
    _host = null;
    if (!_disconnected.isClosed) _disconnected.add(null);
  }

  @override
  Future<void> disconnect() async {
    final host = _host;
    _host = null;
    if (host != null) {
      host._peers.remove(_peerId);
      if (!host._disconnected.isClosed) host._disconnected.add(_peerId);
    }
    await stopDiscovery();
    if (!_disconnected.isClosed) _disconnected.add(null);
  }
}
