import 'package:material_ui/material_ui.dart';

import '../theme/maqha_design_system.dart';

/// Central color palette mapped to the **المقهى** Emerald-Teal, Matte Charcoal,
/// and Warm Amber-Gold design system.
class AppColors {
  AppColors._();

  /// Deep dark surface / text-on-gold contrast tone (`#182022` / `#0B2F2F`).
  static const Color walnut = MaqhaColors.bgDeepTeal;

  /// Signature warm amber-gold accent (`#E7BB50`).
  static const Color gold = MaqhaColors.goldPrimary;

  /// Crisp off-white primary text & icon tone (`#F4F7F6`).
  static const Color ivory = MaqhaColors.textPrimary;

  /// Matte charcoal-slate card fill (`#182022`).
  static const Color surfaceCharcoal = MaqhaColors.cardCharcoal;

  /// Floating navigation dock dark-glass fill (`#142423`).
  static const Color dockGlass = MaqhaColors.dockGlass;

  /// Muted sage-gray secondary text (`#8FA3A0`).
  static const Color textMuted = MaqhaColors.textSecondary;

  /// Subtle hairline border (`rgba(255,255,255,0.09)`).
  static const Color borderSubtle = MaqhaColors.borderSubtle;
}
