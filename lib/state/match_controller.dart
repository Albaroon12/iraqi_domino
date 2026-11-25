import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_persona.dart';
import '../ai/domino_ai.dart';
import '../ai/user_play_profile.dart';
import '../core/audio/sound_service.dart';
import '../data/game_data_center.dart';
import '../engine/board.dart';
import '../engine/domino_piece.dart';
import '../engine/game_rules_config.dart';
import '../engine/match_state.dart';
import '../engine/match_view_state.dart';
import '../engine/seat_occupant.dart';
import 'settings_provider.dart';

export '../engine/match_view_state.dart';

/// Family argument identifying one match session.
typedef MatchArgs = ({int playerCount, GameRulesConfig rules});

/// Riverpod controller owning one match's [MatchState], seat occupants,
/// timers, and turn flow.
class MatchController extends Notifier<MatchViewState> {
  MatchController(this.arg);

  final MatchArgs arg;

  static const Duration _aiDelay = Duration(milliseconds: 900);
  static const Duration _drawDelay = Duration(milliseconds: 700);
  static const Duration _passDelay = Duration(milliseconds: 1300);
  static const Duration _revealDelay = Duration(milliseconds: 3200);
  static const int turnSeconds = 30;
  static const int _boneyardTableSlots = 14;
  static const String _kUserPlayProfile = 'ai.user_play_profile';

  final math.Random _random = math.Random();
  late MatchState _match;
  late UserPlayProfile _userProfile;
  late List<SeatOccupant> _seats;

  List<Move> _myMoves = const [];
  List<DominoPiece?> _boneyardSlots = const [];
  Timer? _timer;
  Timer? _turnTimer;
  int _secondsLeft = turnSeconds;
  MatchStatus? _status;
  bool _awaitingHumanDraw = false;
  bool _revealingRound = false;
  DominoPiece? _lastPlayedPiece;
  bool _showResultPending = false;
  bool _disposed = false;
  int _revision = 0;

