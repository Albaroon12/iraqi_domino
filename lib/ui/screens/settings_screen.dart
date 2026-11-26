import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_difficulty.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/maqha_design_system.dart';
import '../../data/game_data_center.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/tile_skin.dart';
import '../../rendering/wood_table.dart';
import '../../state/settings_provider.dart';
import '../localized_names.dart';
import 'about_legal_screen.dart';

/// Settings: language, target score, AI difficulty, tile skin and sound.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final settings = ref.watch(settingsProvider);
    final account = ref.watch(gameDataCenterProvider);
    // read(...notifier) gives the object that changes the settings.
    final notifier = ref.read(settingsProvider.notifier);
    final skin = TileSkin.byId(settings.tileSkinId);
    final ownedSkins = [
      for (final s in TileSkin.all)
        if (s.id == 'ivory' ||
            s.id == settings.tileSkinId ||
            account.isItemOwned('tile_${s.id}'))
          s,
    ];

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
                title: isAr ? 'مستوى الذكاء الاصطناعي' : 'AI Difficulty',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in AiDifficulty.values)
                      ChoiceChip(
                        label: Text(aiDifficultyName(isAr, d)),
                        selected: settings.aiDifficulty == d,
                        onSelected: (_) => notifier.setAiDifficulty(d),
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
                      runSpacing: 8,
                      children: [
                        for (final s in ownedSkins)
                          ChoiceChip(
                            label: Text(tileSkinName(l10n, s)),
                            selected: settings.tileSkinId == s.id,
                            onSelected: (_) => notifier.setTileSkin(s.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAr
                          ? 'المزيد من الأطقم متاح في السوق'
                          : 'More sets available in Shop',
                      style: const TextStyle(
                        color: MaqhaColors.textMuted,
                        fontSize: 11.5,
                      ),
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.settingsSound,
                          style: const TextStyle(
                            color: AppColors.ivory,
                            fontSize: 14,
                          ),
                        ),
                        Switch(
                          value: settings.soundEnabled,
                          onChanged: notifier.setSound,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'أجواء المقهى العراقي'
                              : 'Iraqi café ambience',
                          style: const TextStyle(
                            color: AppColors.ivory,
                            fontSize: 14,
                          ),
                        ),
                        Switch(
                          value: settings.ambientEnabled,
                          onChanged: notifier.setAmbientSound,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _Section(
                title: isAr ? 'المعلومات والخصوصية والحساب' : 'About, Privacy & Account',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AboutLegalScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.privacy_tip_outlined,
                        color: AppColors.gold,
                        size: 18,
                      ),
                      label: Text(
                        isAr
                            ? 'حول المقهى وسياسة الخصوصية والشروط'
                            : 'About Al-Maqha, Privacy & Fair Play',
                        style: const TextStyle(color: AppColors.ivory),
                      ),
                    ),
                    if (account.isAuthenticated) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _confirmDeleteAccount(context, ref, isAr),
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          color: Color(0xFFEF5350),
                          size: 19,
                        ),
                        label: Text(
                          isAr
                              ? 'حذف الحساب نهائياً'
                              : 'Delete Account Permanently',
                          style: const TextStyle(
                            color: Color(0xFFEF5350),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
    bool isAr,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MaqhaColors.cardCharcoal,
        title: Text(
          isAr ? 'حذف الحساب نهائياً؟' : 'Delete Account Permanently?',
          style: const TextStyle(color: Color(0xFFEF5350), fontSize: 16.5),
        ),
        content: Text(
          isAr
              ? 'سيتم حذف حسابك وجميع بياناتك وإحصائياتك ودنانيرك نهائياً ولا يمكن التراجع عن هذا الإجراء.'
              : 'Your account, stats, and Dinars will be permanently deleted. This action cannot be undone.',
          style: const TextStyle(color: AppColors.ivory, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isAr ? 'تراجع' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              isAr ? 'نعم، احذف حسابي' : 'Delete Forever',
              style: const TextStyle(
                color: Color(0xFFEF5350),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref
          .read(gameDataCenterProvider.notifier)
          .deleteMyAccountPermanently();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAr
                  ? 'تم حذف الحساب نهائياً والعودة لوضع الضيف.'
                  : 'Account deleted permanently.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
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
        color: MaqhaColors.cardCharcoal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MaqhaColors.borderSubtle),
        boxShadow: MaqhaShadows.cardShadow,
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
