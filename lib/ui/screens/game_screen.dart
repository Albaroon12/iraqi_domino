import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../engine/board.dart';
import '../../engine/dealer.dart';
import '../../engine/domino_piece.dart';
import '../../engine/game_rules_config.dart';
import '../../engine/round_result.dart';
import '../../engine/round_state.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/board_view.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/hidden_hand.dart';
import '../../rendering/tile_skin.dart';
import '../../rendering/wood_table.dart';
import '../../state/settings_provider.dart';
import '../widgets/player_chip.dart';
import '../widgets/round_result_dialog.dart';
import '../widgets/score_board.dart';

/// The game screen (PROTOTYPE, Phase 3).
///
/// Seats, counter-clockwise from the bottom (4 players):
/// 0 = you, 1 = right opponent, 2 = partner (top), 3 = left opponent.
/// With 2 players: 0 = you, 1 = opponent (top).
///
/// The match rules come from [rules] and never from the global settings.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.playerCount, required this.rules})
    : assert(playerCount == 2 || playerCount == 4);

  final int playerCount;
  final GameRulesConfig rules;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

/// What the small status pill says about the player who cannot play.
enum _StatusKind { noTiles, passes, draws }

class _GameScreenState extends ConsumerState<GameScreen> {
  // Speed of the game. Change these numbers to make it faster or slower.
  static const Duration _aiDelay = Duration(milliseconds: 900);
  static const Duration _drawDelay = Duration(milliseconds: 700);
  static const Duration _passDelay = Duration(milliseconds: 1300);
  static const Duration _resultDelay = Duration(milliseconds: 700);

  /// Seconds you have for each move. When it runs out, the computer plays
  /// for you. Use 60 for a slower game.
  static const int _turnSeconds = 30;

  /// Short side of the tile that follows your finger while dragging.
  static const double _feedbackWidth = 44;

  final math.Random _random = math.Random();

  /// Keys to find where the two open ends are on the screen.
  final GlobalKey _leftSlotKey = GlobalKey();
  final GlobalKey _rightSlotKey = GlobalKey();

  late RoundState _round;

  /// Your legal moves. Filled only while it is your turn.
  List<Move> _myMoves = const [];

  /// Match score: index 0 = your team, 1 = the other team.
  final List<int> _scores = [0, 0];

  Timer? _timer;
  Timer? _turnTimer;
  int _secondsLeft = _turnSeconds;
  ({int seat, _StatusKind kind})? _status;

  // Interaction state (your own turn only).
  DominoPiece? _dragging;
  DominoPiece? _selected;
  BoardEnd? _hoverEnd;

  bool get _four => widget.playerCount == 4;
  int get _topSeat => _four ? 2 : 1;

  /// The seat whose turn it is, or null when the round is over.
  int? get _turnSeat => _round.isOver ? null : _round.turn;

  @override
  void initState() {
    super.initState();
    _round = _roundFromSetup(
      Dealer.dealFirstRound(widget.playerCount, _random),
    );
    _advance();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _turnTimer?.cancel();
    super.dispose();
  }

  RoundState _roundFromSetup(RoundSetup setup) => RoundState(
    playerCount: widget.playerCount,
    hands: setup.hands,
    boneyard: setup.boneyard,
    startSeat: setup.startSeat,
    openingPiece: setup.startPiece,
  );

  // ---------------------------------------------------------------------
  // Game flow
  // ---------------------------------------------------------------------

