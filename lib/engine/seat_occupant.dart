import '../ai/ai_persona.dart';

/// Whether a table seat is currently controlled by a live human player or an
/// AI persona bot.
enum SeatOccupantKind { human, bot }

/// Describes who currently occupies a seat (`0..playerCount-1`) in a match.
///
/// Pure Dart: designed to be shared between offline mode, local Wi-Fi rooms,
/// and the online server where disconnected humans are seamlessly replaced by
/// an [AiPersona] until a new human joins (unless the match is near its end).
class SeatOccupant {
  const SeatOccupant.human({
    this.playerId,
    required this.nameAr,
    required this.nameEn,
    this.reconnecting = false,
  }) : kind = SeatOccupantKind.human,
       aiPersona = null,
       openForHumanJoin = false;

  SeatOccupant.bot(
    AiPersona persona, {
    this.openForHumanJoin = false,
  }) : kind = SeatOccupantKind.bot,
       playerId = null,
       nameAr = persona.nameAr,
       nameEn = persona.nameEn,
       aiPersona = persona,
       reconnecting = false;

  final SeatOccupantKind kind;
  final String? playerId;
  final String nameAr;
  final String nameEn;
  final AiPersona? aiPersona;

  /// True when a human player's connection dropped briefly before AI takeover.
  final bool reconnecting;

  /// True when this bot took over for a human who left/disconnected and the
  /// seat is eligible for matchmaking replacement.
  final bool openForHumanJoin;

  bool get isHuman => kind == SeatOccupantKind.human;
  bool get isBot => kind == SeatOccupantKind.bot;

  String displayName(bool isAr) => isAr ? nameAr : nameEn;

  /// Fraction of `targetScore` at or above which a running match is considered
  /// "near completion", locking out new human hot-joins so no player is dropped
  /// into a nearly-finished game.
  static const double endgameJoinCutoffRatio = 0.65;

  /// Returns true if a match with [scores] and [targetScore] is still early/mid
  /// enough to allow a new human player to replace a temporary AI bot.
  static bool canAcceptHumanJoin({
    required List<int> scores,
    required int targetScore,
    required bool isMatchOver,
  }) {
    if (isMatchOver || targetScore <= 0) return false;
    final cutoff = (targetScore * endgameJoinCutoffRatio).round();
    for (final s in scores) {
      if (s >= cutoff) return false;
    }
    return true;
  }
}
