import 'dart:async';
import 'dart:math';

import '../../ai/ai_persona.dart';
import '../../ai/domino_ai.dart';
import '../../data/player_account.dart';
import '../../engine/board.dart';
import '../../engine/domino_piece.dart';
import '../../engine/game_rules_config.dart';
import '../../engine/match_state.dart';
import '../../engine/match_view_state.dart';
import '../../engine/round_result.dart';
import '../../engine/seat_occupant.dart';
import '../protocol/seat_mapper.dart';
import '../protocol/wire_messages.dart';
import '../transport/peer_transport.dart';

/// Authoritative room & match host engine. Pure Dart (no Flutter imports!).
///
/// Runs identically on:
/// - The host phone in **Offline Wi-Fi**, **Bluetooth**, and **Local Wi-Fi**.
/// - A dedicated **Dart WebSocket Room Worker** in Phase 7 Online Multiplayer.
///
/// Guarantees:
/// - Single source of truth for dealing, legal moves, timers, and scoring.
/// - Per-seat anti-cheat masking (`MaskedMatchPayload`) + automatic rotation
///   so every human player sees themselves at local seat `0`.
/// - Seamless `AiPersona` bot takeover when a peer disconnects, and instant
///   seat reclaim if the same `playerId` reconnects (or hot-join before 65%).
class AuthoritativeRoomHost {
  AuthoritativeRoomHost({
    required this.transport,
    required this.hostProfile,
    required this.playerCount,
    required this.rules,
    Random? random,
    this.aiDelay = const Duration(milliseconds: 520),
    this.passDelay = const Duration(milliseconds: 850),
    this.drawDelay = const Duration(milliseconds: 420),
    this.revealDelay = const Duration(milliseconds: 2200),
    this.turnSeconds = 30,
  }) : assert(playerCount == 2 || playerCount == 4),
       _random = random ?? Random();

  static const int _boneyardTableSlots = 14;

  final PeerHostTransport transport;
  final PublicPlayerProfile hostProfile;
  final int playerCount;
  final GameRulesConfig rules;
  final Random _random;

  final Duration aiDelay;
  final Duration passDelay;
  final Duration drawDelay;
  final Duration revealDelay;
  final int turnSeconds;

  final _lobbyChanges = StreamController<RoomLobbyState>.broadcast();
  final _hostViewChanges = StreamController<MaskedMatchPayload>.broadcast();

  Stream<RoomLobbyState> get lobbyStream => _lobbyChanges.stream;
  Stream<MaskedMatchPayload> get hostMatchStream => _hostViewChanges.stream;

  RoomLobbyState? _latestLobby;
  MaskedMatchPayload? _latestHostPayload;

  RoomLobbyState? get currentLobby => _latestLobby;
  MaskedMatchPayload? get currentHostPayload => _latestHostPayload;

  late List<LobbySeatSlot> _seats;
  final Map<String, String> _peerToPlayerId = {};
  final Map<String, String> _playerToPeerId = {};

  MatchState? _match;
  List<DominoPiece?> _boneyardSlots = const [];
  DominoPiece? _lastPlayedPiece;
  MatchStatus? _status;
  bool _revealingRound = false;
  bool _showResultPending = false;
  int _secondsLeft = 30;
  int _revision = 0;
  bool _disposed = false;

  Timer? _actionTimer;
  Timer? _turnTimer;
  StreamSubscription<PeerInboundFrame>? _frameSub;
  StreamSubscription<String>? _discSub;

