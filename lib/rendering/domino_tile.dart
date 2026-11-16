import 'package:flutter/widgets.dart';

import 'domino_tile_painter.dart';
import 'tile_skin.dart';

/// A domino tile widget. Use this in screens instead of the painter.
///
/// [width] is the tile's short side; the long side is always 2 x [width].
/// When [horizontal] is true the tile is rotated a quarter turn.
class DominoTile extends StatelessWidget {
  const DominoTile({
    super.key,
    required this.top,
    required this.bottom,
    this.width = 48,
    this.horizontal = false,
    this.skin = TileSkin.ivory,
  })  : assert(top >= 0 && top <= 6),
        assert(bottom >= 0 && bottom <= 6);

  final int top;
  final int bottom;
  final double width;
  final bool horizontal;
  final TileSkin skin;

  @override
  Widget build(BuildContext context) {
    final tile = SizedBox(
      width: width,
      height: width * 2,
      child: CustomPaint(
        painter: DominoTilePainter(top: top, bottom: bottom, skin: skin),
      ),
    );

    return horizontal ? RotatedBox(quarterTurns: 1, child: tile) : tile;
  }
}