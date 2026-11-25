import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/audio/sound_service.dart';
import '../../core/constants/app_colors.dart';
import '../../data/game_data_center.dart';
import '../../l10n/app_localizations.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/tile_skin.dart';
import '../../state/settings_provider.dart';
import 'app_shell_screen.dart';
import 'auth_screen.dart';

/// Animated Iraqi heritage startup Splash Screen (`#140B07` walnut-dark theme).
///
/// Runs a bounded startup animation while performing real boot initialization:
/// 1. Loads saved settings & active [TileSkin].
/// 2. Initializes & verifies [GameDataCenter] player session (Guest / Signed-In).
/// 3. Pre-warms [SoundService] audio asset lookup cache.
/// 4. Smoothly fades into [AppShellScreen] (or `AuthScreen` in Step 7.2).
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
    _emblemScale = Tween<double>(begin: 0.86, end: 1.0).animate(
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
    final hasEnteredBefore = ref
        .read(gameDataCenterProvider.notifier)
        .hasCompletedInitialEntry;
    final destination =
        widget.nextScreen ??
        (hasEnteredBefore ? const AppShellScreen() : const AuthScreen());
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
    return isAr ? 'أهلاً بك في المقهى العراقي...' : 'Entering Iraqi Café...';
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
      backgroundColor: const Color(0xFF140B07),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Radial walnut background + cached Baghdadi star ornament
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.15),
                radius: 1.05,
                colors: [
                  Color(0xFF2E1B11),
                  Color(0xFF180E09),
                  Color(0xFF0C0704),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          const RepaintBoundary(
            child: CustomPaint(painter: _SplashArabesquePainter()),
          ),
          SafeArea(
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
                      // Centerpiece: Fanned Iraqi Domino crest led by Dooshaysh (6-6)
                      FadeTransition(
                        opacity: _emblemOpacity,
                        child: ScaleTransition(
                          scale: _emblemScale,
                          child: _DominoCrestMedallion(skin: skin),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: _emblemOpacity,
                        child: Text(
                          l10n.appTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FadeTransition(
                        opacity: _emblemOpacity,
                        child: Text(
                          isAr
                              ? 'أصالة المقهى البغدادي'
                              : 'Authentic Baghdadi Café Edition',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.ivory.withValues(alpha: 0.72),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(flex: 4),
                      // Sculpted gold loading bar & live boot stage text
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
                                    style: TextStyle(
                                      color: AppColors.ivory.withValues(
                                        alpha: 0.82,
                                      ),
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
                              height: 7,
                              decoration: BoxDecoration(
                                color: const Color(0x66000000),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: FractionallySizedBox(
                                    widthFactor: progress.clamp(0.04, 1.0),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFFB8862D),
                                            AppColors.gold,
                                            Color(0xFFFFE599),
                                          ],
                                        ),
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
        ],
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
      width: 148,
      height: 148,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF235C3D), Color(0xFF112E1E)],
        ),
        border: Border.all(color: AppColors.gold, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(-26, 6),
            child: Transform.rotate(
              angle: -0.24,
              child: DominoTile(top: 5, bottom: 4, width: 32, skin: skin),
            ),
          ),
          Transform.translate(
            offset: const Offset(26, 6),
            child: Transform.rotate(
              angle: 0.24,
              child: DominoTile(top: 6, bottom: 5, width: 32, skin: skin),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -4),
            child: DominoTile(top: 6, bottom: 6, width: 38, skin: skin),
          ),
        ],
      ),
    );
  }
}

/// Subtle Baghdadi 8-pointed geometric star rings drawn behind the splash crest.
class _SplashArabesquePainter extends CustomPainter {
  const _SplashArabesquePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final maxR = math.min(size.width, size.height) * 0.44;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.gold.withValues(alpha: 0.08);

    for (final factor in [0.55, 0.78, 1.0]) {
      final r = maxR * factor;
      canvas.drawCircle(center, r, linePaint);
      _drawEightPointStar(canvas, center, r, linePaint);
    }
  }

  void _drawEightPointStar(
    Canvas canvas,
    Offset c,
    double r,
    Paint paint,
  ) {
    for (var rot = 0; rot < 2; rot++) {
      final offsetAngle = rot * (math.pi / 4);
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = offsetAngle + i * (math.pi / 2);
        final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
