import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Complete Design System & Token Specification extracted 1:1 from the owner's
/// Emerald-Teal & Royal Gold reference mockup for **المقهى** (`Al-Maqha`).
///
/// Visual Pillars:
/// 1. **Deep Emerald-Teal Canvas** (`#0B2F2F` -> `#163B38` -> `#1F4643`) with a
///    soft warm golden-olive center spotlight (`#2D4633`) and scattered
///    translucent rotated Domino silhouettes (`#224E4A`).
/// 2. **Matte Charcoal-Slate Surfaces** (`#182022`) for cards and action buttons,
///    creating crisp modern contrast against the emerald backdrop.
/// 3. **Warm Amber-Gold Accents** (`#F7CB62` -> `#E7BB50` -> `#D6AD41`) for
///    stadium primary CTAs, active navigation states, and icons.
class MaqhaColors {
  MaqhaColors._();

  // ---------------------------------------------------------------------------
  // 1. Background & Canvas Tokens (Emerald-Teal)
  // ---------------------------------------------------------------------------

  /// Deepest outer teal (status bar, native launch screen, & edge vignette).
  static const Color bgDeepTeal = Color(0xFF0B2F2F);

  /// Main screen dark emerald-teal base.
  static const Color bgEmeraldBase = Color(0xFF143A38);
  static const Color bgMidTeal = bgEmeraldBase;

  /// Lighter teal-emerald tone near lower/outer edges.
  static const Color bgEmeraldMid = Color(0xFF1F4643);
  static const Color bgSoftTeal = bgEmeraldMid;

  /// Subtle warm olive-gold atmospheric glow behind hero focal points.
  static const Color bgWarmSpotlight = Color(0xFF2D4633);

  /// Translucent rotated domino watermark tint on the background.
  static const Color dominoWatermark = Color(0x12FFFFFF);

  // ---------------------------------------------------------------------------
  // 2. Surface & Card Tokens (Matte Charcoal-Slate & Dark Glass)
  // ---------------------------------------------------------------------------

  /// Matte charcoal-slate fill used on mode cards & square top action buttons.
  static const Color cardCharcoal = Color(0xE8182022);

  /// Slightly elevated charcoal-slate fill for dialogs, racks, & selected items.
  static const Color cardCharcoalElevated = Color(0xF0202B2D);

  /// Floating navigation dock & side quick-action capsule fill.
  static const Color dockGlass = Color(0xE6142423);
  static const Color navDockGlass = dockGlass;

  /// Top-right player identity pill fill.
  static const Color profilePillFill = Color(0xDD172827);

  /// Jade emerald fill inside the circular player avatar/monogram.
  static const Color avatarJade = Color(0xFF0F583B);

  /// Olive-gold tinted glass fill inside the top currency stadium pill.
  static const Color currencyPillFill = Color(0x33E7BB50);

  /// Subtle hairline border on unselected dark cards and floating docks.
  static const Color borderSubtle = Color(0x17FFFFFF);

  /// Stronger card border on hover / secondary emphasis.
  static const Color borderMuted = Color(0x29FFFFFF);

  // ---------------------------------------------------------------------------
  // 3. Brand Gold & Accent Tokens
  // ---------------------------------------------------------------------------

  /// Bright top highlight gold (headlines, active nav icon, top of CTA pill).
  static const Color goldBright = Color(0xFFF7CB62);

  /// Primary brand gold (card icons, currency ring, active borders).
  static const Color goldPrimary = Color(0xFFE7BB50);

  /// Deeper warm gold at the bottom of the primary stadium CTA gradient.
  static const Color goldDeep = Color(0xFFD6AD41);

  /// Soft ambient gold glow cast by the hero "العب الآن" stadium button.
  static const Color goldGlow = Color(0x4DE7BB50);

  // ---------------------------------------------------------------------------
  // 4. Typography & Semantic Status Tokens
  // ---------------------------------------------------------------------------

  /// Crisp off-white for primary titles and player names.
  static const Color textPrimary = Color(0xFFF4F7F6);

  /// Muted sage-gray for card subtitles, dividers, and inactive nav items.
  static const Color textSecondary = Color(0xFF8FA3A0);
  static const Color textMuted = textSecondary;