  /// Initializes the lobby with the Host seated at canonical seat `0` and
  /// distinct [AiPersona] bots assigned to the remaining seats.
  Future<RoomLobbyState> startRoom() async {
    final bots = AiPersona.pickDistinct(playerCount, _random);
    _seats = [
      LobbySeatSlot(
        seat: 0,
        humanProfile: hostProfile,
        botPersonaId: bots[0].id,
        ready: true,
        isHost: true,
      ),
      for (var i = 1; i < playerCount; i++)
        LobbySeatSlot(seat: i, botPersonaId: bots[i].id),
    ];

    final autoRoomNumber = (1000 + _random.nextInt(9000)).toString();
    final code = await transport.start(
      hostName: hostProfile.displayName,
      playerCount: playerCount,
      targetScore: rules.targetScore,
      preferredRoomCode: autoRoomNumber,
    );

    _frameSub = transport.frames.listen(_onPeerFrame);
    _discSub = transport.peerDisconnected.listen(_onPeerDisconnected);

    _broadcastLobby(roomCodeOverride: code);
    return _latestLobby!;
  }

  /// Host selects a different canonical seat (`0..playerCount-1`) in the lobby
  /// (for example, swapping seats in 4-player mode to team up with a friend).
  void hostPickSeat(int targetSeat) {
    if (_match != null) return;
    _assignPlayerToSeat(hostProfile, targetSeat, isHost: true);
    _broadcastLobby();
  }

  /// Starts the authoritative match from the current lobby seating.
  void startMatch() {
    if (_match != null || _disposed) return;
    _match = MatchState(
      playerCount: playerCount,
      rules: rules,
      random: _random,
    );
    _initBoneyardSlots();
    _broadcastLobby();
    _prepareTurn(soundEvent: null);
    _broadcastMatchSnapshots(soundEvent: null);
  }

  /// Host submits a move from their own local view (`localEnd` = board end).
  void hostPlayMove(DominoPiece piece, BoardEnd end) {
    _handlePlayerMove(hostProfile.playerId, piece, end);
  }

  /// Host draws a boneyard slot (`0..13`) in 2-player mode.
  void hostDrawSlot(int slotIndex) {
    _handlePlayerDraw(hostProfile.playerId, slotIndex);
  }

  /// Host resets the match ("العب مجدداً") after match end.
  void hostResetMatch() {
    _handleResetMatch(hostProfile.playerId);
  }

  // ---------------------------------------------------------------------------
  // Inbound Peer Protocol Handling
  // ---------------------------------------------------------------------------

  void _onPeerFrame(PeerInboundFrame frame) {
    if (_disposed) return;
    final env = WireEnvelope.tryDecode(frame.payload);
    if (env == null) return;

    switch (env.type) {
    case WireEnvelope.tHello:
        final reqCode = (env.data['roomCode'] as String?)?.trim();
        if (reqCode != null &&
            reqCode.isNotEmpty &&
            _latestLobby != null &&
            reqCode != _latestLobby!.roomCode) {
          transport.sendToPeer(
            frame.peerId,
            const WireEnvelope(
              type: WireEnvelope.tError,
              data: {'message': 'رقم الغرفة غير مطابق لهذه الطاولة'},
            ).encode(),
          );
          return;
        }
        final profileMap = env.data['profile'];
        if (profileMap is! Map<String, Object?>) return;
        final profile = PublicPlayerProfile.fromJson(profileMap);
        _onPeerHello(frame.peerId, profile);

      case WireEnvelope.tPickSeat:
        final playerId = _peerToPlayerId[frame.peerId];
        final seat = (env.data['seat'] as num?)?.toInt();
        if (playerId == null || seat == null || _match != null) return;
        final currentSeat = _seatIndexOf(playerId);
        if (currentSeat == null) return;
        final profile = _seats[currentSeat].humanProfile!;
        _assignPlayerToSeat(profile, seat, isHost: false);
        _broadcastLobby();

      case WireEnvelope.tToggleReady:
        final playerId = _peerToPlayerId[frame.peerId];
        if (playerId == null || _match != null) return;
        final idx = _seatIndexOf(playerId);
        if (idx == null) return;
        _seats[idx] = _seats[idx].copyWith(ready: !_seats[idx].ready);
        _broadcastLobby();

      case WireEnvelope.tPlayMove:
        final playerId = _peerToPlayerId[frame.peerId];
        if (playerId == null) return;
        final low = (env.data['low'] as num?)?.toInt();
        final high = (env.data['high'] as num?)?.toInt();
        final endStr = env.data['end'] as String?;
        if (low == null || high == null || endStr == null) return;
        final l = low <= high ? low : high;
        final h = low <= high ? high : low;
        if (l < 0 || h > 6) return;
        _handlePlayerMove(
          playerId,
          DominoPiece(l, h),
          endStr == 'L' ? BoardEnd.left : BoardEnd.right,
        );

      case WireEnvelope.tDrawSlot:
        final playerId = _peerToPlayerId[frame.peerId];
        final slot = (env.data['slot'] as num?)?.toInt();
        if (playerId == null || slot == null) return;
        _handlePlayerDraw(playerId, slot);

      case WireEnvelope.tResetMatch:
        final playerId = _peerToPlayerId[frame.peerId];
        if (playerId != null) _handleResetMatch(playerId);

      case WireEnvelope.tLeave:
        _onPeerDisconnected(frame.peerId);
    }
  }

