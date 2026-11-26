import 'package:material_ui/material_ui.dart';

import 'maqha_design_system.dart';

/// Builds the app-wide Emerald-Teal, Matte Charcoal, & Warm Gold theme.
class AppTheme {
  AppTheme._();

  /// Font family declared in pubspec.yaml (bundled, works offline).
  static const String fontFamily = MaqhaTextStyles.fontFamily;

  static ThemeData get dark => MaqhaTheme.dark;
}
