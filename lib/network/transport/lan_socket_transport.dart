import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../protocol/connection_channel.dart';
import 'native_p2p_transport.dart';
import 'peer_transport.dart';

/// Encodes and decodes an `IPv4:port` endpoint into a short base-36 token
/// (kept as an advanced fallback alongside the automatic 4-digit Room Number).
class QuickConnectCodec {
  const QuickConnectCodec._();

  static String encode(String ip, int port) {
    final parts = ip.split('.');
    if (parts.length != 4) return '$ip:$port';
    final o0 = int.tryParse(parts[0]);
    final o1 = int.tryParse(parts[1]);
    final o2 = int.tryParse(parts[2]);
    final o3 = int.tryParse(parts[3]);
    if (o0 == null || o1 == null || o2 == null || o3 == null) {
      return '$ip:$port';
    }
    final ipVal = ((o0 & 0xFF) << 24) |
        ((o1 & 0xFF) << 16) |
        ((o2 & 0xFF) << 8) |
        (o3 & 0xFF);
    final packed = (BigInt.from(ipVal & 0xFFFFFFFF) << 16) |
        BigInt.from(port & 0xFFFF);
    final raw = packed.toRadixString(36).toUpperCase().padLeft(10, '0');
    return '${raw.substring(0, 5)}-${raw.substring(5)}';
  }

  static ({String host, int port})? tryDecode(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;
    // Do not misinterpret a 4-digit room number (e.g. `4829`) as a base-36 IP!
    if (RegExp(r'^\d{4}$').hasMatch(clean)) return null;

    final colonIdx = clean.lastIndexOf(':');
    if (colonIdx > 0 && clean.contains('.')) {
      final host = clean.substring(0, colonIdx).trim();
      final port = int.tryParse(clean.substring(colonIdx + 1).trim());
      if (host.isNotEmpty && port != null && port > 0 && port <= 65535) {
        return (host: host, port: port);
      }
    }

    final compact = clean.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    if (compact.length < 7) return null;
    final packed = BigInt.tryParse(compact, radix: 36);
    if (packed == null || packed <= BigInt.zero) return null;

    final port = (packed & BigInt.from(0xFFFF)).toInt();
    final ipVal = ((packed >> 16) & BigInt.from(0xFFFFFFFF)).toInt();
    if (port <= 0 || port > 65535) return null;

    final o0 = (ipVal >> 24) & 0xFF;
    final o1 = (ipVal >> 16) & 0xFF;
    final o2 = (ipVal >> 8) & 0xFF;
    final o3 = ipVal & 0xFF;
    if (o0 == 0) return null;
    return (host: '$o0.$o1.$o2.$o3', port: port);
  }
}

/// High-speed TCP (`tcpNoDelay: true`) + UDP auto-discovery Host transport
/// shared by:
/// - [SessionChannel.localWifi] (same Wi-Fi network)
/// - [SessionChannel.wifiOffline] (Offline Hotspot / Wi-Fi Direct P2P)
///
/// Automatically assigns a 4-digit Room Number (e.g. `4829`), binds to
/// [defaultGamePort] (`41928`) when free, broadcasts UDP beacons, and replies
/// instantly to UDP `WHO_HAS` room-number queries!
class LanSocketHostTransport implements PeerHostTransport {
  LanSocketHostTransport({
    required this.channel,
    this.discoveryPort = 41927,
    this.defaultGamePort = 41928,
    this.enableUdpBeacon = true,
  }) : assert(
         channel == SessionChannel.localWifi ||
             channel == SessionChannel.wifiOffline,
       );

  static const String _magic = 'IDOM1';
  static const String _queryMagic = 'IDOM_FIND1';

  @override
  final SessionChannel channel;

  final int discoveryPort;
  final int defaultGamePort;
  final bool enableUdpBeacon;

  ServerSocket? _server;
  RawDatagramSocket? _udp;
  Timer? _beaconTimer;

  String _roomCode = '';
  String _endpointLabel = '';
  String _hostName = '';
  int _playerCount = 4;
  int _targetScore = 151;
  int _occupiedHumans = 1;
  int _nextPeerSeq = 1;

  final Map<String, Socket> _clients = {};
  final _frames = StreamController<PeerInboundFrame>.broadcast();
  final _connected = StreamController<String>.broadcast();
  final _disconnected = StreamController<String>.broadcast();

  @override
  String get roomCode => _roomCode;

  @override
  String get endpointLabel => _endpointLabel;

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
    _hostName = hostName;
    _playerCount = playerCount;
    _targetScore = targetScore;
    _occupiedHumans = 1;

    if (channel == SessionChannel.wifiOffline) {
      await NativeP2pBridgeClient.tryEnsureWifiDirectGroup();
    }

