import 'dart:convert';

import '../../ai/ai_difficulty.dart';
import '../../ai/ai_persona.dart';
import '../../data/player_account.dart';
import '../../engine/board.dart';
import '../../engine/domino_piece.dart';
import '../../engine/game_rules_config.dart';
import '../../engine/match_state.dart';
import '../../engine/match_view_state.dart';
import '../../engine/round_result.dart';
import '../../engine/seat_occupant.dart';
import 'connection_channel.dart';

/// Occupant of one seat inside a pre-match or active room lobby. Pure Dart.
class LobbySeatSlot {
  const LobbySeatSlot({
    required this.seat,
    this.humanProfile,
    this.botPersonaId,
    this.ready = false,
    this.isHost = false,
    this.disconnected = false,
  });

  final int seat;
  final PublicPlayerProfile? humanProfile;
  final String? botPersonaId;
  final bool ready;
  final bool isHost;
  final bool disconnected;

  bool get isHuman => humanProfile != null;
  bool get isBot => humanProfile == null;

  AiPersona get resolvedBotPersona {
    for (final p in AiPersona.all) {
      if (p.id == botPersonaId) return p;
    }
    return AiPersona.all[seat % AiPersona.all.length];
  }

  SeatOccupant toSeatOccupant({bool openForHumanJoin = false}) {
    final profile = humanProfile;
    if (profile != null && !disconnected) {
      return SeatOccupant.human(
        playerId: profile.playerId,
        nameAr: profile.displayName,
        nameEn: profile.displayName,
      );
    }
    return SeatOccupant.bot(
      resolvedBotPersona,
      openForHumanJoin: openForHumanJoin,
    );
  }

  LobbySeatSlot copyWith({
    PublicPlayerProfile? humanProfile,
    bool clearHuman = false,
    String? botPersonaId,
    bool? ready,
    bool? isHost,
    bool? disconnected,
  }) {
    return LobbySeatSlot(
      seat: seat,
      humanProfile: clearHuman ? null : (humanProfile ?? this.humanProfile),
      botPersonaId: botPersonaId ?? this.botPersonaId,
      ready: ready ?? this.ready,
      isHost: isHost ?? this.isHost,
      disconnected: disconnected ?? this.disconnected,
    );
  }

  Map<String, Object?> toJson() => {
    'seat': seat,
    'humanProfile': humanProfile?.toJson(),
    'botPersonaId': botPersonaId,
    'ready': ready,
    'isHost': isHost,
    'disconnected': disconnected,
  };

  factory LobbySeatSlot.fromJson(Map<String, Object?> json) {
    final hp = json['humanProfile'];
    return LobbySeatSlot(
      seat: (json['seat'] as num?)?.toInt() ?? 0,
      humanProfile: hp is Map<String, Object?>
          ? PublicPlayerProfile.fromJson(hp)
          : null,
      botPersonaId: json['botPersonaId'] as String?,
      ready: (json['ready'] as bool?) ?? false,
      isHost: (json['isHost'] as bool?) ?? false,
      disconnected: (json['disconnected'] as bool?) ?? false,
    );
  }
}

/// Complete lobby state broadcast to all peers before (and during) a match.
class RoomLobbyState {
  const RoomLobbyState({
    required this.roomCode,
    required this.channel,
    required this.hostPlayerId,
    required this.playerCount,
    required this.rules,
    required this.seats,
    required this.matchStarted,
  });

  final String roomCode;
  final SessionChannel channel;
  final String hostPlayerId;
  final int playerCount;
  final GameRulesConfig rules;
  final List<LobbySeatSlot> seats;
  final bool matchStarted;

  int? seatOfPlayer(String playerId) {
    for (final s in seats) {
      if (s.humanProfile?.playerId == playerId) return s.seat;
    }
    return null;
  }

  int get humanCount => seats.where((s) => s.isHuman && !s.disconnected).length;

