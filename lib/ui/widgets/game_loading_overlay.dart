import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/tile_skin.dart';
import '../../state/settings_provider.dart';

/// Wraps [child] and displays a themed Iraqi Domino loading modal whenever
/// [visible] is true (e.g., while creating a room, joining by room code,
/// connecting to the online WebSocket server, or searching in matchmaking).
class GameLoadingOverlay extends StatelessWidget {
  const GameLoadingOverlay({
    super.key,
    required this.visible,
    required this.title,
    this.subtitle,
    this.onCancel,
    required this.child,
  });

  final bool visible;
  final String title;
  final String? subtitle;
  final VoidCallback? onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: visible ? StackFit.expand : StackFit.passthrough,
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xCC081E1E),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: GameLoadingCard(
                    title: title,
                    subtitle: subtitle,
                    onCancel: onCancel,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Standalone themed Iraqi Domino loading card with an animated 3-tile wave,
/// live status subtitle, rotating gameplay tip, and optional Cancel action.
class GameLoadingCard extends ConsumerStatefulWidget {
  const GameLoadingCard({
    super.key,
    required this.title,
    this.subtitle,
    this.onCancel,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onCancel;

  @override
  ConsumerState<GameLoadingCard> createState() => _GameLoadingCardState();
}

class _GameLoadingCardState extends ConsumerState<GameLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  late final int _tipIndex;

  static const List<(String, String)> _tips = [
    (
      'الدوشيش (6-6) يفتتح الجولة الأولى دائماً في طور الأربعة لاعبين.',
      'Double-six (6-6) always opens the first round in 4-player mode.',
    ),
    (
      'في لعب الشراكة، راقب الرقم الذي يفتحه شريكك وحاول إبقاؤه مفتوحاً له.',
      'In partnership mode, watch the suit your partner opens and support it.',
    ),
    (
      'عند فوزك بالجولة، تُحسب لك نقاط أحجار الخصوم فقط دون أحجار شريكك.',
      'When your team wins a round, only opponents\' remaining pips are scored.',
    ),
    (
      'التخلص المبكر من الدبلات الثقيلة يحميك عند قفل الطاولة.',
      'Shedding heavy doubles early protects your score if the board locks.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tipIndex = DateTime.now().second % _tips.length;
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final skin = TileSkin.byId(ref.watch(settingsProvider).tileSkinId);
    final tip = isAr ? _tips[_tipIndex].$1 : _tips[_tipIndex].$2;

    const sampleTiles = [(6, 6), (5, 3), (4, 2)];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        decoration: BoxDecoration(
          color: const Color(0xF2182022),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.borderSubtle,
            width: 1.1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated 3-tile domino wave
            SizedBox(
              height: 76,
              child: AnimatedBuilder(
                animation: _waveCtrl,
                builder: (context, _) {
                  final phase = _waveCtrl.value * 2 * math.pi;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < sampleTiles.length; i++) ...[
                        if (i > 0) const SizedBox(width: 14),
                        Transform.translate(
                          offset: Offset(
                            0,
                            -6.5 * math.sin(phase - i * 0.9),
                          ),
                          child: DominoTile(
                            top: sampleTiles[i].$1,
                            bottom: sampleTiles[i].$2,
                            width: 28,
                            skin: skin,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.ivory.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: AppColors.gold.withValues(alpha: 0.16),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0x44000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.gold,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onCancel != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.ivory,
                ),
                label: Text(
                  isAr ? 'إلغاء' : 'Cancel',
                  style: const TextStyle(color: AppColors.ivory, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