  /// Warm sand-ivory tint used on top-bar utility icons (bell, friends, gear).
  static const Color iconSand = Color(0xFFD6CEBE);

  /// High-contrast dark espresso text inside bright gold CTA buttons.
  static const Color textOnGold = Color(0xFF231304);

  /// Notification badge crimson-coral red (`1` badge on bell icon).
  static const Color badgeRed = Color(0xFFD93829);

  /// Positive / online / active emerald indicator.
  static const Color statusSuccess = Color(0xFF4CAF7D);
}

/// Reusable gradients matching the reference UI.
class MaqhaGradients {
  MaqhaGradients._();

  /// Base vertical/diagonal emerald-teal canvas gradient.
  static const LinearGradient screenCanvas = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0E3332),
      Color(0xFF173E3B),
      Color(0xFF1D4642),
      Color(0xFF103433),
    ],
    stops: [0.0, 0.38, 0.72, 1.0],
  );

  /// Warm golden-olive spotlight centered behind the hero CTA area.
  static const RadialGradient centerWarmGlow = RadialGradient(
    center: Alignment(0.0, -0.08),
    radius: 0.72,
    colors: [
      Color(0x38E7BB50),
      Color(0x182D4633),
      Color(0x00000000),
    ],
    stops: [0.0, 0.52, 1.0],
  );

  /// Signature stadium pill CTA gradient (`العب الآن`).
  static const LinearGradient primaryGoldCta = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      MaqhaColors.goldBright,
      MaqhaColors.goldPrimary,
      MaqhaColors.goldDeep,
    ],
    stops: [0.0, 0.52, 1.0],
  );

  /// Matte charcoal-slate card gradient.
  static const LinearGradient charcoalCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xEE1C2527),
      Color(0xEE151C1E),
    ],
  );
}

/// Corner radii tokens used across the new design system.
class MaqhaRadii {
  MaqhaRadii._();

  static const BorderRadius topIconBox = BorderRadius.all(Radius.circular(11));
  static const BorderRadius modeCard = BorderRadius.all(Radius.circular(16));
  static const BorderRadius panelCard = BorderRadius.all(Radius.circular(20));
  static const BorderRadius floatingDock = BorderRadius.all(
    Radius.circular(26),
  );
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Elevation & glow shadows extracted from the reference design.
class MaqhaShadows {
  MaqhaShadows._();

