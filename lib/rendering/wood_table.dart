import 'package:flutter/widgets.dart';

import 'table_skin.dart';
import 'wood_table_painter.dart';

/// A wooden table that fills its parent. Put game content in [child].
class WoodTable extends StatelessWidget {
  const WoodTable({
    super.key,
    this.skin = TableSkin.walnut,
    this.child,
  });

  final TableSkin skin;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary caches the heavy drawing, so moving tiles above it
    // does not force the wood to be painted again.
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: WoodTablePainter(skin: skin),
          child: child,
        ),
      ),
    );
  }
}