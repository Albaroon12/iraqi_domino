import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../engine/dealer.dart';
import '../../engine/domino_piece.dart';
import '../../engine/game_rules_config.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/hidden_hand.dart';
import '../../rendering/tile_skin.dart';
import '../../rendering/wood_table.dart';
import '../../state/settings_provider.dart';
import '../widgets/game_button.dart';
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
  const GameScreen({
    super.key,
    required this.playerCount,
    required this.rules,
  }) : assert(playerCount == 2 || playerCount == 4);

  final int playerCount;
  final GameRulesConfig rules;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  /// Sample round results shown by the debug button: (kind, we won, points).
  static const List<(RoundEndKind, bool, int)> _sampleResults = [
    (RoundEndKind.domino, true, 23),
    (RoundEndKind.blocked, false, 14),
    (RoundEndKind.burned, true, 0),
  ];

  final math.Random _random = math.Random();
  late RoundSetup _round;
  int _turn = 0;
  int _sampleResultIndex = 0;

  bool get _four => widget.playerCount == 4;
  int get _topSeat => _four ? 2 : 1;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  /// Deals a new first round and gives the turn to the starting seat.
  void _deal() {
    _round = Dealer.dealFirstRound(widget.playerCount, _random);
    _turn = _round.startSeat;
  }

  void _showComingSoon() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.featureComingSoon)),
    );
  }

  void _showSampleResult() {
    final (kind, weWon, points) =
        _sampleResults[_sampleResultIndex % _sampleResults.length];
    _sampleResultIndex++;
    showRoundResultDialog(
      context,
      kind: kind,
      weWon: weWon,
      points: points,
      ourTotal: 48,
      theirTotal: 31,
    );
  }

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
    final piece = '${_round.startPiece.low}-${_round.startPiece.high}';
    return _round.startSeat == 0
        ? l10n.youStartRound(piece)
        : l10n.otherStartsRound(_seatName(l10n, _round.startSeat), piece);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final skin = TileSkin.byId(settings.tileSkinId);

    return Scaffold(
      appBar: AppBar(
        title: Text(_four ? l10n.modeFourPlayers : l10n.modeTwoPlayers),
        actions: [
          // Developer shortcuts: hidden in release builds.
          if (!kReleaseMode) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.redeal,
              onPressed: () => setState(_deal),
            ),
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: l10n.previewRoundResult,
              onPressed: _showSampleResult,
            ),
          ],
        ],
      ),
      body: WoodTable(
        child: SafeArea(
          child: Column(
            children: [
              ScoreBoard(
                ourLabel: _four ? l10n.teamUs : l10n.playerYou,
                theirLabel: _four ? l10n.teamThem : l10n.opponentSingle,
                ourScore: 0,
                theirScore: 0,
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

  /// The middle part: other players around the (still empty) line of play.
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
                  isTurn: _turn == _topSeat,
                ),
                const SizedBox(height: 8),
                HiddenHand(count: topCount, skin: skin, tileWidth: 18),
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
                isTurn: _turn == 3,
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
                isTurn: _turn == 1,
                skin: skin,
              ),
            ),
          ),

        // Center: the line of play is empty until step 3.2.
        Align(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _four ? 118 : 20),
            child: _BoardPlaceholder(message: _startMessage(l10n)),
          ),
        ),

        // 2 players: how many pieces are left in the draw pile.
        if (!_four)
          Align(
            alignment: const Alignment(0, 0.65),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
      ],
    );
  }

  /// The bottom part: your card, your real hand and the action button.
  Widget _buildBottomArea(AppLocalizations l10n, TileSkin skin) {
    final myHand = [..._round.hands[0]]..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerChip(
            name: l10n.playerYou,
            tileCount: myHand.length,
            isTurn: _turn == 0,
          ),
          const SizedBox(height: 8),
          // Size the tiles so seven always fit the screen width.
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth =
                  math.min(48.0, (constraints.maxWidth - 6 * 6) / 7);
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [
                  for (final piece in myHand)
                    _HandTile(
                      piece: piece,
                      width: tileWidth,
                      skin: skin,
                      // Before the first move, the only legal piece is the
                      // opening one, and only for the player whose turn it is.
                      playable: _turn == 0 && piece == _round.startPiece,
                      dimmed: _turn == 0 && piece != _round.startPiece,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 220,
            child: GameButton(
              label: _four ? l10n.passButton : l10n.drawButton,
              icon: Icons.skip_next_rounded,
              onPressed: _showComingSoon,
            ),
          ),
        ],
      ),
    );
  }
}

/// One tile of your hand: glows gold if it can be played, fades if not.
class _HandTile extends StatelessWidget {
  const _HandTile({
    required this.piece,
    required this.width,
    required this.skin,
    required this.playable,
    required this.dimmed,
  });

  final DominoPiece piece;
  final double width;
  final TileSkin skin;
  final bool playable;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: dimmed ? 0.4 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: playable
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.85),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              )
            : null,
        child: DominoTile(
          top: piece.low,
          bottom: piece.high,
          width: width,
          skin: skin,
        ),
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
        HiddenHand(count: tileCount, skin: skin, tileWidth: 16, vertical: true),
      ],
    );
  }
}

/// Placeholder for the line of play until step 3.2.
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