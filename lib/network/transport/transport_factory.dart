import '../protocol/connection_channel.dart';
import 'lan_socket_transport.dart';
import 'native_p2p_transport.dart';
import 'peer_transport.dart';

/// Central factory instantiating the appropriate [PeerHostTransport] or
/// [PeerClientTransport] for any of the 3 Local Multiplayer mediums (and ready
/// to plug in `OnlineWebSocketTransport` in Phase 7).
class TransportFactory {
  const TransportFactory._();

  static PeerHostTransport createHost(SessionChannel channel) =>
      switch (channel) {
        SessionChannel.localWifi => LanSocketHostTransport(
          channel: SessionChannel.localWifi,
        ),
        SessionChannel.wifiOffline => LanSocketHostTransport(
          channel: SessionChannel.wifiOffline,
        ),
        SessionChannel.bluetooth => NativeBluetoothHostTransport(),
        _ => throw UnsupportedError('Host transport not local: $channel'),
      };

  static PeerClientTransport createClient(SessionChannel channel) =>
      switch (channel) {
        SessionChannel.localWifi => LanSocketClientTransport(
          channel: SessionChannel.localWifi,
        ),
        SessionChannel.wifiOffline => LanSocketClientTransport(
          channel: SessionChannel.wifiOffline,
        ),
        SessionChannel.bluetooth => NativeBluetoothClientTransport(),
        _ => throw UnsupportedError('Client transport not local: $channel'),
      };
}