  Map<String, Object?> toJson() => {
    'roomCode': roomCode,
    'channel': channel.id,
    'hostPlayerId': hostPlayerId,
    'playerCount': playerCount,
    'targetScore': rules.targetScore,
    'aiDifficulty': rules.aiDifficulty.id,
    'seats': [for (final s in seats) s.toJson()],
    'matchStarted': matchStarted,
  };

  factory RoomLobbyState.fromJson(Map<String, Object?> json) {
    final rawSeats = json['seats'] as List<Object?>? ?? const [];
    return RoomLobbyState(
      roomCode: (json['roomCode'] as String?) ?? '',
      channel: SessionChannel.byId(json['channel'] as String?),
      hostPlayerId: (json['hostPlayerId'] as String?) ?? '',
      playerCount: (json['playerCount'] as num?)?.toInt() ?? 4,
      rules: GameRulesConfig(
        targetScore: (json['targetScore'] as num?)?.toInt() ?? 151,
        aiDifficulty: AiDifficulty.byId(json['aiDifficulty'] as String?),
      ),
      seats: [
        for (final item in rawSeats)
          if (item is Map<String, Object?>) LobbySeatSlot.fromJson(item),
      ],
      matchStarted: (json['matchStarted'] as bool?) ?? false,
    );
  }
}

/// Anti-cheat masked match snapshot tailored specifically for ONE viewer seat
/// (already rotated via `SeatMapper` so local seat `0` is ALWAYS that viewer!).
///
/// - Opponent hands only contain tile counts during active play; real face-up
///   pieces are only included when [revealingRound] is true.
/// - Boneyard slots only transmit `bool` presence flags (`true` = face-down
///   tile available, `false` = already drawn), never hidden pip values!
class MaskedMatchPayload {
  const MaskedMatchPayload({
    required this.playerCount,
    required this.rules,
    required this.seats,
    required this.canAcceptHumanJoin,
    required this.boardMoves,
    required this.myHand,
    required this.otherHandCounts,
    required this.revealedHands,
    required this.boneyardCount,
    required this.boneyardSlotPresent,
    required this.awaitingHumanDraw,
    required this.revealingRound,
    required this.lastPlayedPiece,
    required this.startSeat,
    required this.openingPiece,
    required this.turnSeat,
    required this.scores,
    required this.history,
    required this.myMoves,
    required this.secondsLeft,
    required this.turnSeconds,
    required this.status,
    required this.roundResult,
    required this.matchWinnerTeam,
    required this.showResultPending,
    required this.soundEvent,
    required this.revision,
  });

  final int playerCount;
  final GameRulesConfig rules;
  final List<SeatOccupant> seats;
  final bool canAcceptHumanJoin;
  final List<Move> boardMoves;
  final List<DominoPiece> myHand;
  final List<int> otherHandCounts;
  final List<List<DominoPiece>>? revealedHands;
  final int boneyardCount;
  final List<bool> boneyardSlotPresent;
  final bool awaitingHumanDraw;
  final bool revealingRound;
  final DominoPiece? lastPlayedPiece;
  final int startSeat;
  final DominoPiece? openingPiece;
  final int? turnSeat;
  final List<int> scores;
  final List<MatchRoundRecord> history;
  final List<Move> myMoves;
  final int secondsLeft;
  final int turnSeconds;
  final MatchStatus? status;
  final RoundResult? roundResult;
  final int? matchWinnerTeam;
  final bool showResultPending;

  /// Optional sound trigger (`'place'`, `'draw'`, `'pass'`, or `null`).
  final String? soundEvent;
  final int revision;

