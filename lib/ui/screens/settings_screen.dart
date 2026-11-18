import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/tile_skin.dart';
import '../../rendering/wood_table.dart';
import '../../state/settings_provider.dart';
import '../localized_names.dart';

/// Settings: language, target score, tile skin and sound.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    // read(...notifier) gives the object that changes the settings.
    final notifier = ref.read(settingsProvider.notifier);
    final skin = TileSkin.byId(settings.tileSkinId);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: WoodTable(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            children: [
              _Section(
                title: l10n.settingsLanguage,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('العربية')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {settings.languageCode},
                  onSelectionChanged: (selection) =>
                      notifier.setLanguage(selection.first),
                ),
              ),
              _Section(
                title: l10n.settingsTargetScore,
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final score in SettingsState.targetScoreOptions)
                      ChoiceChip(
                        label: Text('$score'),
                        selected: settings.targetScore == score,
                        onSelected: (_) => notifier.setTargetScore(score),
                      ),
                  ],
                ),
              ),
              _Section(
                title: l10n.settingsTileSkin,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final s in TileSkin.all)
                          ChoiceChip(
                            label: Text(tileSkinName(l10n, s)),
                            selected: settings.tileSkinId == s.id,
                            onSelected: (_) => notifier.setTileSkin(s.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Live preview of the chosen skin.
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DominoTile(top: 6, bottom: 6, width: 40, skin: skin),
                          const SizedBox(width: 14),
                          DominoTile(top: 2, bottom: 5, width: 40, skin: skin),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _Section(
                title: l10n.settingsSound,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Switch(
                    value: settings.soundEnabled,
                    onChanged: notifier.setSound,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled dark panel that groups one setting.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xCC1D110A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