  void _onPeerHello(String peerId, PublicPlayerProfile profile) {
    _peerToPlayerId[peerId] = profile.playerId;
    _playerToPeerId[profile.playerId] = peerId;

    // 1. Reconnect check: did this exact playerId already hold a seat?
    final existingIdx = _seatIndexOf(profile.playerId);
    if (existingIdx != null) {
      _seats[existingIdx] = _seats[existingIdx].copyWith(
        humanProfile: profile,
        disconnected: false,
        ready: true,
      );
      _broadcastLobby();
      if (_match != null) {
        _sendSnapshotToPeer(peerId, existingIdx, soundEvent: null);
        // Broadcast updated seat names/badges to everyone else too.
        _broadcastMatchSnapshots(soundEvent: null);
      }
      return;
    }

    // 2. Active match hot-join check (allowed before 65% endgame cutoff).
    if (_match != null) {
      if (!_canAcceptHumanJoin) {
        transport.sendToPeer(
          peerId,
          const WireEnvelope(
            type: WireEnvelope.tError,
            data: {'message': 'المباراة في مراحلها الأخيرة ولا تقبل انضماماً جديداً'},
          ).encode(),
        );
        return;
      }
      final botIdx = _seats.indexWhere((s) => s.isBot || s.disconnected);
      if (botIdx == -1) {
        transport.sendToPeer(
          peerId,
          const WireEnvelope(
            type: WireEnvelope.tError,
            data: {'message': 'الطاولة ممتلئة بالكامل'},
          ).encode(),
        );
        return;
      }
      _seats[botIdx] = _seats[botIdx].copyWith(
        humanProfile: profile,
        disconnected: false,
        ready: true,
      );
      _broadcastLobby();
      _broadcastMatchSnapshots(soundEvent: null);
      return;
    }

    // 3. Pre-match lobby join: place in first available bot seat.
    final freeIdx = _seats.indexWhere((s) => s.isBot);
    if (freeIdx == -1) {
      transport.sendToPeer(
        peerId,
        const WireEnvelope(
          type: WireEnvelope.tError,
          data: {'message': 'الطاولة ممتلئة بالكامل'},
        ).encode(),
      );
      return;
    }

    _seats[freeIdx] = _seats[freeIdx].copyWith(
      humanProfile: profile,
      disconnected: false,
      ready: true,
    );
    _broadcastLobby();
  }

