import 'package:material_ui/material_ui.dart';

import '../../core/theme/maqha_design_system.dart';

/// Unified button matching the Emerald & Gold reference design:
/// - `primary: true` -> Warm amber-gold gradient (`#F7CB62 -> #D6AD41`), stadium
///   pill shape (`999` radius when single-line, `16px` when carrying a subtitle),
///   dark `#231304` text, and soft golden glow.
/// - `primary: false` -> Matte charcoal-slate (`#182022`) surface with a crisp
///   `1px` subtle border, gold icon, off-white title, and muted sage subtitle.
class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.icon,
    this.primary = false,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    final radius = primary && !hasSubtitle
        ? MaqhaRadii.pill
        : MaqhaRadii.modeCard;
    final fgTitle = primary ? MaqhaColors.textOnGold : MaqhaColors.textPrimary;
    final fgSub = primary
        ? MaqhaColors.textOnGold.withValues(alpha: 0.72)
        : MaqhaColors.textSecondary;
    final iconColor = primary ? MaqhaColors.textOnGold : MaqhaColors.goldPrimary;

    return Opacity(
      opacity: enabled ? 1.0 : 0.48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: primary
              ? MaqhaGradients.primaryGoldCta
              : MaqhaGradients.charcoalCard,
          borderRadius: radius,
          border: primary
              ? null
              : Border.all(color: MaqhaColors.borderSubtle, width: 1),
          boxShadow: enabled
              ? (primary ? MaqhaShadows.goldCtaGlow : MaqhaShadows.softCard)
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: hasSubtitle ? 12 : 13,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: iconColor, size: 21),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: fgTitle,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        if (hasSubtitle) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fgSub,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }
}
