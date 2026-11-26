import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/audio/sound_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/connectivity_provider.dart';
import '../../core/theme/maqha_design_system.dart';
import '../../data/game_data_center.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/tile_skin.dart';
import '../../state/settings_provider.dart';
import 'app_shell_screen.dart';
import 'auth_screen.dart';

/// Animated Emerald-Teal & Gold startup Splash Screen for **المقهى**.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 1400),
    this.nextScreen,
  });

  final Duration duration;
  final Widget? nextScreen;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _emblemScale;
  late final Animation<double> _emblemOpacity;
  bool _bootDone = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _emblemScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _emblemOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _tryProceed();
      }
    });

    _controller.forward();
    _runBootInitialization();
  }

  Future<void> _runBootInitialization() async {
    try {
      await Future.wait([
        ref.read(connectivityProvider.notifier).refreshConnectivity(),
        ref.read(gameDataCenterProvider.notifier).verifyBootSession(),
        ref.read(soundServiceProvider).warmUp(),
      ]);
    } catch (_) {}
    _bootDone = true;
    if (_controller.isCompleted) {
      _tryProceed();
    }
  }

  void _tryProceed() {
    if (_navigated || !_bootDone || !mounted) return;
    _navigated = true;
    final isOnline = ref.read(connectivityProvider).isOnline;
    final hasEnteredBefore = ref
        .read(gameDataCenterProvider.notifier)
        .hasCompletedInitialEntry;
    final destination =
        widget.nextScreen ??
        ((!isOnline || hasEnteredBefore)
            ? const AppShellScreen()
            : const AuthScreen());
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => destination,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  String _stageText(bool isAr, double progress) {
    if (progress < 0.40) {
      return isAr
          ? 'جارٍ تجهيز الطاولة والأحجار...'
          : 'Preparing table & tiles...';
    }
    if (progress < 0.78) {
      return isAr
          ? 'جارٍ التحقق من الحساب ومركز البيانات...'
          : 'Verifying account & data hub...';
    }
    return isAr ? 'أهلاً بك في المقهى...' : 'Entering Al-Maqha...';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final skin = TileSkin.byId(ref.watch(settingsProvider).tileSkinId);

    return Scaffold(
      backgroundColor: MaqhaColors.bgDeepTeal,
      body: MaqhaEmeraldBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = _controller.value;
                final percent = (progress * 100).round();

                return Column(
                  children: [
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: _emblemOpacity,
                      child: ScaleTransition(
                        scale: _emblemScale,
                        child: _DominoCrestMedallion(skin: skin),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FadeTransition(
                      opacity: _emblemOpacity,
                      child: Text(
                        l10n.appTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: MaqhaColors.goldBright,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FadeTransition(
                      opacity: _emblemOpacity,
                      child: Container(
                        width: 54,
                        height: 4,
                        decoration: BoxDecoration(
                          color: MaqhaColors.goldPrimary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _emblemOpacity,
                      child: Text(
                        isAr
                            ? 'أصالة المقهى البغدادي'
                            : 'Authentic Heritage Lounge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: MaqhaColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  _stageText(isAr, progress),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: MaqhaColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$percent%',
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: MaqhaColors.cardCharcoal,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: MaqhaColors.borderSubtle),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: FractionallySizedBox(
                                  widthFactor: progress.clamp(0.04, 1.0),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: MaqhaGradients.primaryGoldCta,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DominoCrestMedallion extends StatelessWidget {
  const _DominoCrestMedallion({required this.skin});

  final TileSkin skin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 142,
      height: 142,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MaqhaColors.cardCharcoal,
        border: Border.all(color: MaqhaColors.goldPrimary, width: 1.8),
        boxShadow: MaqhaShadows.goldCtaGlow,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(-25, 6),
            child: Transform.rotate(
              angle: -0.24,
              child: DominoTile(top: 5, bottom: 4, width: 30, skin: skin),
            ),
          ),
          Transform.translate(
            offset: const Offset(25, 6),
            child: Transform.rotate(
              angle: 0.24,
              child: DominoTile(top: 6, bottom: 5, width: 30, skin: skin),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -4),
            child: DominoTile(top: 6, bottom: 6, width: 36, skin: skin),
          ),
        ],
      ),
    );
  }
}
