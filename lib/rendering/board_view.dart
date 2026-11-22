import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/constants/app_colors.dart';
import '../engine/board.dart';
import '../engine/domino_piece.dart';
import 'board_layout.dart';
import 'serpentine_layout.dart';
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
    this.lastPlacedPiece,
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

  /// Most recently played piece, subtly highlighted so players can spot it.
  final DominoPiece? lastPlacedPiece;

  final void Function(BoardEnd end)? onSlotTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final fitted = _fitLayout(
          board,
          box.maxWidth,
          box.maxHeight,
          ghostDouble,
        );
        final layout = fitted.layout;
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
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: fitted.dx,
              top: fitted.dy,
              width: box.maxWidth,
              height: box.maxHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final t in layout.tiles)
                    Positioned(
                      left: t.box.left,
                      top: t.box.top,
                      child: _buildPlacedTile(t, w),
                    ),
                  if (!board.isEmpty)
                    slot(BoardEnd.left, leftKey, layout.leftSlot),
                  slot(BoardEnd.right, rightKey, layout.rightSlot),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Keeps all placed tiles inside the board without changing the snake path:
  /// first pans smoothly toward the empty space; only if the entire board span
  /// is exceeded does it step [tileWidth] down as a fallback.
  static ({SerpentineLayout layout, double dx, double dy}) _fitLayout(
    Board board,
    double width,
    double height,
    bool ghostDouble,
  ) {
    var layout = SerpentineLayout.fit(
      board,
      width,
      height,
      ghostDouble: ghostDouble,
    );
    if (!layout.overflow || layout.tiles.isEmpty) {
      return (layout: layout, dx: 0, dy: 0);
    }

    const pad = 4.0;
    final availW = math.max(0.0, width - 2 * pad);
    final availH = math.max(0.0, height - 2 * pad);

    var bounds = _bounds(layout.tiles);
    var w = layout.tileWidth;
    while ((bounds.width > availW || bounds.height > availH) &&
        w > SerpentineLayout.minTileWidth) {
      w = math.max(SerpentineLayout.minTileWidth, w - 1);
      layout = SerpentineLayout.compute(
        board,
        width,
        height,
        w,
        ghostDouble: ghostDouble,
      );
      bounds = _bounds(layout.tiles);
    }

    var dx = 0.0;
    if (bounds.width > availW) {
      dx = (width - (bounds.left + bounds.right)) / 2;
    } else if (bounds.left < pad) {
      dx = pad - bounds.left;
    } else if (bounds.right > width - pad) {
      dx = (width - pad) - bounds.right;
    }

    var dy = 0.0;
    if (bounds.height > availH) {
      dy = (height - (bounds.top + bounds.bottom)) / 2;
    } else if (bounds.top < pad) {
      dy = pad - bounds.top;
    } else if (bounds.bottom > height - pad) {
      dy = (height - pad) - bounds.bottom;
    }

    return (layout: layout, dx: dx, dy: dy);
  }

  static ({
    double left,
    double top,
    double right,
    double bottom,
    double width,
    double height,
  })
  _bounds(List<LaidTile> tiles) {
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    for (final t in tiles) {
      final b = t.box;
      if (b.left < left) left = b.left;
      if (b.top < top) top = b.top;
      if (b.right > right) right = b.right;
      if (b.bottom > bottom) bottom = b.bottom;
    }
    return (
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: right - left,
      height: bottom - top,
    );
  }

  Widget _buildPlacedTile(LaidTile t, double w) {
    final child = _tile(t, w);
    final last = lastPlacedPiece;
    if (last == null) return child;
    final matches =
        math.min(t.firstValue, t.secondValue) == last.low &&
        math.max(t.firstValue, t.secondValue) == last.high;
    if (!matches) return child;

    return TweenAnimationBuilder<double>(
      key: ValueKey('last-$last'),
      tween: Tween(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, glow, c) {
        if (glow <= 0.01) return c!;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(w * 0.18),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.65 * glow),
                blurRadius: 10 * glow,
                spreadRadius: 1.5 * glow,
              ),
            ],
          ),
          child: c,
        );
      },
      child: child,
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
