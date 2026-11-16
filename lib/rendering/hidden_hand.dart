import 'package:flutter/widgets.dart';

import 'domino_back.dart';
import 'tile_skin.dart';

/// A row (or column) of face-down tiles that shows how many tiles
/// another player still holds.
class HiddenHand extends StatelessWidget {
  const HiddenHand({
    super.key,
    required this.count,
    required this.skin,
    this.tileWidth = 18,
    this.vertical = false,
  });

  final int count;
  final TileSkin skin;
  final double tileWidth;

  /// true: tiles are stacked in a column (side players).
  /// false: tiles are placed in a row (top player).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final gap = tileWidth * 0.18;
    final children = <Widget>[];

    for (var i = 0; i < count; i++) {
      if (i > 0) {
        children.add(SizedBox(
          width: vertical ? 0 : gap,
          height: vertical ? gap : 0,
        ));
      }
      children.add(DominoBack(
        width: tileWidth,
        horizontal: vertical,
        skin: skin,
      ));
    }

    return Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}