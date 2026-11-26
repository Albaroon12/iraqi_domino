import 'package:flutter/widgets.dart';

import '../core/theme/maqha_design_system.dart';
import 'table_skin.dart';

/// Renders the app-wide Emerald-Teal canvas with warm center spotlight and
/// subtle translucent Domino silhouettes (`MaqhaEmeraldBackground`).
class WoodTable extends StatelessWidget {
  const WoodTable({super.key, this.skin = TableSkin.walnut, this.child});

  final TableSkin skin;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return MaqhaEmeraldBackground(
      child: child ?? const SizedBox.expand(),
    );
  }
}
