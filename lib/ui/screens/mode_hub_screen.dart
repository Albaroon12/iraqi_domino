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

/// Hub screen inside a chosen player-count mode (2 Players or 4 Players),
/// presenting all ways to play that mode:
/// - Offline vs named AI characters (unlocked and playable now)
/// - Local Wi-Fi Direct / Bluetooth (locked until Phase 6 LAN/Nearby is enabled)
/// - Random Online Matchmaking with AI disconnect takeover (locked until Phase 7)
/// - Private Room / Invite Friends with seat selection (locked until Phase 7)
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

    final randomOnlineLabel = isAr ? 'لعب عشوائي (أونلاين)' : 'Random Match';
    final randomOnlineDesc = isAr
        ? 'قريباً — بحث تلقائي مع حلول AI مكان المنقطع حتى دخول بديل'
        : 'Coming soon — Matchmaking with seamless AI bot takeover';

    final friendsRoomLabel = isAr
        ? (four ? 'غرفة أصدقاء (اختيار المقاعد)' : 'تحدي صديق (كود أو دعوة)')
        : (four ? 'Friends Room (Seat Picker)' : 'Play with Friend (Code)');
    final friendsRoomDesc = isAr
        ? (four
              ? 'قريباً — أنشئ غرفة لـ 4 أصدقاء بالكود واختر مكانك ضد زميلك'
              : 'قريباً — ادعُ صديقك بكود غرفة أو دعوة داخل اللعبة')
        : (four
              ? 'Coming soon — Invite 4 friends by code & pick team seats'
              : 'Coming soon — Invite a friend via room code or in-game invite');

    final nearbyLabel = isAr
        ? 'واي فاي مباشر / بلوتوث'
        : 'Wi-Fi Direct / Bluetooth';
    final nearbyDesc = isAr
        ? 'قريباً — العب مع أصدقائك القريبين بدون إنترنت'
        : 'Coming soon — Play with friends nearby offline';

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
                    // Active Mode: Vs AI + AI Difficulty + Persona preview
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
                              // Mini preview of 4 AI persona portraits
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
                    // Locked Online & Local Direct options (enabled as each phase lands)
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        label: randomOnlineLabel,
                        subtitle: randomOnlineDesc,
                        icon: Icons.lock_outline,
                        onPressed: null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        label: friendsRoomLabel,
                        subtitle: friendsRoomDesc,
                        icon: Icons.lock_outline,
                        onPressed: null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        label: nearbyLabel,
                        subtitle: nearbyDesc,
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