    // Bind on fixed port 41928 first (makes Offline Hotspot direct gateway
    // probing instant even if UDP broadcast is blocked by the OS!), falling
    // back to an OS-assigned port if 41928 is already in use on the same machine.
    ServerSocket srv;
    if (enableUdpBeacon) {
      try {
        srv = await ServerSocket.bind(InternetAddress.anyIPv4, defaultGamePort);
      } catch (_) {
        srv = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      }
    } else {
      srv = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    }
    _server = srv;

    final localIp = await _resolveBestLocalIpv4(channel) ?? '127.0.0.1';
    _endpointLabel = '$localIp:${srv.port}';
    _roomCode = (preferredRoomCode != null && preferredRoomCode.isNotEmpty)
        ? preferredRoomCode
        : (1000 + Random().nextInt(9000)).toString();

    srv.listen(_onClientSocket, onError: (_) {});

    if (enableUdpBeacon) {
      await _startUdpBeaconAndResponder(srv.port, localIp);
    }

    return _roomCode;
  }

  void _onClientSocket(Socket socket) {
    socket.setOption(SocketOption.tcpNoDelay, true);
    final peerId = 'tcp_${_nextPeerSeq++}';
    _clients[peerId] = socket;
    if (!_connected.isClosed) _connected.add(peerId);

    utf8.decoder
        .bind(socket)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.isNotEmpty && !_frames.isClosed) {
              _frames.add(PeerInboundFrame(peerId: peerId, payload: line));
            }
          },
          onDone: () => _dropPeer(peerId),
          onError: (_) => _dropPeer(peerId),
          cancelOnError: true,
        );
  }

  void _dropPeer(String peerId) {
    final sock = _clients.remove(peerId);
    if (sock != null) {
      sock.destroy();
      if (!_disconnected.isClosed) _disconnected.add(peerId);
    }
  }

  Uint8List _encodeRoomBeacon(String ip, int tcpPort) {
    final packet = jsonEncode({
      'm': _magic,
      'roomId': 'room_$_roomCode',
      'roomCode': _roomCode,
      'hostName': _hostName,
      'channel': channel.id,
      'playerCount': _playerCount,
      'occupiedHumans': _occupiedHumans,
      'targetScore': _targetScore,
      'endpoint': '$ip:$tcpPort',
    });
    return Uint8List.fromList(utf8.encode(packet));
  }

  Future<void> _startUdpBeaconAndResponder(int tcpPort, String primaryIp) async {
    try {
      final udp = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );
      udp.broadcastEnabled = true;
      _udp = udp;

      // Reply directly via unicast whenever a peer searches by 4-digit roomCode!
      udp.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = udp.receive();
        if (dg == null) return;
        try {
          final map = jsonDecode(utf8.decode(dg.data));
          if (map is! Map<String, Object?> || map['m'] != _queryMagic) return;
          final wantedCode = (map['roomCode'] as String?)?.trim();
          if (wantedCode == null ||
              (wantedCode.isNotEmpty && wantedCode != _roomCode)) {
            return;
          }
          final replyBytes = _encodeRoomBeacon(primaryIp, tcpPort);
          udp.send(replyBytes, dg.address, dg.port);
        } catch (_) {}
      });

      void sendBeacon() async {
        final ips = await _allLocalIpv4s();
        if (ips.isEmpty) ips.add(primaryIp);
        final targets = <String>{
          '255.255.255.255',
          '192.168.43.255', // Android Wi-Fi Hotspot
          '192.168.49.255', // Android Wi-Fi Direct Group Owner
          '172.20.10.15', // iOS Personal Hotspot
          for (final ip in ips) _subnetBroadcastOf(ip),
        };

        for (final ip in ips) {
          final bytes = _encodeRoomBeacon(ip, tcpPort);
          for (final target in targets) {
            try {
              udp.send(bytes, InternetAddress(target), discoveryPort);
            } catch (_) {}
          }
        }
      }

      sendBeacon();
      _beaconTimer = Timer.periodic(
        const Duration(milliseconds: 850),
        (_) => sendBeacon(),
      );
    } catch (_) {}
  }

  @override
  void updateAdvertisement({required int occupiedHumans}) {
    _occupiedHumans = occupiedHumans;
  }

  @override
  Future<void> sendToPeer(String peerId, String payload) async {
    final sock = _clients[peerId];
    if (sock == null) return;
    try {
      sock.add(utf8.encode('$payload\n'));
    } catch (_) {
      _dropPeer(peerId);
    }
  }

  @override
  Future<void> broadcast(String payload) async {
    final bytes = utf8.encode('$payload\n');
    for (final entry in _clients.entries.toList()) {
      try {
        entry.value.add(bytes);
      } catch (_) {
        _dropPeer(entry.key);
      }
    }
  }

  @override
  Future<void> stop() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _udp?.close();
    _udp = null;
    for (final s in _clients.values.toList()) {
      s.destroy();
    }
    _clients.clear();
    await _server?.close();
    _server = null;
    if (channel == SessionChannel.wifiOffline) {
      await NativeP2pBridgeClient.tryRemoveWifiDirectGroup();
    }
    await _frames.close();
    await _connected.close();
    await _disconnected.close();
  }
}

