import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_persona.dart';
import '../../core/constants/app_colors.dart';
import '../../core/games/game_catalog.dart';
import '../../core/network/connectivity_provider.dart';
import '../../core/theme/maqha_design_system.dart';
import '../../data/cafe_progression.dart';
import '../../data/game_data_center.dart';
import '../../data/player_account.dart';
import '../../engine/game_rules_config.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/tile_skin.dart';
import '../../state/settings_provider.dart';
import '../widgets/ai_persona_avatar.dart';
import '../widgets/cafe_avatar_frame.dart';
import '../widgets/cafe_prop_widget.dart';
import '../widgets/game_button.dart';
import '../widgets/maqha_leaderboard_sheet.dart';
import 'auth_screen.dart';
import 'cafe_shop_view.dart';
import 'cafe_tournaments_view.dart';
import 'game_screen.dart';
import 'local_multiplayer_screen.dart';
import 'mode_hub_screen.dart';
import 'settings_screen.dart';
import 'table_preview_screen.dart';
import 'tile_gallery_screen.dart';

/// Portrait **المقهى** shell styled 1:1 after the Emerald-Teal, Matte Charcoal,
/// and Warm Amber-Gold reference design with a floating glass capsule dock.
///
/// Physical left-to-right dock order:
/// 0 = Profile (`ملفي`), 1 = Games (`الألعاب`), 2 = Home (`الرئيسية`),
/// 3 = Tasks (`المهام`), 4 = Shop (`السوق`).
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

  void _showSoonMessage(bool isAr, String gameTitle) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: MaqhaColors.cardCharcoalElevated,
          behavior: SnackBarBehavior.floating,
          content: Text(
            isAr
                ? '$gameTitle ستُفتح قريباً في المقهى'
                : '$gameTitle opens soon in Al-Maqha',
            style: const TextStyle(
              color: MaqhaColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final conn = ref.watch(connectivityProvider);
    final settings = ref.watch(settingsProvider);
    final selectedGame = GameCatalog.byId(settings.selectedGameId);

    if (!conn.isOnline) {
      return _OfflineOnlyCafeScreen(
        l10n: l10n,
        isAr: isAr,
        checking: conn.checking,
        onRetryInternet: () =>
            ref.read(connectivityProvider.notifier).refreshConnectivity(),
        onOpenSettings: () => _open(const SettingsScreen()),
        onOpenModeHub: (playerCount) =>
            _open(ModeHubScreen(playerCount: playerCount)),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: MaqhaColors.bgDeepTeal,
      body: MaqhaEmeraldBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tabIndex,
            children: [
              // 0 (Leftmost): Profile ("ملفي")
              _ProfileTab(
                l10n: l10n,
                isAr: isAr,
                onOpenSettings: () => _open(const SettingsScreen()),
                onOpenGallery: () => _open(const TileGalleryScreen()),
                onOpenTablePreview: () => _open(const TablePreviewScreen()),
              ),
              // 1 (2nd from left): Games ("الألعاب")
              _GamesTab(
                isAr: isAr,
                selectedGameId: selectedGame.id,
                tileSkinId: settings.tileSkinId,
                onSelectAndOpenHome: (entry) {
                  ref.read(settingsProvider.notifier).setSelectedGame(entry.id);
                  setState(() => _tabIndex = 2);
                },
              ),
              // 2 (Center): Home ("الرئيسية")
              _HomeHallTab(
                l10n: l10n,
                isAr: isAr,
                selectedGame: selectedGame,
                tileSkinId: settings.tileSkinId,
                onPlaySelectedGame: () {
                  final builder = selectedGame.builder;
                  if (selectedGame.available && builder != null) {
                    _open(builder(context));
                  } else {
                    _showSoonMessage(isAr, selectedGame.title(isAr));
                  }
                },
                onOpenLocalPlay: () {
                  if (selectedGame.available) {
                    _open(const LocalMultiplayerScreen(playerCount: 4));
                  } else {
                    _showSoonMessage(isAr, selectedGame.title(isAr));
                  }
                },
                onOpenTraining: () {
                  if (selectedGame.available) {
                    _open(
                      GameScreen(
                        playerCount: 2,
                        rules: GameRulesConfig(
                          targetScore: settings.targetScore,
                          aiDifficulty: settings.aiDifficulty,
                        ),
                      ),
                    );
                  } else {
                    _showSoonMessage(isAr, selectedGame.title(isAr));
                  }
                },
                onOpenSettings: () => _open(const SettingsScreen()),
                onSelectTab: (idx) => setState(() => _tabIndex = idx),
              ),
              // 3 (4th from left): Tasks ("المهام")
              CafeTournamentsView(isAr: isAr),
              // 4 (Rightmost): Shop ("السوق")
              CafeShopView(isAr: isAr),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _FloatingCapsuleDock(
        currentIndex: _tabIndex,
        isAr: isAr,
        onTap: (index) => setState(() => _tabIndex = index),
      ),
    );
  }
}

class _FloatingCapsuleDock extends StatelessWidget {
  const _FloatingCapsuleDock({
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
    // Physically ordered from LEFT (0) to RIGHT (4):
    // ملفي -> الألعاب -> الرئيسية -> المهام -> السوق
    final items = <(IconData, IconData, String)>[
      (
        Icons.person_outline_rounded,
        Icons.person_rounded,
        isAr ? 'ملفي' : 'Profile',
      ),
      (
        Icons.grid_view_outlined,
        Icons.grid_view_rounded,
        isAr ? 'الألعاب' : 'Games',
      ),
      (
        Icons.home_outlined,
        Icons.home_rounded,
        isAr ? 'الرئيسية' : 'Home',
      ),
      (
        Icons.adjust_rounded,
        Icons.adjust_rounded,
        isAr ? 'المهام' : 'Tasks',
      ),
      (
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded,
        isAr ? 'السوق' : 'Shop',
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, 10 + bottomInset),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: MaqhaColors.dockGlass,
          borderRadius: MaqhaRadii.floatingDock,
          border: Border.all(color: MaqhaColors.borderSubtle),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _DockNavItem(
                    icon: currentIndex == i ? items[i].$2 : items[i].$1,
                    label: items[i].$3,
                    selected: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockNavItem extends StatelessWidget {
  const _DockNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MaqhaColors.goldBright : MaqhaColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? MaqhaColors.goldPrimary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
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
// Center Tab: Home ("الرئيسية") — Selected Game Showcase, Play CTA, 2 Offline
// Modes (Local & Practice, 0 XP), and Per-Game Leaderboard
// ---------------------------------------------------------------------------

class _HomeHallTab extends ConsumerWidget {
  const _HomeHallTab({
    required this.l10n,
    required this.isAr,
    required this.selectedGame,
    required this.tileSkinId,
    required this.onPlaySelectedGame,
    required this.onOpenLocalPlay,
    required this.onOpenTraining,
    required this.onOpenSettings,
    required this.onSelectTab,
  });

  final AppLocalizations l10n;
  final bool isAr;
  final GameEntry selectedGame;
  final String tileSkinId;
  final VoidCallback onPlaySelectedGame;
  final VoidCallback onOpenLocalPlay;
  final VoidCallback onOpenTraining;
  final VoidCallback onOpenSettings;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(gameDataCenterProvider);
    final persona = AiPersona.all[account.avatarIndex % AiPersona.all.length];
    final skin = TileSkin.byId(tileSkinId);
    final parentDir = Directionality.of(context);

    final leaders = buildLeaderboardEntries(
      account: account,
      gameId: selectedGame.id,
      scope: LeaderboardScope.rating,
    );
    final myIndex = leaders.indexWhere((e) => e.isMe);
    final myRank = myIndex >= 0 ? myIndex + 1 : 1;
    final myPts = myIndex >= 0 ? leaders[myIndex].points : account.rating;
    final rankTitle = CafeProgression.cafeTitleForRank(
      leaderboardRank: myRank,
      rating: myPts,
      isAr: isAr,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 108),
      children: [
        // 1. Top Utility Row (Physically Left -> Right):
        //    Far Left = Settings, Next = Currency, Far Right = Compact Player Pill
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              Directionality(
                textDirection: parentDir,
                child: MaqhaTopIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: l10n.settings,
                  onTap: onOpenSettings,
                ),
              ),
              const SizedBox(width: 6),
              Directionality(
                textDirection: parentDir,
                child: CafeDinarPill(
                  amount: account.cafeDinars,
                  isAr: isAr,
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Directionality(
                    textDirection: parentDir,
                    child: MaqhaPlayerIdentityPill(
                      displayName: account.displayName,
                      rankTitle: rankTitle,
                      avatarChild: AiPersonaAvatar(persona: persona, size: 24),
                      onTap: () => onSelectTab(0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Subtle Al-Maqha platform tag
        Center(
          child: Text(
            l10n.appTitle,
            style: const TextStyle(
              color: MaqhaColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 2. Selected Game Illustration / Symbol + Game Title
        Center(
          child: GestureDetector(
            onTap: () => onSelectTab(1),
            child: _GameHeroEmblem(
              gameId: selectedGame.id,
              skin: skin,
              size: 104,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            selectedGame.title(isAr),
            textAlign: TextAlign.center,
            style: MaqhaTextStyles.displayGoldTitle,
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            width: 54,
            height: 4,
            decoration: BoxDecoration(
              color: MaqhaColors.goldPrimary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 3. Main Gold Pill CTA Button ("العب")
        SizedBox(
          width: double.infinity,
          child: MaqhaGoldPillButton(
            label: selectedGame.available
                ? l10n.play
                : (isAr ? 'قريباً' : 'Coming Soon'),
            showPlayArrow: selectedGame.available,
            height: 56,
            onPressed: onPlaySelectedGame,
          ),
        ),

        const SizedBox(height: 14),

        // 4. ONLY Local Play & Practice with Bots (0 XP) directly below Play
        Row(
          children: [
            Expanded(
              child: MaqhaModeCard(
                icon: Icons.wifi_tethering_rounded,
                title: isAr ? 'لعب محلي' : 'Local Play',
                subtitle: isAr ? 'داخلي • بدون خبرة' : 'Local • 0 XP',
                onTap: onOpenLocalPlay,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MaqhaModeCard(
                icon: Icons.smart_toy_outlined,
                title: isAr ? 'تدريب' : 'Practice',
                subtitle: isAr ? 'مع البوتات • بدون خبرة' : 'Bots • 0 XP',
                onTap: onOpenTraining,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // 5. Shaded/Subtle Leaderboard Button -> Opens Podium Leaderboard Popup
        MaqhaLeaderboardShadedButton(
          gameTitle: selectedGame.title(isAr),
          myRank: myRank,
          myPoints: myPts,
          isAr: isAr,
          onTap: () => MaqhaLeaderboardSheet.show(
            context,
            account: account,
            selectedGame: selectedGame,
            isAr: isAr,
          ),
        ),
      ],
    );
  }
}

/// High-precision custom-painted emblem & illustration for the selected game.
class _GameHeroEmblem extends StatelessWidget {
  const _GameHeroEmblem({
    required this.gameId,
    required this.skin,
    this.size = 104,
  });

  final String gameId;
  final TileSkin skin;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MaqhaColors.cardCharcoal,
        border: Border.all(
          color: MaqhaColors.goldPrimary.withValues(alpha: 0.75),
          width: 1.6,
        ),
        boxShadow: MaqhaShadows.goldCtaGlow,
      ),
      child: Center(child: _buildInnerArtwork()),
    );
  }

  Widget _buildInnerArtwork() {
    switch (gameId) {
      case 'backgammon':
        return CustomPaint(
          size: Size(size * 0.58, size * 0.58),
          painter: const _BackgammonEmblemPainter(),
        );
      case 'cards':
        return CustomPaint(
          size: Size(size * 0.58, size * 0.58),
          painter: const _PlayingCardsEmblemPainter(),
        );
      default:
        final tileW = (size * 0.25).clamp(14.0, 30.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(-tileW * 0.58, tileW * 0.14),
              child: Transform.rotate(
                angle: -0.22,
                child: DominoTile(
                  top: 6,
                  bottom: 5,
                  width: tileW * 0.86,
                  skin: skin,
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(tileW * 0.42, -tileW * 0.06),
              child: Transform.rotate(
                angle: 0.14,
                child: DominoTile(top: 6, bottom: 6, width: tileW, skin: skin),
              ),
            ),
          ],
        );
    }
  }
}

class _BackgammonEmblemPainter extends CustomPainter {
  const _BackgammonEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.08, w, h * 0.84),
      Radius.circular(w * 0.14),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xFF143A38),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = MaqhaColors.goldPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // 4 triangular points along top & bottom
    final goldSpike = Paint()..color = MaqhaColors.goldPrimary.withValues(alpha: 0.85);
    final mutedSpike = Paint()..color = MaqhaColors.textPrimary.withValues(alpha: 0.35);
    final step = (w * 0.8) / 4;
    for (var i = 0; i < 4; i++) {
      final x0 = w * 0.1 + i * step;
      final topTri = Path()
        ..moveTo(x0, h * 0.10)
        ..lineTo(x0 + step * 0.85, h * 0.10)
        ..lineTo(x0 + step * 0.425, h * 0.44)
        ..close();
      canvas.drawPath(topTri, i.isEven ? goldSpike : mutedSpike);

      final botTri = Path()
        ..moveTo(x0, h * 0.90)
        ..lineTo(x0 + step * 0.85, h * 0.90)
        ..lineTo(x0 + step * 0.425, h * 0.56)
        ..close();
      canvas.drawPath(botTri, i.isOdd ? goldSpike : mutedSpike);
    }

    // Checkers + die
    canvas.drawCircle(
      Offset(w * 0.28, h * 0.76),
      w * 0.09,
      Paint()..color = MaqhaColors.goldBright,
    );
    canvas.drawCircle(
      Offset(w * 0.72, h * 0.24),
      w * 0.09,
      Paint()..color = MaqhaColors.textPrimary,
    );
  }

  @override
  bool shouldRepaint(covariant _BackgammonEmblemPainter oldDelegate) => false;
}

class _PlayingCardsEmblemPainter extends CustomPainter {
  const _PlayingCardsEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void drawCard(double angle, Offset shift, Color fill, Color diamondColor) {
      canvas.save();
      canvas.translate(w / 2 + shift.dx, h / 2 + shift.dy);
      canvas.rotate(angle);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.52, height: h * 0.74),
        Radius.circular(w * 0.09),
      );
      canvas.drawRRect(rect, Paint()..color = fill);
      canvas.drawRRect(
        rect,
        Paint()
          ..color = MaqhaColors.goldPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      final d = w * 0.12;
      final diamond = Path()
        ..moveTo(0, -d)
        ..lineTo(d * 0.8, 0)
        ..lineTo(0, d)
        ..lineTo(-d * 0.8, 0)
        ..close();
      canvas.drawPath(diamond, Paint()..color = diamondColor);
      canvas.restore();
    }

    drawCard(
      -0.24,
      Offset(-w * 0.10, h * 0.02),
      const Color(0xFF1F2B2E),
      MaqhaColors.textSecondary,
    );
    drawCard(
      0.16,
      Offset(w * 0.10, -h * 0.01),
      const Color(0xFF143A38),
      MaqhaColors.goldBright,
    );
  }

  @override
  bool shouldRepaint(covariant _PlayingCardsEmblemPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Tab 1: Games Catalog ("الألعاب") — Select & Switch Active Game on Home
// ---------------------------------------------------------------------------

class _GamesTab extends StatelessWidget {
  const _GamesTab({
    required this.isAr,
    required this.selectedGameId,
    required this.tileSkinId,
    required this.onSelectAndOpenHome,
  });

  final bool isAr;
  final String selectedGameId;
  final String tileSkinId;
  final ValueChanged<GameEntry> onSelectAndOpenHome;

  @override
  Widget build(BuildContext context) {
    final skin = TileSkin.byId(tileSkinId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
      children: [
        Text(
          isAr ? 'الألعاب' : 'Games',
          style: const TextStyle(
            color: MaqhaColors.goldBright,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        for (final entry in GameCatalog.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GameCatalogCard(
              entry: entry,
              isAr: isAr,
              isSelected: entry.id == selectedGameId,
              skin: skin,
              onActivate: () => onSelectAndOpenHome(entry),
            ),
          ),
      ],
    );
  }
}

class _GameCatalogCard extends StatelessWidget {
  const _GameCatalogCard({
    required this.entry,
    required this.isAr,
    required this.isSelected,
    required this.skin,
    required this.onActivate,
  });

  final GameEntry entry;
  final bool isAr;
  final bool isSelected;
  final TileSkin skin;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onActivate,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? MaqhaColors.cardCharcoalElevated
              : MaqhaColors.cardCharcoal,
          borderRadius: MaqhaRadii.panelCard,
          border: Border.all(
            color: isSelected
                ? MaqhaColors.goldPrimary
                : MaqhaColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: MaqhaShadows.softCard,
        ),
        child: Row(
          children: [
            _GameHeroEmblem(gameId: entry.id, skin: skin, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title(isAr),
                    style: const TextStyle(
                      color: MaqhaColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.subtitle(isAr),
                    style: const TextStyle(
                      color: MaqhaColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: MaqhaGradients.primaryGoldCta,
                borderRadius: MaqhaRadii.pill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAr ? 'تشغيل' : 'Open',
                    style: const TextStyle(
                      color: MaqhaColors.textOnGold,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: MaqhaColors.textOnGold,
                    size: 17,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 4: Profile ("ملفي")
// ---------------------------------------------------------------------------

class _ProfileTab extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  String _selectedStatsScope = 'iraqi_domino';
  final String _selectedBadgesGameId = 'iraqi_domino';

  AppLocalizations get l10n => widget.l10n;
  bool get isAr => widget.isAr;

  int _computeMyLeaderboardRank(int myRating) {
    const rivalRatings = [1450, 1280, 1120];
    var rank = 1;
    for (final r in rivalRatings) {
      if (r > myRating) rank++;
    }
    return rank;
  }

  Future<void> _editName(BuildContext context, String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isAr ? 'تعديل الاسم' : 'Edit Name',
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

  Future<void> _pickAvatar(BuildContext context, int currentIndex) async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isAr ? 'اختر صورتك الرمزية' : 'Choose Avatar',
          style: const TextStyle(color: AppColors.gold, fontSize: 15.5),
        ),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < AiPersona.all.length; i++)
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(i),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: currentIndex == i
                          ? AppColors.gold.withValues(alpha: 0.18)
                          : MaqhaColors.cardCharcoal,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentIndex == i
                            ? AppColors.gold
                            : MaqhaColors.borderSubtle,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AiPersonaAvatar(persona: AiPersona.all[i], size: 42),
                        const SizedBox(height: 4),
                        Text(
                          isAr
                              ? AiPersona.all[i].nameAr
                              : AiPersona.all[i].nameEn,
                          style: const TextStyle(
                            color: AppColors.ivory,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      ref.read(gameDataCenterProvider.notifier).updateAvatarIndex(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(gameDataCenterProvider);
    final avatarPersona =
        AiPersona.all[account.avatarIndex % AiPersona.all.length];
    final levelInfo = account.levelInfo;
    final myRank = _computeMyLeaderboardRank(account.rating);
    final cafeTitle = CafeProgression.cafeTitleForRank(
      leaderboardRank: myRank,
      rating: account.rating,
      isAr: isAr,
    );
    final dailyEarned = account.effectiveDailyMatchXp();
    final dailyCap = account.dailyMatchXpCap;

    final activeStats = _selectedStatsScope == 'all'
        ? account.stats
        : account.statsForGame(_selectedStatsScope);
    final winPct = (activeStats.winRate * 100).round();
    final badges = CafeProgression.badgesForGame(_selectedBadgesGameId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isAr ? 'ملفي' : 'Profile',
                style: const TextStyle(
                  color: MaqhaColors.goldBright,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            CafeDinarPill(amount: account.cafeDinars, isAr: isAr, compact: true),
          ],
        ),
        const SizedBox(height: 14),

        // 1. Identity & Level Card
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _pickAvatar(context, account.avatarIndex),
                    child: CafeAvatarFrame(
                      frameId: account.effectiveFrameId(),
                      size: 54,
                      child: AiPersonaAvatar(persona: avatarPersona, size: 54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                account.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: MaqhaColors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (account.isVipActive()) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: MaqhaColors.goldPrimary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'VIP',
                                  style: TextStyle(
                                    color: MaqhaColors.textOnGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$cafeTitle  •  #$myRank',
                          style: const TextStyle(
                            color: MaqhaColors.goldPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CafePropWidget(
                    propId: account.effectiveCafePropId(),
                    size: 32,
                  ),
                  IconButton(
                    onPressed: () => _editName(context, account.displayName),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: MaqhaColors.iconSand,
                      size: 19,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isAr
                        ? 'المستوى ${levelInfo.level} / ${CafeProgression.maxLevel}'
                        : 'Lv ${levelInfo.level} / ${CafeProgression.maxLevel}',
                    style: const TextStyle(
                      color: MaqhaColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    levelInfo.level >= CafeProgression.maxLevel
                        ? '${account.totalXp} XP'
                        : '${levelInfo.currentLevelXp} / ${levelInfo.nextLevelXp} XP',
                    style: const TextStyle(
                      color: MaqhaColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: levelInfo.progress.clamp(0.0, 1.0),
                  backgroundColor: const Color(0x44000000),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    MaqhaColors.goldPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isAr ? 'خبرة اليوم' : 'Daily XP',
                    style: const TextStyle(
                      color: MaqhaColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '$dailyEarned / $dailyCap XP',
                    style: const TextStyle(
                      color: MaqhaColors.goldPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Account Link Action
        if (account.isGuest)
          GameButton(
            label: isAr ? 'تسجيل الدخول أو ربط الحساب' : 'Sign In / Link Account',
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
            label: isAr ? 'تسجيل الخروج' : 'Sign Out',
            icon: Icons.logout_rounded,
            onPressed: () =>
                ref.read(gameDataCenterProvider.notifier).continueAsGuest(),
          ),

        const SizedBox(height: 18),

        // 3. Statistics
        Row(
          children: [
            Expanded(
              child: Text(
                isAr ? 'الإحصائيات' : 'Statistics',
                style: const TextStyle(
                  color: MaqhaColors.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              label: Text(isAr ? 'الدومينو' : 'Domino'),
              selected: _selectedStatsScope == 'iraqi_domino',
              onSelected: (_) =>
                  setState(() => _selectedStatsScope = 'iraqi_domino'),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              label: Text(isAr ? 'الكل' : 'All'),
              selected: _selectedStatsScope == 'all',
              onSelected: (_) => setState(() => _selectedStatsScope = 'all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PanelCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatMiniItem(
                    label: isAr ? 'مباريات' : 'Matches',
                    value: '${activeStats.matchesPlayed}',
                  ),
                  _StatMiniItem(
                    label: isAr ? 'فوز' : 'Wins',
                    value: '${activeStats.matchesWon}',
                  ),
                  _StatMiniItem(
                    label: isAr ? 'خسارة' : 'Losses',
                    value: '${activeStats.matchesLost}',
                  ),
                  _StatMiniItem(
                    label: isAr ? 'النسبة' : 'Rate',
                    value: '$winPct%',
                  ),
                ],
              ),
              const Divider(height: 20, color: MaqhaColors.borderSubtle),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatMiniItem(
                    label: isAr ? 'دومينو' : 'Domino',
                    value: '${activeStats.dominoRoundWins}',
                  ),
                  _StatMiniItem(
                    label: isAr ? 'قفلة' : 'Blocks',
                    value: '${activeStats.blockedRoundWins}',
                  ),
                  _StatMiniItem(
                    label: isAr ? 'أعلى جولة' : 'Best',
                    value: '${activeStats.highestSingleRoundScore}',
                  ),
                  _StatMiniItem(
                    label: isAr ? 'سلسلة' : 'Streak',
                    value: '${activeStats.bestWinStreak}',
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 4. Badges
        Text(
          isAr ? 'الأوسمة' : 'Badges',
          style: const TextStyle(
            color: MaqhaColors.textPrimary,
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        for (final badge in badges)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BadgeProgressCard(
              badge: badge,
              stats: account.statsForGame(badge.gameId),
              unlocked: account.unlockedBadgeIds.contains(badge.id),
              isAr: isAr,
            ),
          ),

        const SizedBox(height: 10),
        GameButton(
          label: l10n.settings,
          icon: Icons.settings_outlined,
          onPressed: widget.onOpenSettings,
        ),
        if (!kReleaseMode) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.onOpenGallery,
            child: Text(l10n.tileGallery),
          ),
          TextButton(
            onPressed: widget.onOpenTablePreview,
            child: Text(l10n.tablePreview),
          ),
        ],
      ],
    );
  }
}

class _BadgeProgressCard extends StatelessWidget {
  const _BadgeProgressCard({
    required this.badge,
    required this.stats,
    required this.unlocked,
    required this.isAr,
  });

  final GameBadgeDefinition badge;
  final PlayerStats stats;
  final bool unlocked;
  final bool isAr;

  Color _tierColor(BadgeDifficulty d) => switch (d) {
    BadgeDifficulty.easy => const Color(0xFFCD8B5B),
    BadgeDifficulty.medium => const Color(0xFFC0C7D1),
    BadgeDifficulty.hard => MaqhaColors.goldPrimary,
    BadgeDifficulty.legendary => const Color(0xFFE5534B),
  };

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(badge.difficulty);
    final current = badge.progressValue(stats);
    final target = badge.targetValue;
    final ratio = target == 0 ? 1.0 : (current / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MaqhaColors.cardCharcoal,
        borderRadius: MaqhaRadii.modeCard,
        border: Border.all(
          color: unlocked ? tierColor.withValues(alpha: 0.75) : MaqhaColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tierColor.withValues(alpha: 0.14),
            ),
            child: Icon(
              unlocked
                  ? Icons.workspace_premium_rounded
                  : Icons.military_tech_outlined,
              color: tierColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        badge.title(isAr),
                        style: const TextStyle(
                          color: MaqhaColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '+${badge.difficulty.xpReward} XP',
                      style: TextStyle(
                        color: tierColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  badge.description(isAr),
                  style: const TextStyle(
                    color: MaqhaColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: unlocked ? 1.0 : ratio,
                          backgroundColor: const Color(0x44000000),
                          valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$current/$target',
                      style: TextStyle(
                        color: unlocked
                            ? MaqhaColors.statusSuccess
                            : MaqhaColors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
            color: MaqhaColors.goldBright,
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: MaqhaColors.textSecondary,
            fontSize: 11,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: MaqhaGradients.charcoalCard,
        borderRadius: MaqhaRadii.modeCard,
        border: Border.all(color: MaqhaColors.borderSubtle),
        boxShadow: MaqhaShadows.softCard,
      ),
      child: child,
    );
  }
}

/// Clean Offline-Only screen shown when internet is unavailable.
class _OfflineOnlyCafeScreen extends ConsumerWidget {
  const _OfflineOnlyCafeScreen({
    required this.l10n,
    required this.isAr,
    required this.checking,
    required this.onRetryInternet,
    required this.onOpenSettings,
    required this.onOpenModeHub,
  });

  final AppLocalizations l10n;
  final bool isAr;
  final bool checking;
  final VoidCallback onRetryInternet;
  final VoidCallback onOpenSettings;
  final ValueChanged<int> onOpenModeHub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: MaqhaColors.bgDeepTeal,
      body: MaqhaEmeraldBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.appTitle,
                      style: MaqhaTextStyles.displayGoldTitle,
                    ),
                  ),
                  MaqhaTopIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: l10n.settings,
                    onTap: onOpenSettings,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _PanelCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: MaqhaColors.goldPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? 'وضع بدون إنترنت' : 'Offline Mode',
                            style: const TextStyle(
                              color: MaqhaColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            isAr
                                ? 'متاح اللعب ضد الكمبيوتر واللعب المحلي'
                                : 'Play vs AI and Local Play available',
                            style: const TextStyle(
                              color: MaqhaColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: MaqhaModeCard(
                      icon: Icons.person_outline_rounded,
                      title: l10n.modeTwoPlayers,
                      subtitle: isAr ? 'بدون إنترنت' : 'Offline',
                      onTap: () => onOpenModeHub(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MaqhaModeCard(
                      icon: Icons.groups_rounded,
                      title: l10n.modeFourPlayers,
                      subtitle: isAr ? 'بدون إنترنت' : 'Offline',
                      onTap: () => onOpenModeHub(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              MaqhaGoldPillButton(
                label: checking
                    ? (isAr ? 'جارٍ الفحص...' : 'Checking...')
                    : (isAr ? 'إعادة الاتصال' : 'Reconnect'),
                showPlayArrow: false,
                leadingIcon: Icons.refresh_rounded,
                onPressed: checking ? null : onRetryInternet,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
