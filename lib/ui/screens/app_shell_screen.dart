import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../core/games/game_catalog.dart';
import '../../data/game_data_center.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/tile_skin.dart';
import '../../state/settings_provider.dart';
import '../localized_names.dart';
import '../widgets/game_button.dart';
import 'auth_screen.dart';
import 'mode_selection_screen.dart';
import 'settings_screen.dart';
import 'table_preview_screen.dart';
import 'tile_gallery_screen.dart';

/// Main application shell with a modern 5-tab bottom navigation bar:
/// 0 = Games catalog, 1 = Challenges, 2 = Home (center, default),
/// 3 = Shop (tile skins & future items), 4 = Profile & Settings.
class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({super.key});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  int _tabIndex = 2;

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.1,
            colors: [
              Color(0xFF2B1A11),
              Color(0xFF180F0A),
              Color(0xFF0C0704),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tabIndex,
            children: [
              _GamesTab(
                isAr: isAr,
                onOpenGame: (entry) {
                  final builder = entry.builder;
                  if (entry.available && builder != null) {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: builder));
                  }
                },
              ),
              _ChallengesTab(isAr: isAr),
              _HomeTab(
                l10n: l10n,
                isAr: isAr,
                onQuickPlay: () => _open(const ModeSelectionScreen()),
                onOpenSettings: () => _open(const SettingsScreen()),
                onViewAllGames: () => setState(() => _tabIndex = 0),
              ),
              _ShopTab(l10n: l10n, isAr: isAr),
              _ProfileTab(
                l10n: l10n,
                isAr: isAr,
                onOpenSettings: () => _open(const SettingsScreen()),
                onOpenGallery: () => _open(const TileGalleryScreen()),
                onOpenTablePreview: () => _open(const TablePreviewScreen()),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _ModernBottomBar(
        currentIndex: _tabIndex,
        isAr: isAr,
        onTap: (index) => setState(() => _tabIndex = index),
      ),
    );
  }
}

class _ModernBottomBar extends StatelessWidget {
  const _ModernBottomBar({
    required this.currentIndex,
    required this.isAr,
    required this.onTap,
  });

