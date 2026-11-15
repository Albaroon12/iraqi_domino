import 'package:material_ui/material_ui.dart';

import '../constants/app_colors.dart';

/// Builds the app-wide theme.
class AppTheme {
  AppTheme._();

  /// Font family declared in pubspec.yaml (bundled, works offline).
  static const String fontFamily = 'Cairo';

  static ThemeData get dark {
    // Generate a full Material 3 color scheme from our gold accent,
    // then override the surface color with dark walnut.
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.dark,
      surface: AppColors.walnut,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.walnut,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.walnut,
        foregroundColor: AppColors.ivory,
        centerTitle: true,
      ),
    );
  }
}