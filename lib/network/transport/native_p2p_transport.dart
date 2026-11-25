import 'dart:async';

import 'package:flutter/services.dart';

import '../protocol/connection_channel.dart';
import 'peer_transport.dart';

/// Shared native platform bridge (`com.albaron.iraqi_domino/nearby_p2p`)
/// driving:
/// - **Bluetooth** RFCOMM stream sockets on Android & MultipeerConnectivity on iOS.
/// - **Wi-Fi Direct** (`WifiP2pManager`) autonomous P2P group helper on Android.
///
/// Zero third-party plugins: talks directly to `NearbyP2pBridge.kt` (Android)
/// and `NearbyP2pBridge.swift` (iOS).
class NativeP2pBridgeClient {
  const NativeP2pBridgeClient._();

  static const MethodChannel _method = MethodChannel(
    'com.albaron.iraqi_domino/nearby_p2p',
  );
  static const EventChannel _events = EventChannel(
    'com.albaron.iraqi_domino/nearby_p2p_events',
  );

  static Stream<Map<Object?, Object?>>? _sharedEvents;

  static Stream<Map<Object?, Object?>> get events {
    return _sharedEvents ??= _events
        .receiveBroadcastStream()
        .where((e) => e is Map<Object?, Object?>)
        .cast<Map<Object?, Object?>>();
  }

  static Future<bool> requestPermissions(SessionChannel channel) async {
    try {
      final granted = await _method.invokeMethod<bool>('requestPermissions', {
        'channel': channel.id,
      });
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> tryEnsureWifiDirectGroup() async {
    try {
      await _method.invokeMethod<void>('ensureWifiDirectGroup');
    } catch (_) {}
  }

  static Future<void> tryDiscoverWifiDirectPeers() async {
    try {
      await _method.invokeMethod<void>('discoverWifiDirectPeers');
    } catch (_) {}
  }

  static Future<void> tryRemoveWifiDirectGroup() async {
    try {
      await _method.invokeMethod<void>('removeWifiDirectGroup');
    } catch (_) {}
  }

  static Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    final res = await _method.invokeMethod<Map<Object?, Object?>>(method, args);
    return res ?? const {};
  }
}

/// Bluetooth P2P Host transport implementing [PeerHostTransport] with the exact
/// same line-delimited JSON framing and sub-25ms stream performance as Wi-Fi.
class NativeBluetoothHostTransport implements PeerHostTransport {
  @override
  SessionChannel get channel => SessionChannel.bluetooth;

  String _roomCode = '';
  String _endpointLabel = 'Bluetooth';

  final _frames = StreamController<PeerInboundFrame>.broadcast();
  final _connected = StreamController<String>.broadcast();
  final _disconnected = StreamController<String>.broadcast();
  StreamSubscription<Map<Object?, Object?>>? _sub;

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
    final ok = await NativeP2pBridgeClient.requestPermissions(channel);
    if (!ok) {
      throw StateError('يرجى السماح بصلاحيات البلوتوث لإنشاء طاولة قريبة');
    }

    _sub = NativeP2pBridgeClient.events.listen(_onNativeEvent);

    final autoCode = (preferredRoomCode != null && preferredRoomCode.isNotEmpty)
        ? preferredRoomCode
        : '1000';
    final info = await NativeP2pBridgeClient.invoke('startBluetoothHost', {
      'hostName': '$hostName (#$autoCode)',
      'roomCode': autoCode,
      'playerCount': playerCount,
      'targetScore': targetScore,
    });

    _roomCode = autoCode;
    _endpointLabel = (info['deviceName'] as String?) ?? 'Bluetooth';
    return _roomCode;
  }

  void _onNativeEvent(Map<Object?, Object?> event) {
    if (event['role'] != 'host') return;
    final type = event['type'] as String?;
    final peerId = event['peerId'] as String?;
    if (peerId == null) return;

    switch (type) {
      case 'peerConnected':
        if (!_connected.isClosed) _connected.add(peerId);
      case 'peerDisconnected':
        if (!_disconnected.isClosed) _disconnected.add(peerId);
      case 'frame':
        final payload = event['payload'] as String?;
        if (payload != null && payload.isNotEmpty && !_frames.isClosed) {
          _frames.add(PeerInboundFrame(peerId: peerId, payload: payload));
        }
    }
  }

  @override
  void updateAdvertisement({required int occupiedHumans}) {
    NativeP2pBridgeClient.invoke('updateBluetoothAdvertisement', {
      'occupiedHumans': occupiedHumans,
    }).ignore();
  }

  @override
  Future<void> sendToPeer(String peerId, String payload) async {
    await NativeP2pBridgeClient.invoke('sendToPeer', {
      'peerId': peerId,
      'payload': payload,
    });
  }

