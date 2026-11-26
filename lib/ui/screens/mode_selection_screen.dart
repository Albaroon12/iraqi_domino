import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/maqha_design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/wood_table.dart';
import 'mode_hub_screen.dart';

/// Clean table-format selector (`لاعبان`, `أربعة لاعبين`, `أزنيف`).
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chooseMode)),
      body: WoodTable(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MaqhaModeCard(
                            icon: Icons.person_outline_rounded,
                            title: l10n.modeTwoPlayers,
                            subtitle: isAr ? 'مواجهة فردية' : '1 vs 1',
                            onTap: () => _openModeHub(context, 2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MaqhaModeCard(
                            icon: Icons.groups_rounded,
                            title: l10n.modeFourPlayers,
                            subtitle: isAr ? 'شراكة 2×2' : 'Teams 2×2',
                            onTap: () => _openModeHub(context, 4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: 0.5,
                      child: SizedBox(
                        width: double.infinity,
                        child: MaqhaModeCard(
                          icon: Icons.lock_outline_rounded,
                          title: l10n.modeAzneef,
                          subtitle: l10n.comingSoon,
                          onTap: null,
                        ),
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