  /// Converts this masked network payload directly into the exact
  /// [MatchViewState] consumed by `GameScreen`.
  MatchViewState toMatchViewState() {
    final board = Board();
    for (final m in boardMoves) {
      board.place(m.piece, m.end);
    }

    final hands = <List<DominoPiece>>[];
    if (revealingRound &&
        revealedHands != null &&
        revealedHands!.length == playerCount) {
      for (final h in revealedHands!) {
        hands.add(List<DominoPiece>.unmodifiable(h));
      }
    } else {
      hands.add(List<DominoPiece>.unmodifiable(myHand));
      for (var i = 1; i < playerCount; i++) {
        final count = (i - 1) < otherHandCounts.length
            ? otherHandCounts[i - 1]
            : 0;
        hands.add(
          List<DominoPiece>.filled(count, const DominoPiece(0, 0)),
        );
      }
    }

    final slots = <DominoPiece?>[
      for (final present in boneyardSlotPresent)
        present ? const DominoPiece(0, 0) : null,
    ];

    return MatchViewState(
      playerCount: playerCount,
      rules: rules,
      seats: List<SeatOccupant>.unmodifiable(seats),
      canAcceptHumanJoin: canAcceptHumanJoin,
      board: board,
      hands: List<List<DominoPiece>>.unmodifiable(hands),
      boneyardCount: boneyardCount,
      boneyardSlots: List<DominoPiece?>.unmodifiable(slots),
      awaitingHumanDraw: awaitingHumanDraw,
      revealingRound: revealingRound,
      lastPlayedPiece: lastPlayedPiece,
      startSeat: startSeat,
      openingPiece: openingPiece,
      turnSeat: turnSeat,
      scores: List<int>.unmodifiable(scores),
      history: List<MatchRoundRecord>.unmodifiable(history),
      myMoves: List<Move>.unmodifiable(myMoves),
      secondsLeft: secondsLeft,
      turnSeconds: turnSeconds,
      status: status,
      roundResult: roundResult,
      matchWinnerTeam: matchWinnerTeam,
      showResultPending: showResultPending,
      revision: revision,
    );
  }

  /// Extracts chronological [Move]s from a [Board] so it can be replayed
  /// identically on any client.
  static List<Move> extractBoardMoves(Board board) {
    if (board.isEmpty) return const [];
    final line = board.line;
    final start = board.startIndex;
    final hist = board.history;
    final out = <Move>[Move(line[start].piece, BoardEnd.right)];
    var r = 0;
    var l = 0;
    for (var i = 1; i < hist.length; i++) {
      if (hist[i] == BoardEnd.right) {
        r++;
        out.add(Move(line[start + r].piece, BoardEnd.right));
      } else {
        l++;
        out.add(Move(line[start - l].piece, BoardEnd.left));
      }
    }
    return out;
  }

  Map<String, Object?> toJson() => {
    'pc': playerCount,
    'ts': rules.targetScore,
    'ai': rules.aiDifficulty.id,
    'seats': [for (final s in seats) _encodeSeatOccupant(s)],
    'cahj': canAcceptHumanJoin,
    'bm': [for (final m in boardMoves) _encodeMove(m)],
    'mh': [for (final p in myHand) _encodePiece(p)],
    'ohc': otherHandCounts,
    'rh': revealedHands == null
        ? null
        : [
            for (final h in revealedHands!)
              [for (final p in h) _encodePiece(p)],
          ],
    'bc': boneyardCount,
    'bsp': boneyardSlotPresent,
    'ahd': awaitingHumanDraw,
    'rr': revealingRound,
    'lpp': lastPlayedPiece == null ? null : _encodePiece(lastPlayedPiece!),
    'ss': startSeat,
    'op': openingPiece == null ? null : _encodePiece(openingPiece!),
    'turn': turnSeat,
    'sc': scores,
    'hist': [for (final rec in history) _encodeHistoryRecord(rec)],
    'mm': [for (final m in myMoves) _encodeMove(m)],
    'sl': secondsLeft,
    'tsec': turnSeconds,
    'st': status == null
        ? null
        : {'s': status!.seat, 'k': status!.kind.name},
    'res': roundResult == null ? null : _encodeRoundResult(roundResult!),
    'mwt': matchWinnerTeam,
    'srp': showResultPending,
    'sfx': soundEvent,
    'rev': revision,
  };