  @override
  Future<void> broadcast(String payload) async {
    await NativeP2pBridgeClient.invoke('broadcast', {'payload': payload});
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await NativeP2pBridgeClient.invoke('stopBluetoothHost');
    } catch (_) {}
    await _frames.close();
    await _connected.close();
    await _disconnected.close();
  }
}

/// Bluetooth P2P Client transport implementing [PeerClientTransport].
class NativeBluetoothClientTransport implements PeerClientTransport {
  @override
  SessionChannel get channel => SessionChannel.bluetooth;

  final Map<String, DiscoveredRoom> _found = {};
  final _rooms = StreamController<List<DiscoveredRoom>>.broadcast();
  final _frames = StreamController<String>.broadcast();
  final _disconnected = StreamController<void>.broadcast();
  StreamSubscription<Map<Object?, Object?>>? _sub;

  @override
  Stream<List<DiscoveredRoom>> get discoveredRooms => _rooms.stream;

  @override
  Stream<String> get frames => _frames.stream;

  @override
  Stream<void> get disconnected => _disconnected.stream;

  @override
  Future<void> startDiscovery() async {
    final ok = await NativeP2pBridgeClient.requestPermissions(channel);
    if (!ok) {
      throw StateError('يرجى السماح بصلاحيات البلوتوث للبحث عن طاولات قريبة');
    }
    await _sub?.cancel();
    _sub = NativeP2pBridgeClient.events.listen(_onNativeEvent);
    _found.clear();
    await NativeP2pBridgeClient.invoke('startBluetoothDiscovery');
  }

  void _onNativeEvent(Map<Object?, Object?> event) {
    final role = event['role'] as String?;
    final type = event['type'] as String?;

    if (type == 'deviceFound') {
      final endpoint = (event['endpoint'] as String?) ?? '';
      if (endpoint.isEmpty) return;
      final name = (event['hostName'] as String?) ?? 'جهاز بلوتوث';
      final matchCode = RegExp(r'#(\d{4})').firstMatch(name)?.group(1);
      final room = DiscoveredRoom(
        roomId: endpoint,
        roomCode: matchCode ?? (event['roomCode'] as String?) ?? endpoint,
        hostName: name,
        channel: SessionChannel.bluetooth,
        playerCount: (event['playerCount'] as num?)?.toInt() ?? 4,
        occupiedHumans: (event['occupiedHumans'] as num?)?.toInt() ?? 1,
        targetScore: (event['targetScore'] as num?)?.toInt() ?? 151,
        endpoint: endpoint,
        lastSeenMs: DateTime.now().millisecondsSinceEpoch,
      );
      _found[endpoint] = room;
      if (!_rooms.isClosed) _rooms.add(_found.values.toList());
      return;
    }

    if (role != 'client') return;
    switch (type) {
      case 'frame':
        final payload = event['payload'] as String?;
        if (payload != null && payload.isNotEmpty && !_frames.isClosed) {
          _frames.add(payload);
        }
      case 'disconnected':
        if (!_disconnected.isClosed) _disconnected.add(null);
    }
  }

  @override
  Future<void> stopDiscovery() async {
    try {
      await NativeP2pBridgeClient.invoke('stopBluetoothDiscovery');
    } catch (_) {}
  }

  @override
  Future<void> connect({DiscoveredRoom? room, String? codeOrEndpoint}) async {
    await stopDiscovery();
    _sub ??= NativeP2pBridgeClient.events.listen(_onNativeEvent);
    var target = room?.endpoint ?? '';
    if (target.isEmpty && codeOrEndpoint != null) {
      final clean = codeOrEndpoint.trim();
      for (final r in _found.values) {
        if (r.roomCode == clean || r.endpoint == clean || r.hostName.contains(clean)) {
          target = r.endpoint;
          break;
        }
      }
      if (target.isEmpty && _found.length == 1 && RegExp(r'^\d{4}$').hasMatch(clean)) {
        // Single paired/nearby Bluetooth host found: connect & verify roomCode in Hello!
        target = _found.values.first.endpoint;
      }
      if (target.isEmpty) target = clean;
    }
    if (target.isEmpty) {
      throw ArgumentError('يرجى اختيار غرفة متاحة أو التأكد من رقم الغرفة');
    }
    await NativeP2pBridgeClient.invoke('connectBluetoothHost', {
      'endpoint': target,
    });
  }

  @override
  Future<void> send(String payload) async {
    await NativeP2pBridgeClient.invoke('clientSend', {'payload': payload});
  }

  @override
  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await NativeP2pBridgeClient.invoke('disconnectBluetoothClient');
    } catch (_) {}
    if (!_disconnected.isClosed) _disconnected.add(null);
  }
}