  void _onPeerDisconnected(String peerId) {
    if (_disposed) return;
    final playerId = _peerToPlayerId.remove(peerId);
    if (playerId == null) return;
    _playerToPeerId.remove(playerId);

    final idx = _seatIndexOf(playerId);
    if (idx == null) return;

    if (_match == null) {
      // In lobby: free the seat back to its AI persona bot.
      _seats[idx] = _seats[idx].copyWith(
        clearHuman: true,
        ready: false,
        disconnected: false,
      );
      _broadcastLobby();
      return;
    }

    // During an active match: mark disconnected so the AI persona bot
    // immediately takes over without stalling the round, while keeping
    // humanProfile.playerId reserved if the friend reconnects!
    _seats[idx] = _seats[idx].copyWith(disconnected: true);
    _broadcastLobby();

    final match = _match!;
    if (!match.round.isOver && match.round.turn == idx) {
      _prepareTurn(soundEvent: null);
    }
    _broadcastMatchSnapshots(soundEvent: null);
  }

  void _assignPlayerToSeat(
    PublicPlayerProfile profile,
    int targetSeat, {
    required bool isHost,
  }) {
    if (targetSeat < 0 || targetSeat >= playerCount) return;
    final currentSeat = _seatIndexOf(profile.playerId);
    if (currentSeat == targetSeat) return;

    final targetSlot = _seats[targetSeat];
    // Only move into a bot-held seat (don't kick another connected human).
    if (targetSlot.isHuman && !targetSlot.disconnected) return;

    if (currentSeat != null) {
      _seats[currentSeat] = _seats[currentSeat].copyWith(
        clearHuman: true,
        ready: false,
        isHost: false,
        disconnected: false,
      );
    }
    _seats[targetSeat] = _seats[targetSeat].copyWith(
      humanProfile: profile,
      ready: true,
      isHost: isHost,
      disconnected: false,
    );
  }

  int? _seatIndexOf(String playerId) {
    for (var i = 0; i < _seats.length; i++) {
      if (_seats[i].humanProfile?.playerId == playerId) return i;
    }
    return null;
  }

  bool _isLiveHumanSeat(int canonicalSeat) {
    final slot = _seats[canonicalSeat];
    return slot.isHuman && !slot.disconnected;
  }

  bool get _canAcceptHumanJoin {
    final match = _match;
    if (match == null) return true;
    return SeatOccupant.canAcceptHumanJoin(
      scores: match.scores,
      targetScore: rules.targetScore,
      isMatchOver: match.isOver,
    );
  }

  // ---------------------------------------------------------------------------
  // Authoritative Match Execution & Timers
  // ---------------------------------------------------------------------------

  void _handlePlayerMove(String playerId, DominoPiece piece, BoardEnd end) {
    final match = _match;
    if (match == null || match.round.isOver) return;
    final seat = _seatIndexOf(playerId);
    if (seat == null || !_isLiveHumanSeat(seat)) return;
    if (match.round.turn != seat) return;

    final move = Move(piece, end);
    final legal = match.legalMoves();
    if (!legal.contains(move)) return;

    _lastPlayedPiece = piece;
    match.play(move);
    _prepareTurn(soundEvent: 'place');
    _broadcastMatchSnapshots(soundEvent: 'place');
  }

  void _handlePlayerDraw(String playerId, int slotIndex) {
    final match = _match;
    if (match == null || match.round.isOver || playerCount != 2) return;
    final seat = _seatIndexOf(playerId);
    if (seat == null || !_isLiveHumanSeat(seat)) return;
    if (match.round.turn != seat || match.legalMoves().isNotEmpty) return;
    if (slotIndex < 0 || slotIndex >= _boneyardSlots.length) return;

    final piece = _boneyardSlots[slotIndex];
    if (piece == null) return;
    final idx = match.round.boneyard.indexOf(piece);
    if (idx == -1) return;

    match.draw(idx);
    _boneyardSlots[slotIndex] = null;
    _prepareTurn(soundEvent: 'draw');
    _broadcastMatchSnapshots(soundEvent: 'draw');
  }

  void _handleResetMatch(String playerId) {
    final match = _match;
    if (match == null || !match.isOver) return;
    // Allow the host (or any seated human after match over) to trigger replay.
    if (_seatIndexOf(playerId) == null) return;
    _showResultPending = false;
    _revealingRound = false;
    _lastPlayedPiece = null;
    match.resetMatch();
    _initBoneyardSlots();
    _prepareTurn(soundEvent: null);
    _broadcastMatchSnapshots(soundEvent: null);
  }