/// Client transport for [SessionChannel.localWifi] and
/// [SessionChannel.wifiOffline] supporting BOTH:
/// 1. Live browsing of available nearby rooms (`discoveredRooms`).
/// 2. Joining directly by the Host's **4-digit Room Number** (via cached rooms,
///    active UDP `WHO_HAS` query, and automatic Hotspot gateway TCP probing!).
class LanSocketClientTransport implements PeerClientTransport {
  LanSocketClientTransport({
    required this.channel,
    this.discoveryPort = 41927,
    this.defaultGamePort = 41928,
  }) : assert(
         channel == SessionChannel.localWifi ||
             channel == SessionChannel.wifiOffline,
       );

  @override
  final SessionChannel channel;

  final int discoveryPort;
  final int defaultGamePort;

  RawDatagramSocket? _udp;
  Timer? _pruneTimer;
  Socket? _socket;
  final Map<String, DiscoveredRoom> _found = {};

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
    if (channel == SessionChannel.wifiOffline) {
      await NativeP2pBridgeClient.tryDiscoverWifiDirectPeers();
    }
    try {
      final udp = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );
      udp.broadcastEnabled = true;
      _udp = udp;

      udp.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = udp.receive();
        if (dg == null) return;
        _ingestDatagram(dg);
      });

      // Immediately broadcast an active room scan request too!
      _sendUdpQuery(udp, '');

      _pruneTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        final cutoff = DateTime.now().millisecondsSinceEpoch - 5000;
        final before = _found.length;
        _found.removeWhere((_, r) => r.lastSeenMs < cutoff);
        if (_found.length != before) _emitRooms();
      });
    } catch (_) {}
  }

  void _ingestDatagram(Datagram dg) {
    try {
      final text = utf8.decode(dg.data);
      final map = jsonDecode(text);
      if (map is! Map<String, Object?> || map['m'] != 'IDOM1') return;
      final portPart = ((map['endpoint'] as String?) ?? ':$defaultGamePort')
          .split(':')
          .last;
      final room = DiscoveredRoom.fromJson({
        ...map,
        'endpoint': '${dg.address.address}:$portPart',
        'lastSeenMs': DateTime.now().millisecondsSinceEpoch,
      });
      _found[room.endpoint] = room;
      _emitRooms();
    } catch (_) {}
  }

  Future<void> _sendUdpQuery(RawDatagramSocket udp, String roomCode) async {
    final ips = await _allLocalIpv4s();
    final targets = <String>{
      '255.255.255.255',
      '192.168.43.255',
      '192.168.49.255',
      '192.168.43.1',
      '192.168.49.1',
      '172.20.10.1',
      for (final ip in ips) _subnetBroadcastOf(ip),
      for (final ip in ips) _subnetGatewayOf(ip),
    };
    final payload = Uint8List.fromList(
      utf8.encode(jsonEncode({'m': 'IDOM_FIND1', 'roomCode': roomCode})),
    );
    for (final t in targets) {
      try {
        udp.send(payload, InternetAddress(t), discoveryPort);
      } catch (_) {}
    }
  }

  void _emitRooms() {
    if (_rooms.isClosed) return;
    final list = _found.values.toList()
      ..sort((a, b) => b.lastSeenMs.compareTo(a.lastSeenMs));
    _rooms.add(list);
  }

  @override
  Future<void> stopDiscovery() async {
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _udp?.close();
    _udp = null;
  }

  @override
  Future<void> connect({DiscoveredRoom? room, String? codeOrEndpoint}) async {
    final input = (room?.endpoint ?? codeOrEndpoint ?? '').trim();
    if (input.isEmpty) {
      throw ArgumentError('يرجى إدخال رقم الغرفة أو اختيار غرفة متاحة');
    }

    // 1. Direct IP:Port or QuickConnectCodec token?
    var resolved = QuickConnectCodec.tryDecode(input);

    // 2. Otherwise it's a 4-digit Room Number (e.g. `4829`)!
    if (resolved == null) {
      // Check already-discovered rooms first!
      for (final r in _found.values) {
        if (r.roomCode == input) {
          resolved = QuickConnectCodec.tryDecode(r.endpoint);
          break;
        }
      }
    }

    // 3. Active UDP unicast/broadcast query for this exact 4-digit Room Number!
    resolved ??= await _queryRoomCodeOverUdp(input);

    await stopDiscovery();

    // 4. Zero-UDP Hotspot/Gateway TCP fallback (connects to Host on port 41928
    //    even if a phone blocks all UDP broadcast packets!).
    Socket? sock;
    if (resolved != null) {
      sock = await Socket.connect(
        resolved.host,
        resolved.port,
        timeout: const Duration(seconds: 4),
      );
    } else {
      sock = await _probeHotspotGateways();
    }

    if (sock == null) {
      throw StateError(
        'لم يتم العثور على الغرفة رقم ($input). تأكد من اتصالك بنفس الشبكة أو نقطة الاتصال.',
      );
    }

    sock.setOption(SocketOption.tcpNoDelay, true);
    _socket = sock;

    utf8.decoder
        .bind(sock)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.isNotEmpty && !_frames.isClosed) _frames.add(line);
          },
          onDone: _onSocketClosed,
          onError: (_) => _onSocketClosed(),
          cancelOnError: true,
        );
  }

  Future<({String host, int port})?> _queryRoomCodeOverUdp(
    String roomCode,
  ) async {
    RawDatagramSocket? querySock;
    try {
      querySock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      querySock.broadcastEnabled = true;
      final completer = Completer<({String host, int port})?>();

      querySock.listen((event) {
        if (event != RawSocketEvent.read || completer.isCompleted) return;
        final dg = querySock!.receive();
        if (dg == null) return;
        try {
          final map = jsonDecode(utf8.decode(dg.data));
          if (map is! Map<String, Object?> || map['m'] != 'IDOM1') return;
          if (map['roomCode'] == roomCode) {
            final ep = (map['endpoint'] as String?) ?? '';
            final port = int.tryParse(ep.split(':').last) ?? defaultGamePort;
            completer.complete((host: dg.address.address, port: port));
          }
        } catch (_) {}
      });

      await _sendUdpQuery(querySock, roomCode);
      return await completer.future.timeout(
        const Duration(milliseconds: 950),
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    } finally {
      querySock?.close();
    }
  }

  Future<Socket?> _probeHotspotGateways() async {
    final myIps = await _allLocalIpv4s();
    final candidates = <String>{
      for (final ip in myIps) _subnetGatewayOf(ip),
      '192.168.43.1', // Android Hotspot Host
      '192.168.49.1', // Android Wi-Fi Direct Group Owner
      '172.20.10.1', // iOS Personal Hotspot Host
    };

    for (final host in candidates) {
      if (myIps.contains(host)) continue;
      try {
        return await Socket.connect(
          host,
          defaultGamePort,
          timeout: const Duration(milliseconds: 650),
        );
      } catch (_) {}
    }
    return null;
  }

  void _onSocketClosed() {
    _socket?.destroy();
    _socket = null;
    if (!_disconnected.isClosed) _disconnected.add(null);
  }

  @override
  Future<void> send(String payload) async {
    final sock = _socket;
    if (sock == null) return;
    sock.add(utf8.encode('$payload\n'));
  }

  @override
  Future<void> disconnect() async {
    await stopDiscovery();
    _socket?.destroy();
    _socket = null;
    if (!_disconnected.isClosed) _disconnected.add(null);
  }
}

