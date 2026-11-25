import 'dart:async';

import '../../data/player_account.dart';
import '../../engine/board.dart';
import '../../engine/domino_piece.dart';
import '../protocol/wire_messages.dart';
import '../transport/peer_transport.dart';

/// Pure-Dart client session connecting a player's [PublicPlayerProfile] from
/// `GameDataCenter` to a local or online [AuthoritativeRoomHost].
class RoomClientSession {
  RoomClientSession({
    required this.transport,
    required this.playerProfile,
  });

  final PeerClientTransport transport;
  final PublicPlayerProfile playerProfile;

  final _lobbyChanges = StreamController<RoomLobbyState>.broadcast();
  final _matchChanges = StreamController<MaskedMatchPayload>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _closed = StreamController<void>.broadcast();

  Stream<RoomLobbyState> get lobbyStream => _lobbyChanges.stream;
  Stream<MaskedMatchPayload> get matchStream => _matchChanges.stream;
  Stream<String> get errorStream => _errors.stream;
  Stream<void> get closedStream => _closed.stream;

  RoomLobbyState? _latestLobby;
  MaskedMatchPayload? _latestMatch;

  RoomLobbyState? get currentLobby => _latestLobby;
  MaskedMatchPayload? get currentMatch => _latestMatch;

  StreamSubscription<String>? _frameSub;
  StreamSubscription<void>? _discSub;
  bool _disposed = false;

  /// Connects to [room] or [codeOrEndpoint] and immediately sends the player's
  /// unified identity handshake (`hello`).
  Future<void> connectAndJoin({
    DiscoveredRoom? room,
    String? codeOrEndpoint,
  }) async {
    await transport.connect(room: room, codeOrEndpoint: codeOrEndpoint);
    _frameSub = transport.frames.listen(_onFrame);
    _discSub = transport.disconnected.listen((_) {
      if (!_disposed && !_closed.isClosed) _closed.add(null);
    });

    final cleanCode = codeOrEndpoint?.trim() ?? '';
    final is4DigitRoomCode = RegExp(r'^\d{4}$').hasMatch(cleanCode);

    await transport.send(
      WireEnvelope(
        type: WireEnvelope.tHello,
        data: {
          'profile': playerProfile.toJson(),
          if (room != null)
            'roomCode': room.roomCode
          else if (is4DigitRoomCode)
            'roomCode': cleanCode,
        },
      ).encode(),
    );
  }

  Future<void> pickSeat(int canonicalSeat) => transport.send(
    WireEnvelope(
      type: WireEnvelope.tPickSeat,
      data: {'seat': canonicalSeat},
    ).encode(),
  );

  Future<void> toggleReady() => transport.send(
    const WireEnvelope(type: WireEnvelope.tToggleReady).encode(),
  );

  /// Used when this client is the creator of a server-hosted online room.
  Future<void> requestStartMatch() => transport.send(
    const WireEnvelope(type: 'start_match').encode(),
  );

  Future<void> playMove(DominoPiece piece, BoardEnd end) => transport.send(
    WireEnvelope(
      type: WireEnvelope.tPlayMove,
      data: {
        'low': piece.low,
        'high': piece.high,
        'end': end == BoardEnd.left ? 'L' : 'R',
      },
    ).encode(),
  );

  Future<void> drawSlot(int slotIndex) => transport.send(
    WireEnvelope(
      type: WireEnvelope.tDrawSlot,
      data: {'slot': slotIndex},
    ).encode(),
  );

  Future<void> requestResetMatch() => transport.send(
    const WireEnvelope(type: WireEnvelope.tResetMatch).encode(),
  );

  void _onFrame(String raw) {
    if (_disposed) return;
    final env = WireEnvelope.tryDecode(raw);
    if (env == null) return;

    switch (env.type) {
      case WireEnvelope.tLobbyState:
        final lobby = RoomLobbyState.fromJson(env.data);
        _latestLobby = lobby;
        if (!_lobbyChanges.isClosed) _lobbyChanges.add(lobby);

      case WireEnvelope.tMatchSnapshot:
        final snap = MaskedMatchPayload.fromJson(env.data);
        _latestMatch = snap;
        if (!_matchChanges.isClosed) _matchChanges.add(snap);

      case WireEnvelope.tError:
        final msg = (env.data['message'] as String?) ?? 'حدث خطأ في الاتصال';
        if (!_errors.isClosed) _errors.add(msg);

      case WireEnvelope.tRoomClosed:
        if (!_closed.isClosed) _closed.add(null);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await transport.send(
        const WireEnvelope(type: WireEnvelope.tLeave).encode(),
      );
    } catch (_) {}
    await _frameSub?.cancel();
    await _discSub?.cancel();
    await transport.disconnect();
    await _lobbyChanges.close();
    await _matchChanges.close();
    await _errors.close();
    await _closed.close();
  }
}