  final int currentIndex;
  final bool isAr;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final items = <(IconData, IconData, String)>[
      (
        Icons.sports_esports_outlined,
        Icons.sports_esports_rounded,
        isAr ? 'الألعاب' : 'Games',
      ),
      (
        Icons.emoji_events_outlined,
        Icons.emoji_events_rounded,
        isAr ? 'التحديات' : 'Challenges',
      ),
      (Icons.home_outlined, Icons.home_rounded, isAr ? 'الرئيسية' : 'Home'),
      (
        Icons.storefront_outlined,
        Icons.storefront_rounded,
        isAr ? 'السوق' : 'Shop',
      ),
      (
        Icons.person_outline_rounded,
        Icons.person_rounded,
        isAr ? 'البروفايل' : 'Profile',
      ),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomInset),
      decoration: BoxDecoration(
        color: const Color(0xFF140B07),
        border: Border(
          top: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _NavItem(
                icon: currentIndex == i ? items[i].$2 : items[i].$1,
                label: items[i].$3,
                selected: currentIndex == i,
                isCenter: i == 2,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isCenter,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool isCenter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          vertical: isCenter ? 7 : 6,
          horizontal: 4,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: isCenter ? 0.24 : 0.16)
              : (isCenter
                    ? AppColors.gold.withValues(alpha: 0.08)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(isCenter ? 18 : 14),
          border: isCenter
              ? Border.all(
                  color: AppColors.gold.withValues(alpha: selected ? 0.8 : 0.3),
                  width: 1.2,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isCenter ? 25 : 22,
              color: selected
                  ? AppColors.gold
                  : AppColors.ivory.withValues(alpha: isCenter ? 0.85 : 0.6),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.gold
                      : AppColors.ivory.withValues(
                          alpha: isCenter ? 0.85 : 0.6,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 0: Home (Quick Play + Leaderboard)
// ---------------------------------------------------------------------------

class _HomeTab extends ConsumerWidget {
  const _HomeTab({
    required this.l10n,
    required this.isAr,
    required this.onQuickPlay,
    required this.onOpenSettings,
    required this.onViewAllGames,
  });

  final AppLocalizations l10n;
  final bool isAr;
  final VoidCallback onQuickPlay;
  final VoidCallback onOpenSettings;
  final VoidCallback onViewAllGames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = TileSkin.byId(ref.watch(settingsProvider).tileSkinId);
    final account = ref.watch(gameDataCenterProvider);

    final leaders = <({String nameAr, String nameEn, int pts, bool isMe})>[
      (
        nameAr: 'أبو علي البغدادي',
        nameEn: 'Abu Ali',
        pts: 1450,
        isMe: false,
      ),
      (
        nameAr: 'حيدر المنصور',
        nameEn: 'Haider',
        pts: 1280,
        isMe: false,
      ),
      (
        nameAr: 'كرار البصري',
        nameEn: 'Karrar',
        pts: 1120,
        isMe: false,
      ),
      (
        nameAr: account.displayName,
        nameEn: account.displayName,
        pts: account.rating,
        isMe: true,
      ),
    ]..sort((a, b) => b.pts.compareTo(a.pts));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.appTitle,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: onOpenSettings,
              tooltip: l10n.settings,
              icon: const Icon(
                Icons.settings_outlined,
                color: AppColors.ivory,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Featured quick-play card for Iraqi Domino.
        _PanelCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DominoTile(top: 3, bottom: 5, width: 32, skin: skin),
                  const SizedBox(width: 12),
                  DominoTile(top: 6, bottom: 6, width: 32, skin: skin),
                  const SizedBox(width: 12),
                  DominoTile(top: 1, bottom: 4, width: 32, skin: skin),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.appTitle,
                style: const TextStyle(
                  color: AppColors.ivory,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: GameButton(
                  label: l10n.play,
                  icon: Icons.play_arrow_rounded,
                  primary: true,
                  onPressed: onQuickPlay,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onViewAllGames,
                child: Text(
                  isAr ? 'استعراض كل الألعاب' : 'Browse all games',
                  style: const TextStyle(color: AppColors.gold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Leaderboard preview directly on Home.
        Row(
          children: [
            const Icon(
              Icons.leaderboard_rounded,
              color: AppColors.gold,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isAr ? 'الترتيب العام' : 'Leaderboard',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isAr
                  ? 'تقييمك: ${account.rating}'
                  : 'Your Rating: ${account.rating}',
              style: TextStyle(
                color: AppColors.ivory.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PanelCard(
          child: Column(
            children: [
              for (var i = 0; i < leaders.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 16,
                    color: AppColors.gold.withValues(alpha: 0.16),
                  ),
                Row(
                  children: [
                    _RankBadge(rank: i + 1),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isAr ? leaders[i].nameAr : leaders[i].nameEn,
                        style: TextStyle(
                          color: leaders[i].isMe
                              ? AppColors.gold
                              : AppColors.ivory,
                          fontSize: 14,
                          fontWeight: leaders[i].isMe
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${leaders[i].pts}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final color = switch (rank) {
      1 => AppColors.gold,
      2 => const Color(0xFFC0C7D1),
      _ => const Color(0xFFCD8B5B),
    };
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color),
      ),
      child: Text(
        '#$rank',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Games Catalog (extensible for future games)
// ---------------------------------------------------------------------------

class _GamesTab extends StatelessWidget {
  const _GamesTab({required this.isAr, required this.onOpenGame});

  final bool isAr;
  final ValueChanged<GameEntry> onOpenGame;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        Text(
          isAr ? 'الألعاب' : 'Games',
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        for (final entry in GameCatalog.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: entry.available ? () => onOpenGame(entry) : null,
              child: Opacity(
                opacity: entry.available ? 1 : 0.6,
                child: _PanelCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Icon(
                          entry.icon,
                          color: AppColors.gold,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title(isAr),
                              style: const TextStyle(
                                color: AppColors.ivory,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.subtitle(isAr),
                              style: TextStyle(
                                color: AppColors.ivory.withValues(alpha: 0.7),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        entry.available
                            ? Icons.play_circle_fill_rounded
                            : Icons.lock_outline_rounded,
                        color: entry.available
                            ? AppColors.gold
                            : AppColors.ivory.withValues(alpha: 0.5),
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Challenges & Tournaments (Phase 10 placeholder)
// ---------------------------------------------------------------------------

class _ChallengesTab extends StatelessWidget {
  const _ChallengesTab({required this.isAr});

  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final challenges = [
      (
        icon: Icons.local_fire_department_rounded,
        title: isAr ? 'التحدي اليومي' : 'Daily Challenge',
        desc: isAr
            ? 'اربح 3 جولات متتالية في الدومينو'
            : 'Win 3 consecutive rounds in Domino',
      ),
      (
        icon: Icons.emoji_events_rounded,
        title: isAr ? 'بطولة كهوة بغداد' : 'Baghdad Café Tournament',
        desc: isAr
            ? 'قريباً — بطولات أسبوعية للفرق واللاعبين'
            : 'Coming soon — weekly tournaments',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        Text(
          isAr ? 'التحديات والبطولات' : 'Challenges & Tournaments',
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        for (final item in challenges)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PanelCard(
              child: Row(
                children: [
                  Icon(item.icon, color: AppColors.gold, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: AppColors.ivory,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.desc,
                          style: TextStyle(
                            color: AppColors.ivory.withValues(alpha: 0.7),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Shop (live TileSkin picker + Phase 9 virtual-currency preview)
// ---------------------------------------------------------------------------

class _ShopTab extends ConsumerWidget {
  const _ShopTab({required this.l10n, required this.isAr});

  final AppLocalizations l10n;
  final bool isAr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        Text(
          isAr ? 'السوق' : 'Shop',
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsTileSkin,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final skin in TileSkin.all)
                    GestureDetector(
                      onTap: () => notifier.setTileSkin(skin.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: settings.tileSkinId == skin.id
                              ? AppColors.gold.withValues(alpha: 0.18)
                              : const Color(0x66000000),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: settings.tileSkinId == skin.id
                                ? AppColors.gold
                                : AppColors.gold.withValues(alpha: 0.25),
                            width: settings.tileSkinId == skin.id ? 1.8 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            DominoTile(
                              top: 6,
                              bottom: 6,
                              width: 30,
                              skin: skin,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tileSkinName(l10n, skin),
                              style: const TextStyle(
                                color: AppColors.ivory,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          child: Row(
            children: [
              const Icon(
                Icons.table_restaurant_rounded,
                color: AppColors.gold,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isAr
                      ? 'ثيمات الطاولات والأفاتارات قادمة في التحديثات القادمة (بعملة افتراضية فقط).'
                      : 'Table themes & avatars coming in a future update (virtual currency only).',
                  style: TextStyle(
                    color: AppColors.ivory.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 4: Profile & Settings
// ---------------------------------------------------------------------------

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({
    required this.l10n,
    required this.isAr,
    required this.onOpenSettings,
    required this.onOpenGallery,
    required this.onOpenTablePreview,
  });

  final AppLocalizations l10n;
  final bool isAr;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenGallery;
  final VoidCallback onOpenTablePreview;

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final ctrl = TextEditingController(text: currentName);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF23140C),
        title: Text(
          isAr ? 'تعديل اسم اللاعب' : 'Edit Player Name',
          style: const TextStyle(color: AppColors.gold, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 24,
          style: const TextStyle(color: AppColors.ivory),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: Text(
              isAr ? 'حفظ' : 'Save',
              style: const TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (updated != null && updated.trim().isNotEmpty) {
      ref.read(gameDataCenterProvider.notifier).updateDisplayName(updated);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(gameDataCenterProvider);
    final stats = account.stats;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        Text(
          isAr ? 'البروفايل' : 'Profile',
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        _PanelCard(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4A3020),
                      border: Border.all(color: AppColors.gold, width: 2),
                    ),
                    child: Icon(
                      account.isGuest
                          ? Icons.person_rounded
                          : Icons.verified_user_rounded,
                      color: AppColors.ivory,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.displayName,
                          style: const TextStyle(
                            color: AppColors.ivory,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          account.isGuest
                              ? (isAr
                                    ? 'وضع الضيف نشط — التقييم: ${account.rating}'
                                    : 'Guest Mode Active — Rating: ${account.rating}')
                              : (isAr
                                    ? 'حساب مسجل — التقييم: ${account.rating}'
                                    : 'Signed-In — Rating: ${account.rating}'),
                          style: TextStyle(
                            color: AppColors.ivory.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _editName(
                      context,
                      ref,
                      account.displayName,
                    ),
                    icon: const Icon(Icons.edit_outlined, color: AppColors.gold),
                    tooltip: isAr ? 'تعديل الاسم' : 'Edit name',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatMiniItem(
                    label: isAr ? 'مباريات' : 'Matches',
                    value: '${stats.matchesPlayed}',
                  ),
                  _StatMiniItem(
                    label: isAr ? 'انتصارات' : 'Wins',
                    value: '${stats.matchesWon}',
                  ),
                  _StatMiniItem(
                    label: isAr ? 'أفضل سلسلة' : 'Best Streak',
                    value: '${stats.bestWinStreak}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    account.isGuest
                        ? Icons.cloud_upload_outlined
                        : Icons.verified_user_rounded,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      account.isGuest
                          ? (isAr
                                ? 'أنت تلعب حالياً كضيف. يمكنك ربط حسابك لحفظ نقاطك وانتصاراتك.'
                                : 'Playing as Guest. Link an account to save your progress.')
                          : (isAr
                                ? 'الحساب مربوط (${account.email ?? account.playerId})'
                                : 'Linked Account (${account.email ?? account.playerId})'),
                      style: TextStyle(
                        color: AppColors.ivory.withValues(alpha: 0.78),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (account.isGuest)
                GameButton(
                  label: isAr
                      ? 'تسجيل الدخول / ربط الحساب'
                      : 'Sign In / Link Account',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AuthScreen(popOnComplete: true),
                      ),
                    );
                  },
                )
              else
                GameButton(
                  label: isAr
                      ? 'تسجيل الخروج (المتابعة كضيف)'
                      : 'Sign Out (Continue as Guest)',
                  icon: Icons.logout_rounded,
                  onPressed: () => ref
                      .read(gameDataCenterProvider.notifier)
                      .continueAsGuest(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: GameButton(
            label: l10n.settings,
            icon: Icons.settings_outlined,
            primary: true,
            onPressed: onOpenSettings,
          ),
        ),
        if (!kReleaseMode) ...[
          const SizedBox(height: 22),
          TextButton(onPressed: onOpenGallery, child: Text(l10n.tileGallery)),
          TextButton(
            onPressed: onOpenTablePreview,
            child: Text(l10n.tablePreview),
          ),
        ],
      ],
    );
  }
}

class _StatMiniItem extends StatelessWidget {
  const _StatMiniItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppColors.ivory.withValues(alpha: 0.65),
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xCC1D110A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