// -----------------------------------------------------------------------------
// Network Interface Helpers
// -----------------------------------------------------------------------------

Future<List<String>> _allLocalIpv4s() async {
  final out = <String>[];
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) out.add(addr.address);
      }
    }
  } catch (_) {}
  return out;
}

Future<String?> _resolveBestLocalIpv4(SessionChannel channel) async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    String? fallback;
    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      for (final addr in iface.addresses) {
        final ip = addr.address;
        fallback ??= ip;
        if (channel == SessionChannel.wifiOffline) {
          if (ip.startsWith('192.168.49.') ||
              ip.startsWith('192.168.43.') ||
              ip.startsWith('172.20.10.') ||
              name.contains('p2p') ||
              name.contains('ap') ||
              name.contains('bridge')) {
            return ip;
          }
        } else if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
          return ip;
        }
      }
    }
    return fallback;
  } catch (_) {
    return null;
  }
}

String _subnetBroadcastOf(String ipv4) {
  final parts = ipv4.split('.');
  if (parts.length != 4) return '255.255.255.255';
  return '${parts[0]}.${parts[1]}.${parts[2]}.255';
}

String _subnetGatewayOf(String ipv4) {
  final parts = ipv4.split('.');
  if (parts.length != 4) return '192.168.43.1';
  return '${parts[0]}.${parts[1]}.${parts[2]}.1';
}
