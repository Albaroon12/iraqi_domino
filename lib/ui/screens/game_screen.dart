import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_persona.dart';
import '../../core/audio/sound_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/maqha_design_system.dart';
import '../../data/cafe_events_and_tournaments.dart';
import '../../data/cafe_shop_catalog.dart';
import '../../data/game_data_center.dart';
import '../../data/player_account.dart';
import '../../engine/board.dart';
import '../../engine/domino_piece.dart';
import '../../engine/game_rules_config.dart';
import '../../engine/match_state.dart';
import '../../engine/round_result.dart';
import '../../engine/round_state.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/board_frame.dart';
import '../../rendering/board_theme.dart';
import '../../rendering/board_view.dart';
import '../../rendering/domino_back.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/hidden_hand.dart';
import '../../rendering/tile_skin.dart';
import '../../state/match_controller.dart';
import '../../state/multiplayer_session_controller.dart';
import '../../state/settings_provider.dart';
import '../widgets/cafe_prop_widget.dart';
import '../widgets/game_button.dart';
import '../widgets/player_chip.dart';

/// The game screen.
///
/// Seats, counter-clockwise from the bottom (4 players):
/// 0 = you, 1 = right opponent, 2 = partner (top), 3 = left opponent.
/// With 2 players: 0 = you, 1 = opponent (top).
///
/// The match rules come from [rules] and never from the global settings.
/// When [isMultiplayer] is true, state and moves flow through
/// [multiplayerSessionProvider] (shared across Offline Wi-Fi, Bluetooth, Local
/// Wi-Fi, and Online modes) with identical rendering and animations.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    super.key,
    required this.playerCount,
    required this.rules,
    this.isMultiplayer = false,
    this.activeTournament,
  }) : assert(playerCount == 2 || playerCount == 4);

  final int playerCount;
  final GameRulesConfig rules;
  final bool isMultiplayer;
  final CafeTournamentTier? activeTournament;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// Short side of the tile that follows your finger while dragging.
  static const double _feedbackWidth = 44;

  /// Total boneyard tiles at the start of a two-player round.
  static const int _initialBoneyardCount = 14;

  /// Keys to find where the two open ends and the newly placed tile are.
  final GlobalKey _leftSlotKey = GlobalKey();
  final GlobalKey _rightSlotKey = GlobalKey();
  final GlobalKey _lastPlacedKey = GlobalKey();

  /// Per-piece keys in your hand so a released tile flies straight back into
  /// its live opening slot.
  final Map<DominoPiece, GlobalKey> _handKeys = {};

  /// Active overlay flight animations, cleaned up in [dispose].
  final List<(OverlayEntry, AnimationController)> _activeFlights = [];

  // Pure UI interaction state (your own turn only).
  DominoPiece? _dragging;
  DominoPiece? _returningPiece;
  DominoPiece? _flyingToBoard;
  DominoPiece? _selected;
  BoardEnd? _hoverEnd;
  double _lastHandTileWidth = 36;
  bool _dialogOpen = false;
  bool _tournamentSettled = false;
  String? _cafeCalloutBubble;
  Timer? _calloutTimer;

  late final SoundService _sound;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sound = ref.read(soundServiceProvider);
    _sound.startCafeAmbient();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _sound.pauseCafeAmbient();
    } else if (state == AppLifecycleState.resumed) {
      _sound.resumeCafeAmbient();
    }
  }

  @override
  void dispose() {
    _calloutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _sound.stopCafeAmbient();
    for (final (entry, controller) in _activeFlights) {
      entry.remove();
      controller.dispose();
    }
    _activeFlights.clear();
    super.dispose();
  }

  bool get _four => widget.playerCount == 4;
  int get _topSeat => _four ? 2 : 1;

  MatchArgs get _matchArgs =>
      (playerCount: widget.playerCount, rules: widget.rules);

  MatchViewState get _currentMatch {
    if (widget.isMultiplayer) {
      return ref.read(multiplayerSessionProvider).matchView!;
    }
    return ref.read(matchControllerProvider(_matchArgs));
  }

  void _dispatchPlayMove(DominoPiece piece, BoardEnd end) {
    if (widget.isMultiplayer) {
      ref.read(multiplayerSessionProvider.notifier).playHumanMove(piece, end);
    } else {
      ref.read(matchControllerProvider(_matchArgs).notifier).playHumanMove(
            piece,
            end,
          );
    }
  }

  void _dispatchDrawTile(int slotIndex) {
    if (widget.isMultiplayer) {
      ref.read(multiplayerSessionProvider.notifier).drawHumanTile(slotIndex);
    } else {
      ref.read(matchControllerProvider(_matchArgs).notifier).drawHumanTile(
            slotIndex,
          );
    }
  }

  void _dispatchResetMatch() {
    if (widget.isMultiplayer) {
      ref.read(multiplayerSessionProvider.notifier).resetMatch();
    } else {
      ref.read(matchControllerProvider(_matchArgs).notifier).resetMatch();
    }
  }

  // ---------------------------------------------------------------------
  // Result dialogs & developer shortcut
  // ---------------------------------------------------------------------

  Future<void> _showResult(MatchViewState match) async {
    if (!match.isMatchOver || _dialogOpen) return;
    _dialogOpen = true;

    final weWon = match.matchWinnerTeam == 0;
    final cup = widget.activeTournament;
    if (cup != null && !_tournamentSettled) {
      _tournamentSettled = true;
      ref
          .read(gameDataCenterProvider.notifier)
          .completeTournamentMatch(tier: cup, won: weWon);
    }

    try {
      final playAgain = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _MatchResultDialog(
          weWon: weWon,
          ourTotal: match.scores[0],
          theirTotal: match.scores[1],
          targetScore: widget.rules.targetScore,
          activeTournament: cup,
        ),
      );
      if (!mounted) return;
      if (playAgain == true && cup == null) {
        setState(_clearInteraction);
        _dispatchResetMatch();
      } else {
        if (widget.isMultiplayer) {
          await ref.read(multiplayerSessionProvider.notifier).leaveSession();
        }
        if (mounted) Navigator.of(context).pop();
      }
    } finally {
      _dialogOpen = false;
    }
  }

  /// Developer shortcut: deal a fresh first round.
  void _redeal() {
    if (widget.isMultiplayer) return;
    setState(_clearInteraction);
    ref.read(matchControllerProvider(_matchArgs).notifier).redeal();
  }

  // ---------------------------------------------------------------------
  // Your moves: tap and drag and drop
  // ---------------------------------------------------------------------

  void _clearInteraction() {
    _dragging = null;
    _returningPiece = null;
    _flyingToBoard = null;
    _selected = null;
    _hoverEnd = null;
  }

  /// Commits [piece] on [end] immediately so the board lays out its true final
  /// position and orientation, then flies the tile crisply into that exact spot
  /// (morphing into its board orientation mid-flight without spinning).
  void _flyToBoard({
    required DominoPiece piece,
    required BoardEnd end,
    required TileSkin skin,
    required Offset fromCenter,
    required double fromWidth,
    required Duration duration,
  }) {
    final slotKey = end == BoardEnd.left ? _leftSlotKey : _rightSlotKey;
    final fallbackTarget = _slotCenter(slotKey) ?? fromCenter;

    setState(() {
      _dragging = null;
      _selected = null;
      _hoverEnd = null;
      _flyingToBoard = piece;
    });

    // Place the move immediately; BoardView hides _flyingToBoard while the
    // overlay tile glides into _lastPlacedKey's exact RenderBox.
    _dispatchPlayMove(piece, end);

    _flyOverlayTile(
      piece: piece,
      skin: skin,
      fromCenter: fromCenter,
      targetCenter: () => _slotCenter(_lastPlacedKey) ?? fallbackTarget,
      targetDominoTile: () {
        final w = _lastPlacedKey.currentWidget;
        return w is DominoTile ? w : null;
      },
      fromWidth: fromWidth,
      toWidth: 22,
      duration: duration,
      curve: Curves.easeOutCubic,
      onDone: () {
        if (mounted && _flyingToBoard == piece) {
          setState(() => _flyingToBoard = null);
        }
      },
    );
  }

  void _playMine(DominoPiece piece, BoardEnd end, TileSkin skin) {
    final handKey = _handKeys[piece];
    final fromCenter = handKey == null ? null : _slotCenter(handKey);
    if (fromCenter == null) {
      setState(_clearInteraction);
      _dispatchPlayMove(piece, end);
      return;
    }
    _flyToBoard(
      piece: piece,
      end: end,
      skin: skin,
      fromCenter: fromCenter,
      fromWidth: _lastHandTileWidth,
      duration: const Duration(milliseconds: 185),
    );
  }

  /// Tap: one possible end plays at once; two ends select the piece and
  /// show both places, then you tap the place you want.
  void _onTapPiece(DominoPiece piece, TileSkin skin) {
    if (_flyingToBoard != null) return;
    final ends = _currentMatch.endsFor(piece);
    if (ends.isEmpty) return;
    if (ends.length == 1) {
      _playMine(piece, ends.first, skin);
      return;
    }
    setState(() => _selected = _selected == piece ? null : piece);
  }

  void _onDragStarted(DominoPiece piece) {
    setState(() {
      _dragging = piece;
      _returningPiece = null;
      _selected = null;
      _hoverEnd = null;
    });
  }

  /// Smoothly flies a borderless [DominoTile] in the overlay from [fromCenter]
  /// to [targetCenter] (queried live each frame). When [targetDominoTile] is
  /// provided, the tile flips cleanly mid-flight into its exact final board
  /// orientation (top/bottom/horizontal/width) and drops straight into place
  /// without spinning.
  void _flyOverlayTile({
    required DominoPiece piece,
    required TileSkin skin,
    required Offset fromCenter,
    required Offset? Function() targetCenter,
    DominoTile? Function()? targetDominoTile,
    required double fromWidth,
    required double toWidth,
    required Duration duration,
    Curve curve = Curves.easeOutCubic,
    required VoidCallback onDone,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      onDone();
      return;
    }

    final controller = AnimationController(vsync: this, duration: duration);
    final curved = CurvedAnimation(parent: controller, curve: curve);
    var lastTarget = fromCenter;
    DominoTile? resolvedTile;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: AnimatedBuilder(
          animation: curved,
          builder: (_, _) {
            final liveTarget = targetCenter();
            if (liveTarget != null) lastTarget = liveTarget;
            final liveTile = targetDominoTile?.call();
            if (liveTile != null) resolvedTile = liveTile;

            final t = curved.value;
            final center = Offset.lerp(fromCenter, lastTarget, t)!;
            final endWidth = resolvedTile?.width ?? toWidth;
            final w = fromWidth + (endWidth - fromWidth) * t;
            final shadowAlpha = (1 - t) * 0.45;

            // Morph cleanly around t = 0.35 into the final board orientation
            // without any spinning wheel.
            final useFinalOrientation = resolvedTile != null && t >= 0.35;
            final isHoriz =
                useFinalOrientation && (resolvedTile?.horizontal ?? false);
            final topVal = useFinalOrientation ? resolvedTile!.top : piece.low;
            final botVal = useFinalOrientation
                ? resolvedTile!.bottom
                : piece.high;

            // Subtle mid-flight flip pulse when orientation changes.
            final needsMorph =
                resolvedTile != null &&
                (resolvedTile!.horizontal ||
                    resolvedTile!.top != piece.low ||
                    resolvedTile!.bottom != piece.high);
            var morphScale = 1.0;
            if (needsMorph && t > 0.15 && t < 0.55) {
              final phase = ((t - 0.35).abs() / 0.20).clamp(0.0, 1.0);
              morphScale = 0.82 + 0.18 * phase;
            }

            final boxW = isHoriz ? w * 2 : w;
            final boxH = isHoriz ? w : w * 2;

            return Stack(
              children: [
                Positioned(
                  left: center.dx - boxW / 2,
                  top: center.dy - boxH / 2,
                  child: Transform.scale(
                    scale: morphScale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(w * 0.16),
                        boxShadow: shadowAlpha > 0.01
                            ? [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, shadowAlpha),
                                  blurRadius: 12 * (1 - t) + 2,
                                  offset: Offset(0, 6 * (1 - t)),
                                ),
                              ]
                            : const [],
                      ),
                      child: DominoTile(
                        top: topVal,
                        bottom: botVal,
                        width: w,
                        horizontal: isHoriz,
                        skin: skin,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    final record = (entry, controller);
    _activeFlights.add(record);
    overlay.insert(entry);

    controller.forward().whenComplete(() {
      _activeFlights.remove(record);
      entry.remove();
      controller.dispose();
      if (mounted) onDone();
    });
  }

  /// Drag released outside the board: open the slot smoothly and fly the tile
  /// straight back into it with zero flicker.
  void _onDragCanceled(DominoPiece piece, Offset releaseOffset, TileSkin skin) {
    if (!mounted) return;
    final fromCenter =
        releaseOffset + const Offset(_feedbackWidth / 2, _feedbackWidth);
    final key = _handKeys[piece];

    setState(() {
      _dragging = null;
      _hoverEnd = null;
      _returningPiece = piece;
    });

    _flyOverlayTile(
      piece: piece,
      skin: skin,
      fromCenter: fromCenter,
      targetCenter: () => key == null ? null : _slotCenter(key),
      fromWidth: _feedbackWidth,
      toWidth: _lastHandTileWidth,
      duration: const Duration(milliseconds: 220),
      onDone: () {
        if (_returningPiece == piece) {
          setState(() => _returningPiece = null);
        }
      },
    );
  }

  /// While dragging over the board: light the end nearest to the tile.
  void _onDragMove(DragTargetDetails<DominoPiece> details) {
    final ends = _currentMatch.endsFor(details.data);
    if (ends.isEmpty) return;
    final end = ends.length == 1
        ? ends.first
        : _nearestEnd(_dragPoint(details), ends);
    if (end != _hoverEnd) setState(() => _hoverEnd = end);
  }

  void _onDrop(DragTargetDetails<DominoPiece> details, TileSkin skin) {
    final piece = details.data;
    final ends = _currentMatch.endsFor(piece);
    if (ends.isEmpty) return;
    final hover = _hoverEnd;
    final end = (hover != null && ends.contains(hover))
        ? hover
        : (ends.length == 1
              ? ends.first
              : _nearestEnd(_dragPoint(details), ends));

    _flyToBoard(
      piece: piece,
      end: end,
      skin: skin,
      fromCenter: _dragPoint(details),
      fromWidth: _feedbackWidth,
      duration: const Duration(milliseconds: 135),
    );
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

  String _seatName(
    AppLocalizations l10n,
    bool isAr,
    MatchViewState match,
    int seat,
  ) {
    if (seat == 0) return l10n.playerYou;
    if (seat >= 0 && seat < match.seats.length) {
      return match.seats[seat].displayName(isAr);
    }
    if (!_four) return l10n.opponentSingle;
    return switch (seat) {
      1 => l10n.opponentRight,
      2 => l10n.playerPartner,
      _ => l10n.opponentLeft,
    };
  }

  AiPersona? _seatPersona(MatchViewState match, int seat) {
    if (seat <= 0 || seat >= match.seats.length) return null;
    return match.seats[seat].aiPersona;
  }

  String _startMessage(
    AppLocalizations l10n,
    bool isAr,
    MatchViewState match,
  ) {
    final seat = match.startSeat;
    final forced = match.openingPiece;
    if (forced != null) {
      return seat == 0
          ? l10n.youStartRound('$forced')
          : l10n.otherStartsRound(_seatName(l10n, isAr, match, seat), '$forced');
    }
    return seat == 0
        ? l10n.youStartRoundFree
        : l10n.otherStartsRoundFree(_seatName(l10n, isAr, match, seat));
  }

  String _statusText(
    AppLocalizations l10n,
    bool isAr,
    MatchViewState match,
  ) {
    final status = match.status!;
    final name = _seatName(l10n, isAr, match, status.seat);
    return switch (status.kind) {
      MatchStatusKind.noTiles => l10n.saysNoTiles(name),
      MatchStatusKind.passes => l10n.passesTurn(name),
      MatchStatusKind.draws => l10n.drawsTile(name),
    };
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  Future<void> _showRoundHistory(MatchViewState match) {
    return showDialog<void>(
      context: context,
      builder: (_) => _RoundHistoryDialog(
        history: match.history,
        ourTotal: match.scores[0],
        theirTotal: match.scores[1],
        fourPlayers: _four,
      ),
    );
  }

  void _showCafeCallout(String text) {
    _calloutTimer?.cancel();
    setState(() => _cafeCalloutBubble = text);
    _calloutTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _cafeCalloutBubble = null);
    });
  }

  Future<void> _openSheikhPhrasePicker(bool isAr) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MaqhaColors.cardCharcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isAr ? 'عبارات شيوخ المقهى' : 'Sheikh Table Callouts',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              for (final p in CafeShopCatalog.sheikhQuickPhrases)
                ListTile(
                  dense: true,
                  title: Text(
                    isAr ? p.ar : p.en,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.ivory,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop(isAr ? p.ar : p.en),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) _showCafeCallout(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final settings = ref.watch(settingsProvider);
    final account = ref.watch(gameDataCenterProvider);
    final skin = TileSkin.byId(settings.tileSkinId);
    final boardTheme = BoardTheme.byId(account.effectiveTableId());

    final MatchViewState match;
    if (widget.isMultiplayer) {
      final netState = ref.watch(multiplayerSessionProvider);
      ref.listen<MultiplayerSessionState>(multiplayerSessionProvider, (
        prev,
        next,
      ) {
        if (next.roomClosed && !(prev?.roomClosed ?? false)) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        final prevView = prev?.matchView;
        final nextView = next.matchView;
        if (nextView == null) return;
        if (prevView?.turnSeat != nextView.turnSeat &&
            nextView.turnSeat != 0) {
          if (_dragging != null || _selected != null || _hoverEnd != null) {
            setState(_clearInteraction);
          }
        }
        if (nextView.showResultPending &&
            !(prevView?.showResultPending ?? false)) {
          _showResult(nextView);
        }
      });

      final view = netState.matchView;
      if (view == null) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      match = view;
    } else {
      match = ref.watch(matchControllerProvider(_matchArgs));
      ref.listen<MatchViewState>(matchControllerProvider(_matchArgs), (
        prev,
        next,
      ) {
        if (prev?.turnSeat != next.turnSeat && next.turnSeat != 0) {
          if (_dragging != null || _selected != null || _hoverEnd != null) {
            setState(_clearInteraction);
          }
        }
        if (next.showResultPending && !(prev?.showResultPending ?? false)) {
          _showResult(next);
        }
      });
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && widget.isMultiplayer) {
          ref.read(multiplayerSessionProvider.notifier).leaveSession();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: widget.activeTournament != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.gold,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.activeTournament!.title(isAr),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              )
            : Text(
                _four ? l10n.modeFourPlayers : l10n.modeTwoPlayers,
                style: const TextStyle(fontSize: 15),
              ),
        actions: [
          if (widget.activeTournament != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Center(
                child: CafeDinarPill(
                  amount: widget.activeTournament!.netPrizeDinars,
                  isAr: isAr,
                  compact: true,
                  showCurrencyWord: false,
                ),
              ),
            ),
          // Developer shortcut: hidden in release builds, multiplayer, and staked tournaments.
          if (!kReleaseMode &&
              !widget.isMultiplayer &&
              widget.activeTournament == null)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: l10n.redeal,
              onPressed: _redeal,
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: MaqhaGradients.screenCanvas,
        ),
        child: SafeArea(
          left: false,
          right: false,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: _buildTableArea(l10n, isAr, skin, boardTheme, match),
              ),
              _buildBottomArea(l10n, isAr, skin, account, match),
            ],
          ),
        ),
      ),
    ),
    );
  }

  /// The middle part: a framed board, with the other players around
  /// it (top player above, side players beside it with four players).
  ///
  /// All positions here are physical (left/right of the screen) on purpose:
  /// seating must not flip with the language direction.
  Widget _buildTableArea(
    AppLocalizations l10n,
    bool isAr,
    TileSkin skin,
    BoardTheme boardTheme,
    MatchViewState match,
  ) {
    final topCount = match.hands[_topSeat].length;

    return LayoutBuilder(
      builder: (context, box) {
        final topReserve = (box.maxHeight * 0.21).clamp(76.0, 112.0);
        final sideSlot = _four
            ? (box.maxWidth * 0.13).clamp(38.0, 56.0)
            : 0.0;
        final horizontalGap = _four
            ? (box.maxWidth * 0.02).clamp(5.0, 10.0)
            : (box.maxWidth * 0.055).clamp(12.0, 26.0);
        final bottomGap = (box.maxHeight * 0.015).clamp(4.0, 10.0);

        final boardWidth = math.max(
          80.0,
          box.maxWidth - 2 * sideSlot - 2 * horizontalGap,
        );
        final boardHeight = math.max(
          80.0,
          box.maxHeight - topReserve - bottomGap,
        );

        final left = (box.maxWidth - boardWidth) / 2;
        final top = topReserve;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Top player: the partner (4 players) or the opponent (2).
            Positioned(
              left: 0,
              right: 0,
              top: 4,
              height: topReserve - 6,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerChip(
                      name: _seatName(l10n, isAr, match, _topSeat),
                      tileCount: topCount,
                      isTurn: match.turnSeat == _topSeat,
                      aiPersona: _seatPersona(match, _topSeat),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PlayerScoreBadge(
                          score:
                              match.scores[RoundState.teamOf(
                                _topSeat,
                                widget.playerCount,
                              )],
                          target: widget.rules.targetScore,
                          compact: true,
                        ),
                        const SizedBox(width: 6),
                        _TileRack(
                          pieces: match.hands[_topSeat],
                          revealed: match.revealingRound,
                          skin: skin,
                          tileWidth: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // The framed board.
            Positioned(
              left: left,
              top: top,
              width: boardWidth,
              height: boardHeight,
              child: _buildBoardZone(l10n, isAr, skin, boardTheme, match),
            ),

            // Side players (4 players only), anchored to the left and right
            // edges of the screen with their tile racks emerging from the edge.
            if (_four)
              Positioned(
                left: 0,
                top: top,
                width: sideSlot,
                height: boardHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _SidePlayer(
                      name: _seatName(l10n, isAr, match, 3),
                      aiPersona: _seatPersona(match, 3),
                      pieces: match.hands[3],
                      revealed: match.revealingRound,
                      isTurn: match.turnSeat == 3,
                      score:
                          match.scores[RoundState.teamOf(3, widget.playerCount)],
                      target: widget.rules.targetScore,
                      skin: skin,
                      alignLeft: true,
                    ),
                  ),
                ),
              ),
            if (_four)
              Positioned(
                right: 0,
                top: top,
                width: sideSlot,
                height: boardHeight,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: _SidePlayer(
                      name: _seatName(l10n, isAr, match, 1),
                      aiPersona: _seatPersona(match, 1),
                      pieces: match.hands[1],
                      revealed: match.revealingRound,
                      isTurn: match.turnSeat == 1,
                      score:
                          match.scores[RoundState.teamOf(1, widget.playerCount)],
                      target: widget.rules.targetScore,
                      skin: skin,
                      alignLeft: false,
                    ),
                  ),
                ),
              ),

            // 2 players: how many pieces are left in the draw pile (14/14).
            if (!_four)
              Positioned(
                left: 10,
                top: 10,
                child: IgnorePointer(
                  child: _TopInfoPill(
                    icon: Icons.layers_rounded,
                    label: '${match.boneyardCount}/$_initialBoneyardCount',
                  ),
                ),
              ),

            // Round-by-round score log.
            Positioned(
              right: 10,
              top: 10,
              child: _TopInfoPill(
                icon: Icons.receipt_long_rounded,
                onTap: () => _showRoundHistory(match),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The framed board. Its inside is the line of play and the drop zone.
  Widget _buildBoardZone(
    AppLocalizations l10n,
    bool isAr,
    TileSkin skin,
    BoardTheme boardTheme,
    MatchViewState match,
  ) {
    return BoardFrame(
      theme: boardTheme,
      child: Stack(
        children: [
          Positioned.fill(
            child: DragTarget<DominoPiece>(
              onWillAcceptWithDetails: (details) =>
                  match.isPlayable(details.data),
              onMove: _onDragMove,
              onLeave: (_) {
                if (_hoverEnd != null) setState(() => _hoverEnd = null);
              },
              onAcceptWithDetails: (details) => _onDrop(details, skin),
              builder: (context, candidates, rejected) =>
                  SizedBox.expand(child: _buildBoard(l10n, isAr, skin, match)),
            ),
          ),
          if (match.awaitingHumanDraw)
            Center(
              child: _BoneyardDrawBoard(
                slots: match.boneyardSlots,
                skin: skin,
                onPick: _dispatchDrawTile,
              ),
            ),
          if (match.revealingRound && match.roundResult != null)
            Center(
              child: IgnorePointer(
                child: _RoundTallyBadge(
                  result: match.roundResult!,
                  fourPlayers: _four,
                ),
              ),
            ),
          if (_cafeCalloutBubble != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: match.status != null ? 38 : 10,
              child: Center(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: MaqhaColors.cardCharcoal,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.gold),
                    ),
                    child: Text(
                      _cafeCalloutBubble!,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (match.status != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: IgnorePointer(
                child: _StatusPill(text: _statusText(l10n, isAr, match)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBoard(
    AppLocalizations l10n,
    bool isAr,
    TileSkin skin,
    MatchViewState match,
  ) {
    final ghost = _dragging ?? _selected;
    final active = ghost == null ? const <BoardEnd>[] : match.endsFor(ghost);
    final hover = _hoverEnd;
    final selected = _selected;

    // Always mount BoardView so _leftSlotKey/_rightSlotKey are attached even
    // on an empty board (allowing the opening tap-to-play tile to fly smoothly
    // to the center slot).
    final boardView = BoardView(
      board: match.board,
      skin: skin,
      leftKey: _leftSlotKey,
      rightKey: _rightSlotKey,
      ghostDouble: ghost?.isDouble ?? false,
      activeEnds: active,
      // Dragging: only the nearest end is lit. Tap selection: all are lit.
      litEnds: _dragging != null ? {?hover} : active.toSet(),
      lastPlacedPiece: match.lastPlayedPiece,
      lastPlacedKey: _lastPlacedKey,
      hiddenPiece: _flyingToBoard,
      onSlotTap: selected == null
          ? null
          : (end) => _playMine(selected, end, skin),
    );

    if (match.board.isEmpty && ghost == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          boardView,
          Center(
            child: IgnorePointer(
              child: _BoardPlaceholder(
                message: _startMessage(l10n, isAr, match),
              ),
            ),
          ),
        ],
      );
    }

    return boardView;
  }

  /// The bottom part: your hand rack and your card.
  Widget _buildBottomArea(
    AppLocalizations l10n,
    bool isAr,
    TileSkin skin,
    PlayerAccount account,
    MatchViewState match,
  ) {
    final myHand = [...match.hands[0]]..sort();
    final myTurn = match.turnSeat == 0;
    final timerOn = myTurn && match.myMoves.isNotEmpty;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final compactBottom = screenHeight < 640;
    final maxTileByHeight = (screenHeight * 0.05).clamp(24.0, 38.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        8,
        compactBottom ? 6 : 8,
        8,
        (compactBottom ? 4 : 6) + bottomInset,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MaqhaColors.navDockGlass, Color(0xFF0E1818)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: const Border(
          top: BorderSide(
            color: MaqhaColors.borderSubtle,
            width: 1.1,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 16,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player's hand inside a 7-tile board-like rack; extra tiles clip
          // cleanly at both ends and can be reached by horizontal scrolling.
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = math
                  .min(maxTileByHeight, (constraints.maxWidth - 76) / 7)
                  .clamp(22.0, 38.0);
              _lastHandTileWidth = tileWidth;
              const rackPadH = 8.0;
              final rackWidth = math.min(
                constraints.maxWidth,
                7 * (tileWidth + 6) + rackPadH * 2 + 2,
              );
              final rackInnerWidth = math.max(0.0, rackWidth - 2);

              final rackBoxHeight = tileWidth * 2 + 14;
              const liftHeadroom = 18.0;

              return SizedBox(
                width: rackWidth,
                height: rackBoxHeight + liftHeadroom,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // The wooden rack sits at the bottom of the stack so a
                    // selected 2-end tile rises visibly ABOVE its top border.
                    Container(
                      width: rackWidth,
                      height: rackBoxHeight,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            MaqhaColors.cardCharcoalElevated,
                            MaqhaColors.cardCharcoal,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          width: 1.1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x80000000),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    // Clips horizontally at the rack walls while leaving top
                    // headroom unclipped so selected tiles pop above the rack.
                    ClipRect(
                      clipper: const _HorizontalRackClipper(
                        horizontalInset: 1.5,
                        topAllowance: 24,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: rackInnerWidth),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              rackPadH,
                              liftHeadroom + 7,
                              rackPadH,
                              7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final piece in myHand)
                                  AnimatedContainer(
                                    key: ValueKey(piece),
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    width:
                                        (_dragging == piece ||
                                            _flyingToBoard == piece)
                                        ? 0
                                        : tileWidth + 6,
                                    alignment: Alignment.center,
                                    clipBehavior:
                                        (_dragging == piece ||
                                            _flyingToBoard == piece)
                                        ? Clip.hardEdge
                                        : Clip.none,
                                    decoration: const BoxDecoration(),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: KeyedSubtree(
                                        key: _handKeys.putIfAbsent(
                                          piece,
                                          GlobalKey.new,
                                        ),
                                        child: _HandTile(
                                          piece: piece,
                                          width: tileWidth,
                                          feedbackWidth: _feedbackWidth,
                                          skin: skin,
                                          playable: match.isPlayable(piece),
                                          dimmed:
                                              myTurn &&
                                              !match.isPlayable(piece),
                                          selected: _selected == piece,
                                          hidden: _returningPiece == piece,
                                          onTap: () => _onTapPiece(piece, skin),
                                          onDragStarted: () =>
                                              _onDragStarted(piece),
                                          onDragCanceled: (offset) =>
                                              _onDragCanceled(
                                                piece,
                                                offset,
                                                skin,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: compactBottom ? 4 : 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PlayerChip(
                  name: l10n.playerYou,
                  tileCount: myHand.length,
                  isTurn: myTurn,
                  humanPersona:
                      AiPersona.all[account.avatarIndex % AiPersona.all.length],
                  avatarFrameId: account.effectiveFrameId(),
                  showBotBadge: false,
                  secondsLeft: timerOn ? match.secondsLeft : null,
                  secondsTotal: match.turnSeconds,
                  compact: compactBottom,
                ),
                const SizedBox(width: 8),
                _PlayerScoreBadge(
                  score: match.scores[0],
                  target: widget.rules.targetScore,
                  compact: compactBottom,
                ),
                const SizedBox(width: 8),
                CafePropWidget(
                  propId: account.effectiveCafePropId(),
                  size: compactBottom ? 28 : 34,
                  onTap: () {
                    final propTitle =
                        CafeShopCatalog.byId(
                          account.effectiveCafePropId(),
                        )?.title(isAr) ??
                        (isAr ? 'ضيافة المقهى' : 'Café Treat');
                    _showCafeCallout(
                      isAr
                          ? '${account.displayName}: $propTitle'
                          : '${account.displayName}: $propTitle',
                    );
                  },
                ),
                if (account.hasLuxuryQuickChat()) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _openSheikhPhrasePicker(isAr),
                    child: Container(
                      width: compactBottom ? 26 : 30,
                      height: compactBottom ? 26 : 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold.withValues(alpha: 0.18),
                        border: Border.all(color: AppColors.gold),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.gold,
                        size: compactBottom ? 14 : 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Clips horizontally to the inner boundaries of the player's wooden rack
/// (so >7 tiles clip cleanly on the left and right) while allowing extra
/// vertical space above the top edge so a selected 2-end tile can pop out
/// above the rack without being cut off.
class _HorizontalRackClipper extends CustomClipper<Rect> {
  const _HorizontalRackClipper({
    required this.horizontalInset,
    required this.topAllowance,
  });

  final double horizontalInset;
  final double topAllowance;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    horizontalInset,
    -topAllowance,
    size.width - horizontalInset,
    size.height,
  );

  @override
  bool shouldReclip(_HorizontalRackClipper oldClipper) =>
      oldClipper.horizontalInset != horizontalInset ||
      oldClipper.topAllowance != topAllowance;
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
    required this.hidden,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragCanceled,
  });

  final DominoPiece piece;
  final double width;
  final double feedbackWidth;
  final TileSkin skin;
  final bool playable;
  final bool dimmed;
  final bool selected;
  final bool hidden;
  final VoidCallback onTap;
  final VoidCallback onDragStarted;
  final void Function(Offset offset) onDragCanceled;

  @override
  Widget build(BuildContext context) {
    Widget tile = DominoTile(
      top: piece.low,
      bottom: piece.high,
      width: width,
      skin: skin,
    );

    if (playable && !hidden) {
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

    // A selected tile (two possible ends) rises visibly above the top edge
    // of the wooden rack so it clearly stands out while choosing a board end.
    tile = AnimatedScale(
      scale: selected ? 1.07 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: selected ? const Offset(0, -0.24) : Offset.zero,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: tile,
      ),
    );

    if (hidden) {
      tile = Opacity(opacity: 0, child: tile);
    }

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
      feedback: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(feedbackWidth * 0.16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: DominoTile(
          top: piece.low,
          bottom: piece.high,
          width: feedbackWidth,
          skin: skin,
        ),
      ),
      // Collapses smoothly via the parent AnimatedContainer while dragging.
      childWhenDragging: const SizedBox.shrink(),
      onDragStarted: onDragStarted,
      onDraggableCanceled: (_, offset) => onDragCanceled(offset),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      ),
    );
  }
}

/// A side opponent: compact card, score badge, and a vertical tile rack
/// emerging from the left or right screen edge.
class _SidePlayer extends StatelessWidget {
  const _SidePlayer({
    required this.name,
    this.aiPersona,
    required this.pieces,
    required this.revealed,
    required this.isTurn,
    required this.score,
    required this.target,
    required this.skin,
    required this.alignLeft,
  });

  final String name;
  final AiPersona? aiPersona;
  final List<DominoPiece> pieces;
  final bool revealed;
  final bool isTurn;
  final int score;
  final int target;
  final TileSkin skin;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      crossAxisAlignment:
          alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: alignLeft ? 3 : 0,
            right: alignLeft ? 0 : 3,
          ),
          child: PlayerChip(
            name: name,
            aiPersona: aiPersona,
            tileCount: pieces.length,
            isTurn: isTurn,
            compact: true,
          ),
        ),
        const SizedBox(height: 3),
        _PlayerScoreBadge(
          score: score,
          target: target,
          compact: true,
          flushLeft: alignLeft,
          flushRight: !alignLeft,
        ),
        const SizedBox(height: 5),
        _TileRack(
          pieces: pieces,
          revealed: revealed,
          skin: skin,
          tileWidth: 11,
          vertical: true,
          flushLeft: alignLeft,
          flushRight: !alignLeft,
        ),
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
        color: MaqhaColors.cardCharcoal.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MaqhaColors.borderSubtle),
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
        color: MaqhaColors.cardCharcoal,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
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

/// Compact score badge shown beside a player's chip (e.g. 23/151).
class _PlayerScoreBadge extends StatelessWidget {
  const _PlayerScoreBadge({
    required this.score,
    required this.target,
    this.compact = false,
    this.flushLeft = false,
    this.flushRight = false,
  });

  final int score;
  final int target;
  final bool compact;
  final bool flushLeft;
  final bool flushRight;

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.gold.withValues(alpha: 0.45);
    final side = BorderSide(color: borderColor);
    final radius = flushLeft
        ? const BorderRadius.horizontal(right: Radius.circular(10))
        : (flushRight
              ? const BorderRadius.horizontal(left: Radius.circular(10))
              : BorderRadius.circular(compact ? 10 : 12));

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: MaqhaColors.cardCharcoal,
        borderRadius: radius,
        border: Border(
          top: side,
          bottom: side,
          left: flushLeft ? BorderSide.none : side,
          right: flushRight ? BorderSide.none : side,
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$score',
                style: TextStyle(
                  color: AppColors.ivory,
                  fontSize: compact ? 11.5 : 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: '/$target',
                style: TextStyle(
                  color: AppColors.ivory.withValues(alpha: 0.7),
                  fontSize: compact ? 9.5 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Board-like wooden rack holding an opponent's tiles (face-down during play,
/// face-up when [revealed] is true at the end of a round).
class _TileRack extends StatelessWidget {
  const _TileRack({
    required this.pieces,
    required this.revealed,
    required this.skin,
    required this.tileWidth,
    this.vertical = false,
    this.flushLeft = false,
    this.flushRight = false,
  });

  final List<DominoPiece> pieces;
  final bool revealed;
  final TileSkin skin;
  final double tileWidth;
  final bool vertical;
  final bool flushLeft;
  final bool flushRight;

  Widget _buildRevealed() {
    final gap = tileWidth * 0.18;
    final children = <Widget>[];
    for (var i = 0; i < pieces.length; i++) {
      if (i > 0) {
        children.add(
          SizedBox(width: vertical ? 0 : gap, height: vertical ? gap : 0),
        );
      }
      final p = pieces[i];
      children.add(
        DominoTile(
          top: p.low,
          bottom: p.high,
          width: tileWidth,
          horizontal: vertical,
          skin: skin,
        ),
      );
    }
    return Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.gold.withValues(alpha: revealed ? 0.85 : 0.45);
    final side = BorderSide(color: borderColor, width: 1.2);
    final radius = flushLeft
        ? const BorderRadius.horizontal(right: Radius.circular(10))
        : (flushRight
              ? const BorderRadius.horizontal(left: Radius.circular(10))
              : BorderRadius.circular(10));

    // Reserve 7 slots so the rack stays a steady size as tiles are played.
    final sevenSpan = 7 * tileWidth + 6 * (tileWidth * 0.18);

    return Container(
      constraints: BoxConstraints(
        minWidth: vertical ? 0 : sevenSpan + 12,
        minHeight: vertical ? sevenSpan + 10 : tileWidth * 2 + 8,
      ),
      padding: EdgeInsets.fromLTRB(
        flushLeft ? 0 : (vertical ? 4 : 6),
        vertical ? 5 : 4,
        flushRight ? 0 : (vertical ? 4 : 6),
        vertical ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: MaqhaColors.cardCharcoal.withValues(alpha: 0.88),
        borderRadius: radius,
        border: Border(
          top: side,
          bottom: side,
          left: flushLeft ? BorderSide.none : side,
          right: flushRight ? BorderSide.none : side,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: vertical
          ? Alignment.topCenter
          : AlignmentDirectional.centerEnd,
      child: pieces.isEmpty
          ? SizedBox(
              width: tileWidth * 2,
              height: tileWidth * 2,
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: revealed
                  ? _buildRevealed()
                  : HiddenHand(
                      count: pieces.length,
                      skin: skin,
                      tileWidth: tileWidth,
                      vertical: vertical,
                    ),
            ),
    );
  }
}

/// Wooden 2-row boneyard drawing table shown in 2-player mode when seat 0 must
/// pick a tile. Tapped tiles vanish from their slot and appear in the player's
/// hand rack below.
class _BoneyardDrawBoard extends StatelessWidget {
  const _BoneyardDrawBoard({
    required this.slots,
    required this.skin,
    required this.onPick,
  });

  final List<DominoPiece?> slots;
  final TileSkin skin;
  final void Function(int slotIndex) onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MaqhaColors.bgSoftTeal, MaqhaColors.cardCharcoal],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.75),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xCC000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = ((constraints.maxWidth - 42) / 7).clamp(
              18.0,
              32.0,
            );
            final tileHeight = tileWidth * 2;

            Widget buildRow(int start, int end) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = start; i < end && i < slots.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: slots[i] == null
                          ? Container(
                              width: tileWidth,
                              height: tileHeight,
                              decoration: BoxDecoration(
                                color: const Color(0x44000000),
                                borderRadius: BorderRadius.circular(
                                  tileWidth * 0.16,
                                ),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.18),
                                ),
                              ),
                            )
                          : GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onPick(i),
                              child: DominoBack(
                                width: tileWidth,
                                skin: skin,
                              ),
                            ),
                    ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildRow(0, 7),
                const SizedBox(height: 8),
                buildRow(7, 14),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Visual points tally shown over the board at the end of a round while all
/// remaining tiles are revealed face-up (no "round ended" text dialog).
class _RoundTallyBadge extends StatelessWidget {
  const _RoundTallyBadge({
    required this.result,
    required this.fourPlayers,
  });

  final RoundResult result;
  final bool fourPlayers;

  @override
  Widget build(BuildContext context) {
    final burned = result.kind == RoundEndKind.burned;
    final weWon = result.winnerTeam == 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MaqhaColors.cardCharcoalElevated, MaqhaColors.cardCharcoal],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.85),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.35),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              burned
                  ? Icons.local_fire_department_rounded
                  : (weWon
                        ? Icons.emoji_events_rounded
                        : Icons.arrow_upward_rounded),
              color: AppColors.gold,
              size: 26,
            ),
            const SizedBox(width: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                burned ? '0' : '+${result.points}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact pill in the top corners of the table (boneyard count, round log).
class _TopInfoPill extends StatelessWidget {
  const _TopInfoPill({required this.icon, this.label, this.onTap});

  final IconData icon;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: label == null ? 9 : 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: MaqhaColors.cardCharcoal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MaqhaColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          if (label != null) ...[
            const SizedBox(width: 5),
            Text(
              label!,
              style: const TextStyle(
                color: AppColors.ivory,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

/// Dialog showing the points recorded for each completed round.
class _RoundHistoryDialog extends StatelessWidget {
  const _RoundHistoryDialog({
    required this.history,
    required this.ourTotal,
    required this.theirTotal,
    required this.fourPlayers,
  });

  final List<MatchRoundRecord> history;
  final int ourTotal;
  final int theirTotal;
  final bool fourPlayers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ourLabel = fourPlayers ? l10n.teamUs : l10n.playerYou;
    final theirLabel = fourPlayers ? l10n.teamThem : l10n.opponentSingle;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 380),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MaqhaColors.cardCharcoalElevated, MaqhaColors.cardCharcoal],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.gold,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.totalsLine(ourTotal, theirTotal),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Icon(
                  Icons.hourglass_empty_rounded,
                  color: AppColors.ivory,
                  size: 28,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 10,
                    color: AppColors.gold.withValues(alpha: 0.2),
                  ),
                  itemBuilder: (_, index) {
                    final entry = history[index];
                    final res = entry.result;
                    final burned = res.kind == RoundEndKind.burned;
                    final winner = burned
                        ? l10n.roundBurned
                        : (res.winnerTeam == 0 ? ourLabel : theirLabel);
                    final pts = burned ? '0' : '+${res.points}';
                    return Row(
                      children: [
                        Text(
                          '#${entry.round}',
                          style: TextStyle(
                            color: AppColors.gold.withValues(alpha: 0.9),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            winner,
                            style: const TextStyle(
                              color: AppColors.ivory,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          pts,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog shown when one side reaches [targetScore] and wins the match.
class _MatchResultDialog extends StatelessWidget {
  const _MatchResultDialog({
    required this.weWon,
    required this.ourTotal,
    required this.theirTotal,
    required this.targetScore,
    this.activeTournament,
  });

  final bool weWon;
  final int ourTotal;
  final int theirTotal;
  final int targetScore;
  final CafeTournamentTier? activeTournament;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final cup = activeTournament;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MaqhaColors.cardCharcoalElevated, MaqhaColors.cardCharcoal],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              weWon
                  ? Icons.emoji_events_rounded
                  : Icons.sentiment_dissatisfied_outlined,
              size: 54,
              color: AppColors.gold,
            ),
            const SizedBox(height: 12),
            Text(
              cup != null
                  ? (weWon
                        ? (isAr ? 'تُوجت بكأس البطولة' : 'Tournament Champion')
                        : (isAr ? 'انتهت رحلة البطولة' : 'Tournament Ended'))
                  : (weWon ? l10n.weWonRound : l10n.theyWonRound),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.targetScoreLabel(targetScore),
              style: TextStyle(
                color: AppColors.ivory.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.totalsLine(ourTotal, theirTotal),
              style: const TextStyle(
                color: AppColors.ivory,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (cup != null && weWon) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold),
                ),
                child: Text(
                  isAr
                      ? 'الجائزة الصافية: +${cup.netPrizeDinars} دينار المقهى  •  +${cup.bonusXpForWinner} XP'
                      : 'Net Prize: +${cup.netPrizeDinars} Dinars  •  +${cup.bonusXpForWinner} XP',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            if (cup == null) ...[
              SizedBox(
                width: double.infinity,
                child: GameButton(
                  label: l10n.play,
                  primary: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: GameButton(
                label: cup != null
                    ? (isAr ? 'العودة لقاعة البطولات' : 'Back to Tournaments')
                    : l10n.chooseMode,
                primary: cup != null,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}