  void _initBoneyardSlots() {
    final match = _match;
    if (match == null || playerCount != 2) {
      _boneyardSlots = const [];
      return;
    }
    final remaining = match.round.boneyard;
    final pad = max(0, _boneyardTableSlots - remaining.length);
    _boneyardSlots = <DominoPiece?>[
      ...remaining,
      ...List<DominoPiece?>.filled(pad, null),
    ];
  }

  void _cancelTimers() {
    _actionTimer?.cancel();
    _turnTimer?.cancel();
  }

  void _schedule(Duration delay, void Function() fn) {
    _actionTimer?.cancel();
    _actionTimer = Timer(delay, () {
      if (!_disposed) fn();
    });
  }

  void _prepareTurn({required String? soundEvent}) {
    _cancelTimers();
    _revealingRound = false;
    _showResultPending = false;

    final match = _match!;
    final round = match.round;

    if (round.isOver) {
      _status = null;
      _revealingRound = true;
      _schedule(revealDelay, () {
        if (match.isOver) {
          _showResultPending = true;
          _broadcastMatchSnapshots(soundEvent: null);
        } else {
          _revealingRound = false;
          _lastPlayedPiece = null;
          match.startNextRound();
          _initBoneyardSlots();
          _prepareTurn(soundEvent: null);
          _broadcastMatchSnapshots(soundEvent: null);
        }
      });
      return;
    }

    final seat = round.turn;
    final moves = match.legalMoves();

    if (moves.isEmpty) {
      final canDraw = playerCount == 2 && round.boneyard.isNotEmpty;
      if (canDraw && _isLiveHumanSeat(seat)) {
        _status = null;
        _startHumanTurnTimer(seat, isDrawing: true);
        return;
      }

      _status = MatchStatus(
        seat: seat,
        kind: canDraw
            ? MatchStatusKind.draws
            : (playerCount == 4
                  ? MatchStatusKind.noTiles
                  : MatchStatusKind.passes),
      );
      _schedule(canDraw ? drawDelay : passDelay, () {
        if (canDraw) {
          final drawn = match.draw();
          final idx = _boneyardSlots.indexOf(drawn);
          if (idx != -1) _boneyardSlots[idx] = null;
          _prepareTurn(soundEvent: 'draw');
          _broadcastMatchSnapshots(soundEvent: 'draw');
        } else {
          match.pass();
          _prepareTurn(soundEvent: 'pass');
          _broadcastMatchSnapshots(soundEvent: 'pass');
        }
      });
      return;
    }

    _status = null;
    if (_isLiveHumanSeat(seat)) {
      _startHumanTurnTimer(seat, isDrawing: false);
    } else {
      _schedule(aiDelay, () {
        final aiMove = DominoAi.chooseMove(
          match.round,
          difficulty: rules.aiDifficulty,
        );
        _lastPlayedPiece = aiMove.piece;
        match.play(aiMove);
        _prepareTurn(soundEvent: 'place');
        _broadcastMatchSnapshots(soundEvent: 'place');
      });
    }
  }

