import 'package:flutter/widgets.dart';

import 'tile_skin.dart';

/// A face-down domino tile (used for hidden hands of the other players).
///
/// [width] is the short side; the long side is 2 x [width].
/// When [horizontal] is true the tile lies on its side.
class DominoBack extends StatelessWidget {
  const DominoBack({
    super.key,
    this.width = 20,
    this.horizontal = false,
    this.skin = TileSkin.ivory,
  });

  final double width;
  final bool horizontal;
  final TileSkin skin;

  @override
  Widget build(BuildContext context) {
    final w = horizontal ? width * 2 : width;
    final h = horizontal ? width : width * 2;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [skin.bodyLight, skin.bodyDark],
        ),
        border: Border.all(color: skin.bevelDark, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0x66000000),
            blurRadius: width * 0.25,
            offset: Offset(width * 0.05, width * 0.12),
          ),
        ],
      ),
      // A thin line in the middle, so it still reads as a domino.
      child: Center(
        child: Container(
          width: horizontal ? 1.5 : width * 0.6,
          height: horizontal ? width * 0.6 : 1.5,
          color: skin.grooveColor,
        ),
      ),
    );
  }
}
