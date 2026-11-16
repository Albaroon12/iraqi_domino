import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/tile_skin.dart';
import '../../rendering/wood_table.dart';

/// Temporary developer screen: the wooden table with a sample line of
/// play and a sample hand. Used to judge the look. Replaced in step 2.3.
class TablePreviewScreen extends StatefulWidget {
  const TablePreviewScreen({super.key});

  @override
  State<TablePreviewScreen> createState() => _TablePreviewScreenState();
}

class _TablePreviewScreenState extends State<TablePreviewScreen> {
  int _skinIndex = 0;

  /// Sample hand of seven tiles.
  static const List<(int, int)> _hand = [
    (0, 1), (2, 3), (4, 4), (1, 6), (5, 2), (3, 3), (6, 0),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final skin = TileSkin.all[_skinIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tablePreview),
        actions: [
          // Cycles through the tile skins.
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => setState(
              () => _skinIndex = (_skinIndex + 1) % TileSkin.all.length,
            ),
          ),
        ],
      ),
      body: WoodTable(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Size the hand so seven tiles always fit the screen width.
            final handTileWidth =
                math.min(48.0, (constraints.maxWidth - 48 - 6 * 6) / 7);
            const lineTileWidth = 36.0;

            return Column(
              children: [
                // Sample line of play: 4|2  2|6  6|6 (double, crosswise)  6|3
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        DominoTile(
                          top: 2, bottom: 4, width: lineTileWidth,
                          horizontal: true, skin: skin,
                        ),
                        const SizedBox(width: 2),
                        DominoTile(
                          top: 6, bottom: 2, width: lineTileWidth,
                          horizontal: true, skin: skin,
                        ),
                        const SizedBox(width: 2),
                        DominoTile(
                          top: 6, bottom: 6, width: lineTileWidth, skin: skin,
                        ),
                        const SizedBox(width: 2),
                        DominoTile(
                          top: 3, bottom: 6, width: lineTileWidth,
                          horizontal: true, skin: skin,
                        ),
                      ],
                    ),
                  ),
                ),
                // The player's hand at the bottom.
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    children: [
                      for (final (a, b) in _hand)
                        DominoTile(
                          top: a, bottom: b, width: handTileWidth, skin: skin,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}