  void _startHumanTurnTimer(int canonicalSeat, {required bool isDrawing}) {
    _turnTimer?.cancel();
    _secondsLeft = turnSeconds;
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      _secondsLeft--;
      if (_secondsLeft <= 0) {
        timer.cancel();
        final match = _match;
        if (match == null || match.round.isOver || match.round.turn != canonicalSeat) {
          return;
        }
        if (isDrawing && match.round.boneyard.isNotEmpty) {
          final drawn = match.draw();
          final idx = _boneyardSlots.indexOf(drawn);
          if (idx != -1) _boneyardSlots[idx] = null;
          _prepareTurn(soundEvent: 'draw');
          _broadcastMatchSnapshots(soundEvent: 'draw');
        } else if (match.legalMoves().isNotEmpty) {
          final autoMove = DominoAi.chooseMove(
            match.round,
            difficulty: rules.aiDifficulty,
          );
          _lastPlayedPiece = autoMove.piece;
          match.play(autoMove);
          _prepareTurn(soundEvent: 'place');
          _broadcastMatchSnapshots(soundEvent: 'place');
        }
      } else {
        _broadcastMatchSnapshots(soundEvent: null);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Broadcasting & Per-Viewer Anti-Cheat Masking + Seat Rotation
  // ---------------------------------------------------------------------------

  void _broadcastLobby({String? roomCodeOverride}) {
    final code = roomCodeOverride ?? transport.roomCode;
    final lobby = RoomLobbyState(
      roomCode: code,
      channel: transport.channel,
      hostPlayerId: hostProfile.playerId,
      playerCount: playerCount,
      rules: rules,
      seats: List<LobbySeatSlot>.unmodifiable(_seats),
      matchStarted: _match != null,
    );
    _latestLobby = lobby;
    transport.updateAdvertisement(occupiedHumans: lobby.humanCount);
    if (!_lobbyChanges.isClosed) _lobbyChanges.add(lobby);

    final msg = WireEnvelope(
      type: WireEnvelope.tLobbyState,
      data: lobby.toJson(),
    ).encode();
    transport.broadcast(msg);
  }

  void _broadcastMatchSnapshots({required String? soundEvent}) {
    if (_match == null || _disposed) return;
    _revision++;

    // 1. Emit masked & rotated view for the local Host player.
    final hostSeat = _seatIndexOf(hostProfile.playerId) ?? 0;
    final hostPayload = _buildPayloadForSeat(hostSeat, soundEvent: soundEvent);
    _latestHostPayload = hostPayload;
    if (!_hostViewChanges.isClosed) _hostViewChanges.add(hostPayload);

    // 2. Send individually masked & rotated views to each connected peer!
    for (final entry in _peerToPlayerId.entries.toList()) {
      final seat = _seatIndexOf(entry.value);
      if (seat != null) {
        _sendSnapshotToPeer(entry.key, seat, soundEvent: soundEvent);
      }
    }
  }

  void _sendSnapshotToPeer(
    String peerId,
    int viewerCanonicalSeat, {
    required String? soundEvent,
  }) {
    final payload = _buildPayloadForSeat(
      viewerCanonicalSeat,
      soundEvent: soundEvent,
    );
    final frame = WireEnvelope(
      type: WireEnvelope.tMatchSnapshot,
      data: payload.toJson(),
    ).encode();
    transport.sendToPeer(peerId, frame);
  }

  MaskedMatchPayload _buildPayloadForSeat(
    int viewerSeat, {
    required String? soundEvent,
  }) {
    final match = _match!;
    final round = match.round;
    final canHotJoin = _canAcceptHumanJoin;

    final canonicalOccupants = [
      for (final slot in _seats)
        slot.toSeatOccupant(openForHumanJoin: slot.disconnected && canHotJoin),
    ];
    final rotatedSeats = SeatMapper.rotateSeats(
      canonicalOccupants,
      viewerCanonicalSeat: viewerSeat,
    );

    final rotatedHands = SeatMapper.rotateSeats(
      round.hands,
      viewerCanonicalSeat: viewerSeat,
    );

    final isMyTurn = !round.isOver &&
        round.turn == viewerSeat &&
        _isLiveHumanSeat(viewerSeat);
    final legalForViewer = isMyTurn ? match.legalMoves() : const <Move>[];
    final awaitingDraw = isMyTurn &&
        legalForViewer.isEmpty &&
        playerCount == 2 &&
        round.boneyard.isNotEmpty;

    final rotatedStart = SeatMapper.toLocalSeat(
      canonicalSeat: round.startSeat,
      viewerCanonicalSeat: viewerSeat,
      playerCount: playerCount,
    );
    final rotatedTurn = round.isOver
        ? null
        : SeatMapper.toLocalSeat(
            canonicalSeat: round.turn,
            viewerCanonicalSeat: viewerSeat,
            playerCount: playerCount,
          );

    final rotatedStatus = _status == null
        ? null
        : MatchStatus(
            seat: SeatMapper.toLocalSeat(
              canonicalSeat: _status!.seat,
              viewerCanonicalSeat: viewerSeat,
              playerCount: playerCount,
            ),
            kind: _status!.kind,
          );

    final rotatedScores = SeatMapper.rotateTeamScores(
      match.scores,
      viewerCanonicalSeat: viewerSeat,
      playerCount: playerCount,
    );

    final rotatedRoundResult = _rotateRoundResult(round.result, viewerSeat);
    final rotatedHistory = [
      for (final rec in match.history)
        _rotateHistoryRecord(rec, viewerSeat),
    ];

    return MaskedMatchPayload(
      playerCount: playerCount,
      rules: rules,
      seats: rotatedSeats,
      canAcceptHumanJoin: canHotJoin,
      boardMoves: MaskedMatchPayload.extractBoardMoves(round.board),
      myHand: List<DominoPiece>.unmodifiable(rotatedHands[0]),
      otherHandCounts: [
        for (var i = 1; i < playerCount; i++) rotatedHands[i].length,
      ],
      revealedHands: _revealingRound ? rotatedHands : null,
      boneyardCount: round.boneyard.length,
      boneyardSlotPresent: [for (final p in _boneyardSlots) p != null],
      awaitingHumanDraw: awaitingDraw,
      revealingRound: _revealingRound,
      lastPlayedPiece: _lastPlayedPiece,
      startSeat: rotatedStart,
      openingPiece: round.openingPiece,
      turnSeat: rotatedTurn,
      scores: rotatedScores,
      history: rotatedHistory,
      myMoves: legalForViewer,
      secondsLeft: _secondsLeft,
      turnSeconds: turnSeconds,
      status: rotatedStatus,
      roundResult: rotatedRoundResult,
      matchWinnerTeam: SeatMapper.rotateWinnerTeam(
        match.winnerTeam,
        viewerCanonicalSeat: viewerSeat,
        playerCount: playerCount,
      ),
      showResultPending: _showResultPending,
      soundEvent: soundEvent,
      revision: _revision,
    );
  }

  RoundResult? _rotateRoundResult(RoundResult? r, int viewerSeat) {
    if (r == null) return null;
    if (r.kind == RoundEndKind.burned) {
      return const RoundResult(kind: RoundEndKind.burned);
    }
    return RoundResult(
      kind: r.kind,
      winnerSeat: r.winnerSeat == null
          ? null
          : SeatMapper.toLocalSeat(
              canonicalSeat: r.winnerSeat!,
              viewerCanonicalSeat: viewerSeat,
              playerCount: playerCount,
            ),
      winnerTeam: SeatMapper.rotateWinnerTeam(
        r.winnerTeam,
        viewerCanonicalSeat: viewerSeat,
        playerCount: playerCount,
      ),
      points: r.points,
    );
  }

  MatchRoundRecord _rotateHistoryRecord(MatchRoundRecord rec, int viewerSeat) {
    final myTeam = viewerSeat % 2;
    return MatchRoundRecord(
      round: rec.round,
      result: _rotateRoundResult(rec.result, viewerSeat)!,
      ourTotal: myTeam == 0 ? rec.ourTotal : rec.theirTotal,
      theirTotal: myTeam == 0 ? rec.theirTotal : rec.ourTotal,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelTimers();
    await _frameSub?.cancel();
    await _discSub?.cancel();
    await transport.broadcast(
      const WireEnvelope(type: WireEnvelope.tRoomClosed).encode(),
    );
    await transport.stop();
    await _lobbyChanges.close();
    await _hostViewChanges.close();
  }
}
