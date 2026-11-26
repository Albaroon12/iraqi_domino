import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_difficulty.dart';
import '../../core/network/connectivity_provider.dart';
import '../../core/theme/maqha_design_system.dart';
import '../../engine/game_rules_config.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/wood_table.dart';
import '../../state/settings_provider.dart';
import '../localized_names.dart';
import 'game_screen.dart';
import 'local_multiplayer_screen.dart';
import 'online_friends_room_screen.dart';
import 'online_matchmaking_screen.dart';

/// Clean mode hub inside 2 Players or 4 Players, styled with Matte Charcoal
/// cards and concise 2-word subtitles.
class ModeHubScreen extends ConsumerWidget {
  const ModeHubScreen({super.key, required this.playerCount})
    : assert(playerCount == 2 || playerCount == 4);

  final int playerCount;

  void _startVsAi(BuildContext context, GameRulesConfig rules) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(playerCount: playerCount, rules: rules),
      ),
    );
  }

  void _openLocalPlay(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalMultiplayerScreen(playerCount: playerCount),
      ),
    );
  }

  void _openOnlineFriendsRoom(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnlineFriendsRoomScreen(playerCount: playerCount),
      ),
    );
  }

  void _startOnlineRandomMatch(BuildContext context, GameRulesConfig rules) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnlineMatchmakingScreen(
          playerCount: playerCount,
          rules: rules,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final conn = ref.watch(connectivityProvider);
    final four = playerCount == 4;

    final rules = GameRulesConfig(
      targetScore: settings.targetScore,
      aiDifficulty: settings.aiDifficulty,
    );

    final title = four ? l10n.modeFourPlayers : l10n.modeTwoPlayers;

    return Scaffold(
      appBar: AppBar(toolbarHeight: 48, title: Text(title)),
      body: WoodTable(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 370),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (conn.isOnline) ...[
                      SizedBox(
                        width: double.infinity,
                        child: MaqhaGoldPillButton(
                          label: isAr ? 'لعب عشوائي (أونلاين)' : 'Random Match',
                          onPressed: () =>
                              _startOnlineRandomMatch(context, rules),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // AI Difficulty Selector Strip
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: MaqhaColors.cardCharcoal,
                        borderRadius: MaqhaRadii.modeCard,
                        border: Border.all(color: MaqhaColors.borderSubtle),
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final d in AiDifficulty.values)
                            ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                aiDifficultyName(isAr, d),
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              selected: settings.aiDifficulty == d,
                              onSelected: (_) => notifier.setAiDifficulty(d),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: MaqhaModeCard(
                            icon: Icons.school_outlined,
                            title: isAr ? 'ضد الكمبيوتر' : 'Play vs AI',
                            subtitle: isAr ? 'بدون إنترنت' : 'Offline',
                            onTap: () => _startVsAi(context, rules),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MaqhaModeCard(
                            icon: Icons.wifi_tethering_rounded,
                            title: isAr ? 'اللعب المحلي' : 'Local Play',
                            subtitle: isAr ? 'بلوتوث • واي فاي' : 'Nearby P2P',
                            onTap: () => _openLocalPlay(context),
                          ),
                        ),
                      ],
                    ),

                    if (conn.isOnline) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: MaqhaModeCard(
                          icon: Icons.key_rounded,
                          title: isAr
                              ? (four
                                    ? 'غرفة أصدقاء (أونلاين)'
                                    : 'تحدي صديق (أونلاين)')
                              : 'Online Friends Room',
                          subtitle: isAr ? 'كود غرفة خاص' : 'Private code',
                          onTap: () => _openOnlineFriendsRoom(context),
                        ),
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