  @override
  MatchViewState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _cancelTimers();
    });

    _userProfile = _loadUserProfile();
    _seats = _buildInitialOfflineSeats();
    _match = MatchState(
      playerCount: arg.playerCount,
      rules: arg.rules,
      random: _random,
    );
    _initBoneyardSlots();
    _prepareTurn();
    return _snapshot();
  }

  List<SeatOccupant> _buildInitialOfflineSeats() {
    final bots = AiPersona.pickDistinct(arg.playerCount - 1, _random);
    return <SeatOccupant>[
      const SeatOccupant.human(nameAr: 'أنت', nameEn: 'You'),
      for (final persona in bots) SeatOccupant.bot(persona),
    ];
  }

  UserPlayProfile _loadUserProfile() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      return UserPlayProfile.decode(prefs.getString(_kUserPlayProfile));
    } catch (_) {
      return UserPlayProfile();
    }
  }

  void _saveUserProfile() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.setString(_kUserPlayProfile, _userProfile.encode());
    } catch (_) {
      // Safe fallback when running in unit tests without SharedPreferences.
    }
  }

  bool get _canAcceptHumanJoin => SeatOccupant.canAcceptHumanJoin(
    scores: _match.scores,
    targetScore: arg.rules.targetScore,
    isMatchOver: _match.isOver,
  );

  /// Replaces a disconnected/departed human at [seat] (`1..playerCount-1`)
  /// with a distinct [AiPersona] bot that immediately continues the match.
  void replaceHumanWithBot(int seat) {
    if (seat <= 0 || seat >= arg.playerCount) return;
    final usedIds = <String>{
      for (final s in _seats)
        if (s.aiPersona != null) s.aiPersona!.id,
    };
    final persona = AiPersona.pickDistinct(
      1,
      _random,
      excludeIds: usedIds,
    ).first;
    _seats[seat] = SeatOccupant.bot(
      persona,
      openForHumanJoin: _canAcceptHumanJoin,
    );
    if (_match.round.turn == seat && !_match.round.isOver) {
      _prepareTurn();
    }
    _emit();
  }

  /// Replaces an open bot seat (`1..playerCount-1`) with a newly matched human
  /// player if the match has not yet entered its endgame phase.
  bool tryHotJoinHuman({
    required int seat,
    required String playerId,
    required String nameAr,
    required String nameEn,
  }) {
    if (seat <= 0 || seat >= arg.playerCount) return false;
    final current = _seats[seat];
    if (!current.isBot || !current.openForHumanJoin) return false;
    if (!_canAcceptHumanJoin) return false;

    _seats[seat] = SeatOccupant.human(
      playerId: playerId,
      nameAr: nameAr,
      nameEn: nameEn,
    );
    _emit();
    return true;
  }

  /// Plays a human move for seat 0 if valid, and lets the AI learn from the
  /// player's decision.
  void playHumanMove(DominoPiece piece, BoardEnd end) {
    final move = Move(piece, end);
    if (_match.round.turn != 0 || !_myMoves.contains(move)) return;
    _userProfile.observeHumanMove(_match.round, move, _myMoves);
    _saveUserProfile();
    _lastPlayedPiece = piece;
    _match.play(move);
    ref.read(soundServiceProvider).playTilePlace();
    _prepareTurn();
    _emit();
  }

  /// Draws the specific tile at [slotIndex] from the 2-player boneyard table.
  void drawHumanTile(int slotIndex) {
    if (!_awaitingHumanDraw || _match.round.turn != 0) return;
    if (slotIndex < 0 || slotIndex >= _boneyardSlots.length) return;
    final piece = _boneyardSlots[slotIndex];
    if (piece == null) return;

    final boneyardIndex = _match.round.boneyard.indexOf(piece);
    if (boneyardIndex == -1) return;

    _match.draw(boneyardIndex);
    _boneyardSlots[slotIndex] = null;
    ref.read(soundServiceProvider).playTileDraw();
    _prepareTurn();
    _emit();
  }

  /// Advances to the next round manually if needed.
  void startNextRound() {
    if (_match.isOver || !_match.round.isOver) return;
    _showResultPending = false;
    _revealingRound = false;
    _lastPlayedPiece = null;
    _match.startNextRound();
    _initBoneyardSlots();
    _prepareTurn();
    _emit();
  }

  /// Resets scores and history and starts a fresh match.
  void resetMatch() {
    _showResultPending = false;
    _revealingRound = false;
    _lastPlayedPiece = null;
    _match.resetMatch();
    _initBoneyardSlots();
    _prepareTurn();
    _emit();
  }

  /// Developer shortcut: deals a fresh first round without resetting scores.
  void redeal() {
    _showResultPending = false;
    _revealingRound = false;
    _lastPlayedPiece = null;
    _match.redealCurrentRound();
    _initBoneyardSlots();
    _prepareTurn();
    _emit();
  }

  void _initBoneyardSlots() {
    if (arg.playerCount != 2) {
      _boneyardSlots = const [];
      return;
    }
    final remaining = _match.round.boneyard;
    final pad = math.max(0, _boneyardTableSlots - remaining.length);
    _boneyardSlots = <DominoPiece?>[
      ...remaining,
      ...List<DominoPiece?>.filled(pad, null),
    ];
  }

  // ---------------------------------------------------------------------
  // Turn orchestration & timers
  // ---------------------------------------------------------------------

  void _cancelTimers() {
    _timer?.cancel();
    _turnTimer?.cancel();
  }

  void _schedule(Duration delay, void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (!_disposed) action();
    });
  }

  /// Updates turn-derived fields and schedules the next timer without emitting
  /// synchronously (safe to call from [build]).
  void _prepareTurn() {
    _cancelTimers();
    _myMoves = const [];
    _awaitingHumanDraw = false;
    _revealingRound = false;
    _showResultPending = false;

    final round = _match.round;
    if (round.isOver) {
      _status = null;
      _revealingRound = true;
      // Refresh openForHumanJoin flags when scores cross the endgame cutoff.
      if (!_canAcceptHumanJoin) {
        for (var i = 1; i < _seats.length; i++) {
          final s = _seats[i];
          if (s.isBot && s.openForHumanJoin && s.aiPersona != null) {
            _seats[i] = SeatOccupant.bot(s.aiPersona!, openForHumanJoin: false);
          }
        }
      }
      _schedule(_revealDelay, () {
        if (_match.isOver) {
          _showResultPending = true;
          final won = _match.winnerTeam == 0;
          final roundsWon = _match.history
              .where((r) => r.result.winnerTeam == 0)
              .length;
          try {
            ref.read(gameDataCenterProvider.notifier).recordMatchOutcome(
                  won: won,
                  ourScore: _match.scores[0],
                  roundsWonInMatch: roundsWon,
                );
          } catch (_) {}
          _emit();
        } else {
          _revealingRound = false;
          _lastPlayedPiece = null;
          _match.startNextRound();
          _initBoneyardSlots();
          _prepareTurn();
          _emit();
        }
      });
      return;
    }

    final seat = round.turn;
    final moves = _match.legalMoves();

    if (moves.isEmpty) {
      final canDraw = round.playerCount == 2 && round.boneyard.isNotEmpty;
      if (canDraw && seat == 0) {
        // Human chooses tiles directly from the 2-row wooden boneyard table.
        _status = null;
        _awaitingHumanDraw = true;
        return;
      }

      _status = MatchStatus(
        seat: seat,
        kind: canDraw
            ? MatchStatusKind.draws
            : (arg.playerCount == 4
                  ? MatchStatusKind.noTiles
                  : MatchStatusKind.passes),
      );
      _schedule(canDraw ? _drawDelay : _passDelay, _resolveNoMoves);
      return;
    }

    _status = null;
    if (seat == 0) {
      _myMoves = moves;
      _startTurnTimer();
    } else {
      _schedule(_aiDelay, () => _aiPlay(moves));
    }
  }

  void _startTurnTimer() {
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
        _autoPlayForMe();
      } else {
        _emit();
      }
    });
  }

  /// Plays an AI-chosen move for seat 0 when the 30-second turn timer expires.
  void _autoPlayForMe() {
    if (_match.round.isOver || _match.round.turn != 0 || _myMoves.isEmpty) {
      return;
    }
    final move = DominoAi.chooseMove(
      _match.round,
      difficulty: arg.rules.aiDifficulty,
      userProfile: _userProfile,
    );
    _lastPlayedPiece = move.piece;
    _match.play(move);
    ref.read(soundServiceProvider).playTilePlace();
    _prepareTurn();
    _emit();
  }

  void _resolveNoMoves() {
    if (_match.round.playerCount == 2 && _match.round.boneyard.isNotEmpty) {
      final drawn = _match.draw();
      final idx = _boneyardSlots.indexOf(drawn);
      if (idx != -1) _boneyardSlots[idx] = null;
      ref.read(soundServiceProvider).playTileDraw();
    } else {
      _match.pass();
      ref.read(soundServiceProvider).playPass();
    }
    _prepareTurn();
    _emit();
  }

  /// Plays a strategic move for AI-controlled seats using [DominoAi].
  void _aiPlay(List<Move> _) {
    final move = DominoAi.chooseMove(
      _match.round,
      difficulty: arg.rules.aiDifficulty,
      userProfile: _userProfile,
    );
    _lastPlayedPiece = move.piece;
    _match.play(move);
    ref.read(soundServiceProvider).playTilePlace();
    _prepareTurn();
    _emit();
  }

  void _emit() {
    if (_disposed) return;
    state = _snapshot();
  }

  MatchViewState _snapshot() {
    final round = _match.round;
    return MatchViewState(
      playerCount: arg.playerCount,
      rules: arg.rules,
      seats: List<SeatOccupant>.unmodifiable(_seats),
      canAcceptHumanJoin: _canAcceptHumanJoin,
      board: round.board,
      hands: [
        for (final hand in round.hands) List<DominoPiece>.unmodifiable(hand),
      ],
      boneyardCount: round.boneyard.length,
      boneyardSlots: List<DominoPiece?>.unmodifiable(_boneyardSlots),
      awaitingHumanDraw: _awaitingHumanDraw,
      revealingRound: _revealingRound,
      lastPlayedPiece: _lastPlayedPiece,
      startSeat: round.startSeat,
      openingPiece: round.openingPiece,
      turnSeat: round.isOver ? null : round.turn,
      scores: _match.scores,
      history: _match.history,
      myMoves: List<Move>.unmodifiable(_myMoves),
      secondsLeft: _secondsLeft,
      turnSeconds: turnSeconds,
      status: _status,
      roundResult: round.result,
      matchWinnerTeam: _match.winnerTeam,
      showResultPending: _showResultPending,
      revision: ++_revision,
    );
  }
}

/// Provider creating one [MatchController] per match configuration.
final matchControllerProvider = NotifierProvider.autoDispose
    .family<MatchController, MatchViewState, MatchArgs>(MatchController.new);
