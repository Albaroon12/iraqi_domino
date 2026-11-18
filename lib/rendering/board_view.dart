import 'package:flutter/widgets.dart';

import '../core/constants/app_colors.dart';
import '../engine/board.dart';
import 'board_layout.dart';
import 'domino_tile.dart';
import 'tile_skin.dart';

/// Draws the line of play and the "ghost" places where the next piece goes.
/// Only draws: the game screen decides which ends are active or lit.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.board,
    required this.skin,
    required this.leftKey,
    required this.rightKey,
    this.ghostDouble = false,
    this.activeEnds = const [],
    this.litEnds = const {},
    this.onSlotTap,
  });

  final Board board;
  final TileSkin skin;

  /// Keys on the two ghost places, so the screen can find where they are.
  final GlobalKey leftKey;
  final GlobalKey rightKey;

  /// The piece being moved is a double (its ghost stands crosswise).
  final bool ghostDouble;

  /// Ends where the held piece can go (their ghost is visible).
  final List<BoardEnd> activeEnds;

  /// Ends drawn bright gold; the other active ends are faint.
  final Set<BoardEnd> litEnds;

  final void Function(BoardEnd end)? onSlotTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final layout = BoardLayout.fit(
          board,
          box.maxWidth,
          box.maxHeight,
          ghostDouble: ghostDouble,
        );
        final w = layout.tileWidth;

        Widget slot(BoardEnd end, GlobalKey key, LayoutBox b) => Positioned(
          left: b.left,
          top: b.top,
          width: b.width,
          height: b.height,
          child: _Slot(
            key: key,
            visible: activeEnds.contains(end),
            lit: litEnds.contains(end),
            radius: w * 0.18,
            onTap: onSlotTap == null ? null : () => onSlotTap!(end),
          ),
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final t in layout.tiles)
              Positioned(left: t.box.left, top: t.box.top, child: _tile(t, w)),
            if (!board.isEmpty) slot(BoardEnd.left, leftKey, layout.leftSlot),
            slot(BoardEnd.right, rightKey, layout.rightSlot),
          ],
        );
      },
    );
  }

  Widget _tile(LaidTile t, double w) {
    // Vertical box: no rotation, the first value is the top half.
    if (t.isVertical) {
      return DominoTile(
        top: t.firstValue,
        bottom: t.secondValue,
        width: w,
        skin: skin,
      );
    }
    // Horizontal box: the tile is turned clockwise, so its "top" half ends
    // up on the right and its "bottom" half on the left.
    return DominoTile(
      top: t.secondValue,
      bottom: t.firstValue,
      width: w,
      horizontal: true,
      skin: skin,
    );
  }
}

/// A ghost place: bright gold = the piece will land here; faint = possible.
///
/// It appears with a short fade but disappears INSTANTLY. Otherwise, after
/// a piece is played, the ghost would fade out at its new position and show
/// as a quick flash.
class _Slot extends StatelessWidget {
  const _Slot({
    super.key,
    required this.visible,
    required this.lit,
    required this.radius,
    required this.onTap,
  });

  final bool visible;
  final bool lit;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fade = visible ? const Duration(milliseconds: 150) : Duration.zero;

    return IgnorePointer(
      ignoring: !visible,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: fade,
          child: AnimatedContainer(
            duration: fade,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: lit
                  ? AppColors.gold.withValues(alpha: 0.35)
                  : const Color(0x00000000),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: lit ? 1 : 0.45),
                width: lit ? 2.5 : 1.5,
              ),
              boxShadow: lit
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.6),
                        blurRadius: 14,
                      ),
                    ]
                  : const [],
            ),
          ),
        ),
      ),
    );
  }
}
