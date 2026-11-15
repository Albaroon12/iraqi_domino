import 'package:material_ui/material_ui.dart';

/// Central place for the game's color palette.
/// Keeping colors here means we can restyle the whole game from one file.
class AppColors {
  AppColors._(); // Private constructor: this class is never instantiated.

  /// Dark walnut wood tone used for backgrounds.
  static const Color walnut = Color(0xFF2B1B12);

  /// Warm gold accent used for highlights and titles.
  static const Color gold = Color(0xFFC9A24B);

  /// Ivory tone, matching the domino tile color.
  static const Color ivory = Color(0xFFF5EFE0);
}