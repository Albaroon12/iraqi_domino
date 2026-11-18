import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/tile_skin.dart';

/// Temporary developer screen: shows all 28 tiles so we can judge the
/// look at different sizes and in different skins. Removed before release.
class TileGalleryScreen extends StatefulWidget {
  const TileGalleryScreen({super.key});

  @override
  State<TileGalleryScreen> createState() => _TileGalleryScreenState();
}

class _TileGalleryScreenState extends State<TileGalleryScreen> {
  double _tileWidth = 48;
  TileSkin _skin = TileSkin.ivory;

  /// All 28 tiles of a double-six set: (0,0), (0,1) ... (6,6).
  static final List<(int, int)> _allTiles = [
    for (var a = 0; a <= 6; a++)
      for (var b = a; b <= 6; b++) (a, b),
  ];

  String _skinName(AppLocalizations l10n, TileSkin skin) => switch (skin.id) {
    'ebony' => l10n.skinEbony,
    'ruby' => l10n.skinRuby,
    _ => l10n.skinIvory,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tileGallery)),
      body: Column(
        children: [
          // Skin selector.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final skin in TileSkin.all)
                  ChoiceChip(
                    label: Text(_skinName(l10n, skin)),
                    selected: _skin.id == skin.id,
                    onSelected: (_) => setState(() => _skin = skin),
                  ),
              ],
            ),
          ),
          // Slider to test how the tiles look at different sizes.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  _tileWidth.round().toString(),
                  style: const TextStyle(color: AppColors.ivory),
                ),
                Expanded(
                  child: Slider(
                    value: _tileWidth,
                    min: 24,
                    max: 90,
                    onChanged: (v) => setState(() => _tileWidth = v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 18,
                runSpacing: 22,
                children: [
                  for (final (a, b) in _allTiles)
                    DominoTile(
                      top: a,
                      bottom: b,
                      width: _tileWidth,
                      skin: _skin,
                    ),
                  // One horizontal sample to check rotation.
                  DominoTile(
                    top: 6,
                    bottom: 6,
                    width: _tileWidth,
                    horizontal: true,
                    skin: _skin,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
