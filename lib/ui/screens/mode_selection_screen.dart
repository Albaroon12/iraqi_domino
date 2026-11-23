import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../rendering/wood_table.dart';
import '../../state/settings_provider.dart';
import '../widgets/game_button.dart';
import 'mode_hub_screen.dart';

/// Lets the player choose the main Domino table format: 2 Players, 4 Players,
/// or Azneef (locked). Each format opens its dedicated [ModeHubScreen].
class ModeSelectionScreen extends ConsumerWidget {
  const ModeSelectionScreen({super.key});

  void _openModeHub(BuildContext context, int playerCount) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ModeHubScreen(playerCount: playerCount),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final targetScore = ref.watch(settingsProvider).targetScore;
    final targetText = l10n.targetScoreLabel(targetScore);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chooseMode)),
      body: WoodTable(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        label: l10n.modeTwoPlayers,
                        subtitle: '${l10n.modeTwoPlayersDesc}\n$targetText',
                        icon: Icons.person_outline,
                        primary: true,
                        onPressed: () => _openModeHub(context, 2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        label: l10n.modeFourPlayers,
                        subtitle: '${l10n.modeFourPlayersDesc}\n$targetText',
                        icon: Icons.groups_outlined,
                        primary: true,
                        onPressed: () => _openModeHub(context, 4),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Azneef rules are not defined yet: the button is disabled.
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        label: l10n.modeAzneef,
                        subtitle: l10n.comingSoon,
                        icon: Icons.lock_outline,
                        onPressed: null,
                      ),
                    ),
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