  void _schedule(Duration delay, VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (mounted) action();
    });
  }

  /// Decides what happens now that the turn belongs to a new player.
  /// Call it inside setState (it only changes fields and starts timers).
  void _advance() {
    _timer?.cancel();
    _turnTimer?.cancel();
    _myMoves = const [];

    if (_round.isOver) {
      _schedule(_resultDelay, _showResult);
      return;
    }

    // Legal moves are computed ONLY for the player whose turn it is,
    // because the hands change after every move.
    final seat = _round.turn;
    final moves = _round.legalMoves();

    if (moves.isEmpty) {
      // No legal move: it happens automatically, nobody presses a button.
      final canDraw = _round.playerCount == 2 && _round.boneyard.isNotEmpty;
      _status = (
        seat: seat,
        kind: canDraw
            ? _StatusKind.draws
            : (_four ? _StatusKind.noTiles : _StatusKind.passes),
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

  /// Starts the countdown of your turn.
  void _startTurnTimer() {
    _turnTimer?.cancel();
    _secondsLeft = _turnSeconds;
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        _autoPlayForMe();
      }
    });
  }

  /// Time is up: the computer plays a legal move for you.
  /// PROTOTYPE: random move. The real AI comes in Phase 5.
  void _autoPlayForMe() {
    if (_round.isOver || _round.turn != 0 || _myMoves.isEmpty) return;
    final move = _myMoves[_random.nextInt(_myMoves.length)];
    setState(() {
      _clearInteraction();
      _round.play(move);
      _advance();
    });
  }

  /// The current player has no move: draw (two players) or pass.
  void _resolveNoMoves() {
    setState(() {
      if (_round.playerCount == 2 && _round.boneyard.isNotEmpty) {
        _round.draw();
      } else {
        _round.pass();
      }
      _advance();
    });
  }

  /// PROTOTYPE: the computer plays a random legal move.
  /// The real AI comes in Phase 5.
  void _aiPlay(List<Move> moves) {
    final move = moves[_random.nextInt(moves.length)];
    setState(() {
      _round.play(move);
      _advance();
    });
  }

  Future<void> _showResult() async {
    final result = _round.result;
    if (result == null) return;

    setState(() {
      final team = result.winnerTeam;
      if (team != null) _scores[team] += result.points;
      _status = null;
    });

    await showRoundResultDialog(
      context,
      kind: result.kind,
      weWon: result.winnerTeam == 0,
      points: result.points,
      ourTotal: _scores[0],
      theirTotal: _scores[1],
    );
    if (!mounted) return;
    _startNextRound(result);
  }

  /// A burned round is dealt like a first round. After a win, the winner
  /// starts and may open with any piece.
  void _startNextRound(RoundResult last) {
    setState(() {
      _clearInteraction();
      final winner = last.winnerSeat;
      if (last.kind == RoundEndKind.burned || winner == null) {
        _round = _roundFromSetup(
          Dealer.dealFirstRound(widget.playerCount, _random),
        );
      } else {
        final dealt = Dealer.deal(widget.playerCount, _random);
        _round = RoundState(
          playerCount: widget.playerCount,
          hands: dealt.hands,
          boneyard: dealt.boneyard,
          startSeat: winner,
        );
      }
      _advance();
    });
  }

  /// Developer shortcut: deal a fresh first round.
  void _redeal() {
    setState(() {
      _clearInteraction();
      _round = _roundFromSetup(
        Dealer.dealFirstRound(widget.playerCount, _random),
      );
      _advance();
    });
  }

  // ---------------------------------------------------------------------
  // Your moves: tap and drag and drop
  // ---------------------------------------------------------------------

  void _clearInteraction() {
    _dragging = null;
    _selected = null;
    _hoverEnd = null;
  }

  bool _isPlayable(DominoPiece piece) =>
      _myMoves.any((move) => move.piece == piece);

  List<BoardEnd> _endsFor(DominoPiece piece) => [
    for (final move in _myMoves)
      if (move.piece == piece) move.end,
  ];

  void _playMine(DominoPiece piece, BoardEnd end) {
    final move = Move(piece, end);
    if (_round.turn != 0 || !_myMoves.contains(move)) return;
    setState(() {
      _clearInteraction();
      _round.play(move);
      _advance();
    });
  }

  /// Tap: one possible end plays at once; two ends select the piece and
  /// show both places, then you tap the place you want.
  void _onTapPiece(DominoPiece piece) {
    final ends = _endsFor(piece);
    if (ends.isEmpty) return;
    if (ends.length == 1) {
      _playMine(piece, ends.first);
      return;
    }
    setState(() => _selected = _selected == piece ? null : piece);
  }

  void _onDragStarted(DominoPiece piece) {
    setState(() {
      _dragging = piece;
      _selected = null;
      _hoverEnd = null;
    });
  }

  void _onDragEnd() {
    if (!mounted) return;
    if (_dragging != null || _hoverEnd != null) {
      setState(() {
        _dragging = null;
        _hoverEnd = null;
      });
    }
  }

  /// While dragging over the board: light the end nearest to the tile.
  void _onDragMove(DragTargetDetails<DominoPiece> details) {
    final ends = _endsFor(details.data);
    if (ends.isEmpty) return;
    final end = ends.length == 1
        ? ends.first
        : _nearestEnd(_dragPoint(details), ends);
    if (end != _hoverEnd) setState(() => _hoverEnd = end);
  }

  void _onDrop(DragTargetDetails<DominoPiece> details) {
    final ends = _endsFor(details.data);
    if (ends.isEmpty) return;
    final hover = _hoverEnd;
    final end = (hover != null && ends.contains(hover))
        ? hover
        : (ends.length == 1
              ? ends.first
              : _nearestEnd(_dragPoint(details), ends));
    _playMine(details.data, end);
  }

  /// The center of the dragged tile on the screen.
  Offset _dragPoint(DragTargetDetails<DominoPiece> details) =>
      details.offset + const Offset(_feedbackWidth / 2, _feedbackWidth);

  BoardEnd _nearestEnd(Offset point, List<BoardEnd> ends) {
    var best = ends.first;
    var bestDistance = double.infinity;
    for (final end in ends) {
      final center = _slotCenter(
        end == BoardEnd.left ? _leftSlotKey : _rightSlotKey,
      );
      if (center == null) continue;
      final distance = (center - point).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = end;
      }
    }
    return best;
  }

  Offset? _slotCenter(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  // ---------------------------------------------------------------------
  // Texts
  // ---------------------------------------------------------------------

  String _seatName(AppLocalizations l10n, int seat) {
    if (seat == 0) return l10n.playerYou;
    if (!_four) return l10n.opponentSingle;
    return switch (seat) {
      1 => l10n.opponentRight,
      2 => l10n.playerPartner,
      _ => l10n.opponentLeft,
    };
  }

  String _startMessage(AppLocalizations l10n) {
    final seat = _round.startSeat;
    final forced = _round.openingPiece;
    if (forced != null) {
      return seat == 0
          ? l10n.youStartRound('$forced')
          : l10n.otherStartsRound(_seatName(l10n, seat), '$forced');
    }
    return seat == 0
        ? l10n.youStartRoundFree
        : l10n.otherStartsRoundFree(_seatName(l10n, seat));
  }

  String _statusText(AppLocalizations l10n) {
    final status = _status!;
    final name = _seatName(l10n, status.seat);
    return switch (status.kind) {
      _StatusKind.noTiles => l10n.saysNoTiles(name),
      _StatusKind.passes => l10n.passesTurn(name),
      _StatusKind.draws => l10n.drawsTile(name),
    };
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final skin = TileSkin.byId(settings.tileSkinId);

    return Scaffold(
      appBar: AppBar(
        title: Text(_four ? l10n.modeFourPlayers : l10n.modeTwoPlayers),
        actions: [
          // Developer shortcut: hidden in release builds.
          if (!kReleaseMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.redeal,
              onPressed: _redeal,
            ),
        ],
      ),
      body: WoodTable(
        child: SafeArea(
          child: Column(
            children: [
              ScoreBoard(
                ourLabel: _four ? l10n.teamUs : l10n.playerYou,
                theirLabel: _four ? l10n.teamThem : l10n.opponentSingle,
                ourScore: _scores[0],
                theirScore: _scores[1],
                targetScore: widget.rules.targetScore,
              ),
              Expanded(child: _buildTableArea(l10n, skin)),
              _buildBottomArea(l10n, skin),
            ],
          ),
        ),
      ),
    );
  }

  /// The middle part: other players around the line of play.
  Widget _buildTableArea(AppLocalizations l10n, TileSkin skin) {
    final topCount = _round.hands[_topSeat].length;

    return Stack(
      children: [
        // Top player: the partner (4 players) or the opponent (2 players).
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlayerChip(
                  name: _seatName(l10n, _topSeat),
                  tileCount: topCount,
                  isTurn: _turnSeat == _topSeat,
                ),
                const SizedBox(height: 8),
                HiddenHand(count: topCount, skin: skin, tileWidth: 12),
              ],
            ),
          ),
        ),

        // Side players (4 players only). Alignment is physical left/right
        // on purpose: seating must not flip with the language direction.
        if (_four)
          Align(
            alignment: const Alignment(-1, 0.4),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _SidePlayer(
                name: _seatName(l10n, 3),
                tileCount: _round.hands[3].length,
                isTurn: _turnSeat == 3,
                skin: skin,
              ),
            ),
          ),
        if (_four)
          Align(
            alignment: const Alignment(1, 0.4),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _SidePlayer(
                name: _seatName(l10n, 1),
                tileCount: _round.hands[1].length,
                isTurn: _turnSeat == 1,
                skin: skin,
              ),
            ),
          ),

        // Center: the line of play, which is also the drop zone.
        // The padding keeps the tiles away from the screen edge and from
        // the players' cards (top 108, sides 76 with four players).
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _four ? 76 : 14,
              108,
              _four ? 76 : 14,
              12,
            ),
            child: _buildBoardZone(l10n, skin),
          ),
        ),

        // 2 players: how many pieces are left in the draw pile.
        if (!_four)
          Align(
            alignment: Alignment.topLeft,
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 10, 0, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xCC1D110A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.boneyardCount(_round.boneyard.length),
                  style: const TextStyle(color: AppColors.ivory, fontSize: 13),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBoardZone(AppLocalizations l10n, TileSkin skin) {
    return Stack(
      children: [
        Positioned.fill(
          child: DragTarget<DominoPiece>(
            onWillAcceptWithDetails: (details) => _isPlayable(details.data),
            onMove: _onDragMove,
            onLeave: (_) {
              if (_hoverEnd != null) setState(() => _hoverEnd = null);
            },
            onAcceptWithDetails: _onDrop,
            builder: (context, candidates, rejected) =>
                SizedBox.expand(child: _buildBoard(l10n, skin)),
          ),
        ),
        if (_status != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(child: _StatusPill(text: _statusText(l10n))),
          ),
      ],
    );
  }

  Widget _buildBoard(AppLocalizations l10n, TileSkin skin) {
    final ghost = _dragging ?? _selected;
    if (_round.board.isEmpty && ghost == null) {
      return Center(child: _BoardPlaceholder(message: _startMessage(l10n)));
    }
    final active = ghost == null ? const <BoardEnd>[] : _endsFor(ghost);
    final hover = _hoverEnd;
    final selected = _selected;

    return BoardView(
      board: _round.board,
      skin: skin,
      leftKey: _leftSlotKey,
      rightKey: _rightSlotKey,
      ghostDouble: ghost?.isDouble ?? false,
      activeEnds: active,
      // Dragging: only the nearest end is lit. Tap selection: all are lit.
      litEnds: _dragging != null ? {?hover} : active.toSet(),
      onSlotTap: selected == null ? null : (end) => _playMine(selected, end),
    );
  }

  /// The bottom part: your card and your hand.
  Widget _buildBottomArea(AppLocalizations l10n, TileSkin skin) {
    final myHand = [..._round.hands[0]]..sort();
    final myTurn = _turnSeat == 0;
    final timerOn = myTurn && _myMoves.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerChip(
            name: l10n.playerYou,
            tileCount: myHand.length,
            isTurn: myTurn,
            secondsLeft: timerOn ? _secondsLeft : null,
            secondsTotal: _turnSeconds,
          ),
          const SizedBox(height: 4),
          // One row that scrolls sideways, so any number of tiles can be
          // reached. The tile size never changes with the number of tiles.
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = math.min(48.0, (constraints.maxWidth - 68) / 7);
              return SizedBox(
                height: tileWidth * 2 + 32,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final piece in myHand)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: _HandTile(
                                piece: piece,
                                width: tileWidth,
                                feedbackWidth: _feedbackWidth,
                                skin: skin,
                                playable: _isPlayable(piece),
                                dimmed: myTurn && !_isPlayable(piece),
                                selected: _selected == piece,
                                onTap: () => _onTapPiece(piece),
                                onDragStarted: () => _onDragStarted(piece),
                                onDragEnd: _onDragEnd,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One tile of your hand. Playable tiles glow gold and can be tapped or
/// dragged up to the table; the others fade (only while it is your turn).
class _HandTile extends StatelessWidget {
  const _HandTile({
    required this.piece,
    required this.width,
    required this.feedbackWidth,
    required this.skin,
    required this.playable,
    required this.dimmed,
    required this.selected,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragEnd,
  });

  final DominoPiece piece;
  final double width;
  final double feedbackWidth;
  final TileSkin skin;
  final bool playable;
  final bool dimmed;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    Widget tile = DominoTile(
      top: piece.low,
      bottom: piece.high,
      width: width,
      skin: skin,
    );

    if (playable) {
      tile = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.16),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.85),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: tile,
      );
    }

    // A selected tile (two possible ends) rises a little.
    tile = AnimatedSlide(
      offset: selected ? const Offset(0, -0.12) : Offset.zero,
      duration: const Duration(milliseconds: 150),
      child: tile,
    );

    if (!playable) {
      return AnimatedOpacity(
        opacity: dimmed ? 0.4 : 1,
        duration: const Duration(milliseconds: 200),
        child: tile,
      );
    }

    return Draggable<DominoPiece>(
      data: piece,
      maxSimultaneousDrags: 1,
      // Only an upward/downward drag starts the drag-and-drop, so a
      // sideways swipe still scrolls the hand.
      affinity: Axis.vertical,
      feedback: DominoTile(
        top: piece.low,
        bottom: piece.high,
        width: feedbackWidth,
        skin: skin,
      ),
      // The place stays EMPTY while the tile is in your finger.
      childWhenDragging: SizedBox(width: width, height: width * 2),
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      ),
    );
  }
}

/// A side opponent: card on top, a column of face-down tiles below it.
class _SidePlayer extends StatelessWidget {
  const _SidePlayer({
    required this.name,
    required this.tileCount,
    required this.isTurn,
    required this.skin,
  });

  final String name;
  final int tileCount;
  final bool isTurn;
  final TileSkin skin;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerChip(name: name, tileCount: tileCount, isTurn: isTurn),
        const SizedBox(height: 6),
        HiddenHand(count: tileCount, skin: skin, tileWidth: 12, vertical: true),
      ],
    );
  }
}

/// Message shown on the empty table before the first piece.
class _BoardPlaceholder extends StatelessWidget {
  const _BoardPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC1D110A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.ivory, fontSize: 14),
      ),
    );
  }
}

/// Small pill that says who has no tile to play ("I have none", draws...).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xDD1D110A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.ivory,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
