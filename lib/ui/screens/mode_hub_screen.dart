import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_difficulty.dart';
import '../../ai/ai_persona.dart';
import '../../core/constants/app_colors.dart';
import '../../engine/game_rules_config.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/wood_table.dart';
import '../../state/settings_provider.dart';
import '../localized_names.dart';
import '../widgets/ai_persona_avatar.dart';
import '../widgets/game_button.dart';
import 'game_screen.dart';
import 'local_multiplayer_screen.dart';
import 'online_friends_room_screen.dart';
import 'online_matchmaking_screen.dart';

/// Hub screen inside a chosen player-count mode (2 Players or 4 Players):
/// 1. Offline vs named AI characters (unlocked)
/// 2. Single "اللعب المحلي" button opening [LocalMultiplayerScreen] where the
///    player chooses the connection method (Offline Wi-Fi, Bluetooth, or Wi-Fi),
///    hosts with an automatic 4-digit room number, or joins by room number /
///    browsing available rooms.
/// 3. Online Matchmaking & Friends Room (locked until Phase 7 server).
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
    final four = playerCount == 4;

    final rules = GameRulesConfig(
      targetScore: settings.targetScore,
      aiDifficulty: settings.aiDifficulty,
    );

    final title = four ? l10n.modeFourPlayers : l10n.modeTwoPlayers;
    final vsAiLabel = isAr ? 'ضد الكمبيوتر' : 'Play vs AI';
    final vsAiDesc = isAr
        ? (four
              ? 'العب مع شريك وخصوم من شخصيات الذكاء الاصطناعي العشر'
              : 'واجه إحدى شخصيات الذكاء الاصطناعي العشر')
        : (four
              ? 'Team up & compete with the 10 named AI personas'
              : 'Challenge one of the 10 named AI personas');

    final localPlayLabel = isAr ? 'اللعب المحلي' : 'Local Play';
    final localPlayDesc = isAr
        ? 'اختر الطريقة: واي فاي بدون إنترنت • بلوتوث • Wi-Fi'
        : 'Choose method: Offline Wi-Fi • Bluetooth • Wi-Fi';

    final randomOnlineLabel = isAr ? 'لعب عشوائي (أونلاين)' : 'Random Match';
    final randomOnlineDesc = isAr
        ? 'بحث تلقائي عبر السيرفر (بحسابك أو كضيف) مع حلول AI مكان المنقطع'
        : 'Automatic server matchmaking with seamless AI bot takeover';

    final friendsRoomLabel = isAr
        ? (four ? 'غرفة أصدقاء (أونلاين)' : 'تحدي صديق (أونلاين)')
        : (four ? 'Online Friends Room' : 'Online Friend Match');
    final friendsRoomDesc = isAr
        ? (four
              ? 'أنشئ غرفة على السيرفر برقم تلقائي واختر المقاعد والشريك'
              : 'ادعُ صديقك عبر الإنترنت برقم الغرفة أو من الغرف المتاحة')
        : (four
              ? 'Create an online server room & pick team seats'
              : 'Invite a friend online via room number');

    return Scaffold(
      appBar: AppBar(toolbarHeight: 48, title: Text(title)),
      body: WoodTable(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Play vs AI
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xCC1D110A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isAr
                                      ? 'مستوى الذكاء الاصطناعي'
                                      : 'AI Difficulty',
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              for (var i = 0; i < 4; i++)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: AiPersonaAvatar(
                                    persona: AiPersona.all[i],
                                    size: 22,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final d in AiDifficulty.values)
                                ChoiceChip(
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  label: Text(
                                    aiDifficultyName(isAr, d),
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  selected: settings.aiDifficulty == d,
                                  onSelected: (_) =>
                                      notifier.setAiDifficulty(d),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: GameButton(
                              label: vsAiLabel,
                              subtitle: vsAiDesc,
                              icon: Icons.smart_toy_outlined,
                              primary: true,
                              onPressed: () => _startVsAi(context, rules),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Single "Local Play" Button -> opens method & room hub
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        label: localPlayLabel,
                        subtitle: localPlayDesc,
                        icon: Icons.wifi_tethering_rounded,
                        primary: true,
                        onPressed: () => _openLocalPlay(context),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. Online Friends Room (UNLOCKED in Step 7.4!)
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        label: friendsRoomLabel,
                        subtitle: friendsRoomDesc,
                        icon: Icons.cloud_outlined,
                        primary: true,
                        onPressed: () => _openOnlineFriendsRoom(context),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 4. Online Random Matchmaking (UNLOCKED in Step 7.5!)
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        label: randomOnlineLabel,
                        subtitle: randomOnlineDesc,
                        icon: Icons.public_rounded,
                        primary: true,
                        onPressed: () =>
                            _startOnlineRandomMatch(context, rules),
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
