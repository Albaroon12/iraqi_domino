import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/wood_table.dart';
import '../widgets/game_button.dart';
import 'mode_selection_screen.dart';
import 'settings_screen.dart';
import 'table_preview_screen.dart';
import 'tile_gallery_screen.dart';

/// The main menu: first screen the player sees.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: WoodTable(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Decorative logo: three tiles.
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DominoTile(top: 3, bottom: 5, width: 38),
                        SizedBox(width: 14),
                        DominoTile(top: 6, bottom: 6, width: 38),
                        SizedBox(width: 14),
                        DominoTile(top: 1, bottom: 4, width: 38),
                      ],
                    ),
                    const SizedBox(height: 28),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.appTitle,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(
                                  color: Color(0xAA000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        label: l10n.play,
                        icon: Icons.play_arrow_rounded,
                        primary: true,
                        onPressed: () =>
                            _open(context, const ModeSelectionScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        label: l10n.settings,
                        icon: Icons.settings_outlined,
                        onPressed: () =>
                            _open(context, const SettingsScreen()),
                      ),
                    ),
                    // Developer shortcuts: visible only in debug runs.
                    if (!kReleaseMode) ...[
                      const SizedBox(height: 28),
                      TextButton(
                        onPressed: () =>
                            _open(context, const TileGalleryScreen()),
                        child: Text(l10n.tileGallery),
                      ),
                      TextButton(
                        onPressed: () =>
                            _open(context, const TablePreviewScreen()),
                        child: Text(l10n.tablePreview),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}