  factory MaskedMatchPayload.fromJson(Map<String, Object?> json) {
    final rawSeats = json['seats'] as List<Object?>? ?? const [];
    final rawBm = json['bm'] as List<Object?>? ?? const [];
    final rawMh = json['mh'] as List<Object?>? ?? const [];
    final rawOhc = json['ohc'] as List<Object?>? ?? const [];
    final rawRh = json['rh'] as List<Object?>?;
    final rawBsp = json['bsp'] as List<Object?>? ?? const [];
    final rawSc = json['sc'] as List<Object?>? ?? const [0, 0];
    final rawHist = json['hist'] as List<Object?>? ?? const [];
    final rawMm = json['mm'] as List<Object?>? ?? const [];
    final rawSt = json['st'] as Map<String, Object?>?;
    final rawRes = json['res'] as Map<String, Object?>?;

    return MaskedMatchPayload(
      playerCount: (json['pc'] as num?)?.toInt() ?? 4,
      rules: GameRulesConfig(
        targetScore: (json['ts'] as num?)?.toInt() ?? 151,
        aiDifficulty: AiDifficulty.byId(json['ai'] as String?),
      ),
      seats: [
        for (final s in rawSeats)
          if (s is Map<String, Object?>) _decodeSeatOccupant(s),
      ],
      canAcceptHumanJoin: (json['cahj'] as bool?) ?? false,
      boardMoves: [
        for (final m in rawBm)
          if (m is List<Object?>) _decodeMove(m),
      ],
      myHand: [
        for (final p in rawMh)
          if (p is List<Object?>) _decodePiece(p),
      ],
      otherHandCounts: [for (final n in rawOhc) (n as num).toInt()],
      revealedHands: rawRh == null
          ? null
          : [
              for (final h in rawRh)
                if (h is List<Object?>)
                  [
                    for (final p in h)
                      if (p is List<Object?>) _decodePiece(p),
                  ],
            ],
      boneyardCount: (json['bc'] as num?)?.toInt() ?? 0,
      boneyardSlotPresent: [for (final b in rawBsp) b == true],
      awaitingHumanDraw: (json['ahd'] as bool?) ?? false,
      revealingRound: (json['rr'] as bool?) ?? false,
      lastPlayedPiece: json['lpp'] is List<Object?>
          ? _decodePiece(json['lpp'] as List<Object?>)
          : null,
      startSeat: (json['ss'] as num?)?.toInt() ?? 0,
      openingPiece: json['op'] is List<Object?>
          ? _decodePiece(json['op'] as List<Object?>)
          : null,
      turnSeat: (json['turn'] as num?)?.toInt(),
      scores: [for (final s in rawSc) (s as num).toInt()],
      history: [
        for (final h in rawHist)
          if (h is Map<String, Object?>) _decodeHistoryRecord(h),
      ],
      myMoves: [
        for (final m in rawMm)
          if (m is List<Object?>) _decodeMove(m),
      ],
      secondsLeft: (json['sl'] as num?)?.toInt() ?? 30,
      turnSeconds: (json['tsec'] as num?)?.toInt() ?? 30,
      status: rawSt == null
          ? null
          : MatchStatus(
              seat: (rawSt['s'] as num?)?.toInt() ?? 0,
              kind: MatchStatusKind.values.firstWhere(
                (v) => v.name == rawSt['k'],
                orElse: () => MatchStatusKind.passes,
              ),
            ),
      roundResult: rawRes == null ? null : _decodeRoundResult(rawRes),
      matchWinnerTeam: (json['mwt'] as num?)?.toInt(),
      showResultPending: (json['srp'] as bool?) ?? false,
      soundEvent: json['sfx'] as String?,
      revision: (json['rev'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Top-level wire envelope used across Local Wi-Fi, Offline Wi-Fi, Bluetooth,
/// and Phase 7 Online WebSockets. Compact single-line JSON.
class WireEnvelope {
  const WireEnvelope({required this.type, this.data = const {}});

  final String type;
  final Map<String, Object?> data;

  // Client -> Host/Server message types
  static const String tHello = 'hello';
  static const String tPickSeat = 'pick_seat';
  static const String tToggleReady = 'toggle_ready';
  static const String tPlayMove = 'play_move';
  static const String tDrawSlot = 'draw_slot';
  static const String tResetMatch = 'reset_match';
  static const String tLeave = 'leave';

  // Host/Server -> Client message types
  static const String tLobbyState = 'lobby_state';
  static const String tMatchSnapshot = 'match_snapshot';
  static const String tError = 'error';
  static const String tRoomClosed = 'room_closed';

  String encode() => jsonEncode({'t': type, 'd': data});

  static WireEnvelope? tryDecode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, Object?>) return null;
      final t = map['t'] as String?;
      if (t == null || t.isEmpty) return null;
      final d = map['d'];
      return WireEnvelope(
        type: t,
        data: d is Map<String, Object?> ? d : const {},
      );
    } catch (_) {
      return null;
    }
  }
}

// -----------------------------------------------------------------------------
// Compact field codecs (keeps frames < 600 bytes for crisp Bluetooth RFCOMM/BLE)
// -----------------------------------------------------------------------------

List<int> _encodePiece(DominoPiece p) => [p.low, p.high];

DominoPiece _decodePiece(List<Object?> a) =>
    DominoPiece((a[0] as num).toInt(), (a[1] as num).toInt());

List<Object> _encodeMove(Move m) => [
  m.piece.low,
  m.piece.high,
  m.end == BoardEnd.left ? 'L' : 'R',
];

Move _decodeMove(List<Object?> a) => Move(
  DominoPiece((a[0] as num).toInt(), (a[1] as num).toInt()),
  a[2] == 'L' ? BoardEnd.left : BoardEnd.right,
);

Map<String, Object?> _encodeSeatOccupant(SeatOccupant s) => {
  'k': s.isHuman ? 'h' : 'b',
  'id': s.playerId,
  'ar': s.nameAr,
  'en': s.nameEn,
  'bot': s.aiPersona?.id,
  'rec': s.reconnecting,
  'open': s.openForHumanJoin,
};

SeatOccupant _decodeSeatOccupant(Map<String, Object?> m) {
  if (m['k'] == 'h') {
    return SeatOccupant.human(
      playerId: m['id'] as String?,
      nameAr: (m['ar'] as String?) ?? 'لاعب',
      nameEn: (m['en'] as String?) ?? 'Player',
      reconnecting: m['rec'] == true,
    );
  }
  final botId = m['bot'] as String?;
  final persona = AiPersona.all.firstWhere(
    (p) => p.id == botId,
    orElse: () => AiPersona.all.first,
  );
  return SeatOccupant.bot(persona, openForHumanJoin: m['open'] == true);
}

Map<String, Object?> _encodeRoundResult(RoundResult r) => {
  'k': r.kind.name,
  'ws': r.winnerSeat,
  'wt': r.winnerTeam,
  'pts': r.points,
};

RoundResult _decodeRoundResult(Map<String, Object?> m) {
  final kind = RoundEndKind.values.firstWhere(
    (k) => k.name == m['k'],
    orElse: () => RoundEndKind.blocked,
  );
  return RoundResult(
    kind: kind,
    winnerSeat: (m['ws'] as num?)?.toInt(),
    winnerTeam: (m['wt'] as num?)?.toInt(),
    points: (m['pts'] as num?)?.toInt() ?? 0,
  );
}

Map<String, Object?> _encodeHistoryRecord(MatchRoundRecord rec) => {
  'r': rec.round,
  'res': _encodeRoundResult(rec.result),
  'our': rec.ourTotal,
  'th': rec.theirTotal,
};

MatchRoundRecord _decodeHistoryRecord(Map<String, Object?> m) =>
    MatchRoundRecord(
      round: (m['r'] as num).toInt(),
      result: _decodeRoundResult(m['res'] as Map<String, Object?>),
      ourTotal: (m['our'] as num).toInt(),
      theirTotal: (m['th'] as num).toInt(),
    );