  static const List<BoxShadow> goldCtaGlow = [
    BoxShadow(
      color: MaqhaColors.goldGlow,
      blurRadius: 24,
      spreadRadius: 1,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x55000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> softCard = [
    BoxShadow(
      color: Color(0x52000000),
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> cardShadow = softCard;
}

/// Typography hierarchy built on the bundled `Cairo` font family.
class MaqhaTextStyles {
  MaqhaTextStyles._();

  static const String fontFamily = 'Cairo';

  static const TextStyle displayGoldTitle = TextStyle(
    fontFamily: fontFamily,
    color: MaqhaColors.goldBright,
    fontSize: 26,
    fontWeight: FontWeight.w900,
    height: 1.2,
  );

  static const TextStyle heroPrompt = TextStyle(
    fontFamily: fontFamily,
    color: MaqhaColors.textPrimary,
    fontSize: 19,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle ctaButtonLabel = TextStyle(
    fontFamily: fontFamily,
    color: MaqhaColors.textOnGold,
    fontSize: 19,
    fontWeight: FontWeight.w900,
    height: 1.15,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    color: MaqhaColors.textPrimary,
    fontSize: 14.5,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontFamily: fontFamily,
    color: MaqhaColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
}

/// Builds the Material 3 `ThemeData` for the Emerald-Teal & Gold **المقهى** UI.
class MaqhaTheme {
  MaqhaTheme._();

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: MaqhaColors.goldPrimary,
      brightness: Brightness.dark,
      primary: MaqhaColors.goldPrimary,
      onPrimary: MaqhaColors.textOnGold,
      surface: MaqhaColors.bgEmeraldBase,
      onSurface: MaqhaColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: MaqhaTextStyles.fontFamily,
      scaffoldBackgroundColor: MaqhaColors.bgDeepTeal,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: MaqhaColors.textPrimary,
        centerTitle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MaqhaColors.cardCharcoal,
        contentTextStyle: const TextStyle(
          fontFamily: MaqhaTextStyles.fontFamily,
          color: MaqhaColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF162223),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: MaqhaColors.borderMuted),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MaqhaColors.cardCharcoal,
        selectedColor: MaqhaColors.currencyPillFill,
        side: const BorderSide(color: MaqhaColors.borderSubtle),
        labelStyle: const TextStyle(
          fontFamily: MaqhaTextStyles.fontFamily,
          color: MaqhaColors.textPrimary,
          fontSize: 12,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: MaqhaTextStyles.fontFamily,
          color: MaqhaColors.goldBright,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

// =============================================================================
// Reusable Signature UI Components Matching the Reference Mockup
// =============================================================================

/// Full-screen background canvas painting:
/// 1. Deep Emerald-Teal gradient
/// 2. Soft warm golden-olive center spotlight
/// 3. Scattered translucent rotated Domino tile watermarks (`RepaintBoundary` cached)
class MaqhaEmeraldBackground extends StatelessWidget {
  const MaqhaEmeraldBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(
          child: CustomPaint(painter: _EmeraldDominoBackdropPainter()),
        ),
        child,
      ],
    );
  }
}

class _EmeraldDominoBackdropPainter extends CustomPainter {
  const _EmeraldDominoBackdropPainter();

  static const List<({double x, double y, double angle, int top, int bot, double scale})>
  _tiles = [
    (x: 0.10, y: 0.18, angle: -0.32, top: 3, bot: 5, scale: 1.05),
    (x: 0.86, y: 0.15, angle: 0.28, top: 6, bot: 4, scale: 1.15),
    (x: 0.72, y: 0.30, angle: -0.22, top: 2, bot: 2, scale: 0.92),
    (x: 0.24, y: 0.62, angle: 0.18, top: 5, bot: 1, scale: 1.10),
    (x: 0.08, y: 0.88, angle: 1.48, top: 4, bot: 5, scale: 0.95),
    (x: 0.62, y: 0.44, angle: 0.05, top: 1, bot: 3, scale: 1.00),
    (x: 0.90, y: 0.82, angle: -0.26, top: 6, bot: 6, scale: 1.08),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Emerald-teal base gradient
    canvas.drawRect(
      rect,
      Paint()..shader = MaqhaGradients.screenCanvas.createShader(rect),
    );

    // 2. Warm golden-olive spotlight in the center
    canvas.drawRect(
      rect,
      Paint()..shader = MaqhaGradients.centerWarmGlow.createShader(rect),
    );

    // 3. Subtle rotated translucent domino silhouettes
    final shortest = math.min(size.width, size.height);
    final baseW = (shortest * 0.14).clamp(42.0, 74.0);

    final bodyFill = Paint()..color = const Color(0x0BFFFFFF);
    final bodyStroke = Paint()
      ..color = const Color(0x16FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final pipPaint = Paint()..color = const Color(0x12FFFFFF);

    for (final t in _tiles) {
      final w = baseW * t.scale;
      final h = w * 1.95;
      canvas.save();
      canvas.translate(size.width * t.x, size.height * t.y);
      canvas.rotate(t.angle);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        Radius.circular(w * 0.18),
      );
      canvas.drawRRect(rrect, bodyFill);
      canvas.drawRRect(rrect, bodyStroke);
      canvas.drawLine(
        Offset(-w * 0.38, 0),
        Offset(w * 0.38, 0),
        bodyStroke,
      );

      _drawWatermarkPips(canvas, Offset(0, -h * 0.24), w * 0.34, t.top, pipPaint);
      _drawWatermarkPips(canvas, Offset(0, h * 0.24), w * 0.34, t.bot, pipPaint);

      canvas.restore();
    }
  }

  void _drawWatermarkPips(
    Canvas canvas,
    Offset center,
    double span,
    int count,
    Paint paint,
  ) {
    final r = span * 0.13;
    List<Offset> offsets = switch (count) {
      1 => [Offset.zero],
      2 => [Offset(-span * 0.5, -span * 0.5), Offset(span * 0.5, span * 0.5)],
      3 => [
        Offset(-span * 0.5, -span * 0.5),
        Offset.zero,
        Offset(span * 0.5, span * 0.5),
      ],
      4 => [
        Offset(-span * 0.5, -span * 0.5),
        Offset(span * 0.5, -span * 0.5),
        Offset(-span * 0.5, span * 0.5),
        Offset(span * 0.5, span * 0.5),
      ],
      5 => [
        Offset(-span * 0.5, -span * 0.5),
        Offset(span * 0.5, -span * 0.5),
        Offset.zero,
        Offset(-span * 0.5, span * 0.5),
        Offset(span * 0.5, span * 0.5),
      ],
      _ => [
        Offset(-span * 0.5, -span * 0.55),
        Offset(span * 0.5, -span * 0.55),
        Offset(-span * 0.5, 0),
        Offset(span * 0.5, 0),
        Offset(-span * 0.5, span * 0.55),
        Offset(span * 0.5, span * 0.55),
      ],
    };
    for (final o in offsets) {
      canvas.drawCircle(center + o, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Primary hero stadium CTA button (`العب الآن ◀`) with golden glow.
class MaqhaGoldPillButton extends StatelessWidget {
  const MaqhaGoldPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.showPlayArrow = true,
    this.leadingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool showPlayArrow;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: MaqhaGradients.primaryGoldCta,
          borderRadius: MaqhaRadii.pill,
          boxShadow: enabled ? MaqhaShadows.goldCtaGlow : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: MaqhaRadii.pill,
            onTap: onPressed,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (leadingIcon != null) ...[
                          Icon(
                            leadingIcon,
                            color: MaqhaColors.textOnGold,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(label, style: MaqhaTextStyles.ctaButtonLabel),
                        if (showPlayArrow) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: MaqhaColors.textOnGold,
                            size: 24,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Matte charcoal-slate mode card (`فرق 2×2`, `تدريب`, `لعب محلي`, `المزيد`).
class MaqhaModeCard extends StatelessWidget {
  const MaqhaModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: MaqhaGradients.charcoalCard,
        borderRadius: MaqhaRadii.modeCard,
        border: Border.all(
          color: highlighted
              ? MaqhaColors.goldPrimary.withValues(alpha: 0.7)
              : MaqhaColors.borderSubtle,
          width: highlighted ? 1.4 : 1.0,
        ),
        boxShadow: MaqhaShadows.softCard,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: MaqhaRadii.modeCard,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: MaqhaColors.goldPrimary, size: 26),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: MaqhaTextStyles.cardTitle,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: MaqhaTextStyles.cardSubtitle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `40×40` squircle top-bar utility button with optional red notification badge.
class MaqhaTopIconButton extends StatelessWidget {
  const MaqhaTopIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: MaqhaColors.cardCharcoal,
          borderRadius: MaqhaRadii.topIconBox,
          child: InkWell(
            borderRadius: MaqhaRadii.topIconBox,
            onTap: onTap,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: MaqhaRadii.topIconBox,
                border: Border.all(color: MaqhaColors.borderSubtle),
              ),
              child: Icon(icon, color: MaqhaColors.iconSand, size: 19),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -4,
            left: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: MaqhaColors.badgeRed,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Top-right floating player identity capsule (`نجم الدومينو • بلاتيني` + jade avatar).
class MaqhaPlayerIdentityPill extends StatelessWidget {
  const MaqhaPlayerIdentityPill({
    super.key,
    required this.displayName,
    required this.rankTitle,
    this.avatarChild,
    this.onTap,
  });

  final String displayName;
  final String rankTitle;
  final Widget? avatarChild;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty
        ? 'م'
        : displayName.trim().characters.first;

    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 156),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 3, 10, 3),
          decoration: BoxDecoration(
            color: MaqhaColors.profilePillFill,
            borderRadius: MaqhaRadii.pill,
            border: Border.all(color: MaqhaColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MaqhaColors.avatarJade,
                  border: Border.all(
                    color: MaqhaColors.goldPrimary,
                    width: 1.3,
                  ),
                ),
                child: avatarChild != null
                    ? ClipOval(child: avatarChild)
                    : Text(
                        initial,
                        style: const TextStyle(
                          color: MaqhaColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MaqhaColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                    Text(
                      rankTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MaqhaColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
