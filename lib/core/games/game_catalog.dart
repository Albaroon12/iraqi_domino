import 'package:material_ui/material_ui.dart';

import '../../ui/screens/mode_selection_screen.dart';

/// Metadata for one game inside the app's multi-game catalog.
///
/// New games can be added under `lib/games/<id>/` and registered in
/// [GameCatalog.entries] without modifying the navigation shell.
class GameEntry {
  const GameEntry({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.icon,
    required this.available,
    this.builder,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final IconData icon;
  final bool available;
  final WidgetBuilder? builder;

  String title(bool isArabic) => isArabic ? titleAr : titleEn;
  String subtitle(bool isArabic) => isArabic ? subtitleAr : subtitleEn;
}

/// Central registry of games hosted by the application.
class GameCatalog {
  GameCatalog._();

  static final List<GameEntry> entries = [
    GameEntry(
      id: 'iraqi_domino',
      titleAr: 'الدومينو العراقي',
      titleEn: 'Iraqi Domino',
      subtitleAr: 'لاعبان، أربعة لاعبين (شراكة)، وأزنيف قريباً',
      subtitleEn: '2 players, 4 players (partners), Azneef coming soon',
      icon: Icons.casino_rounded,
      available: true,
      builder: (_) => const ModeSelectionScreen(),
    ),
    const GameEntry(
      id: 'backgammon',
      titleAr: 'طاولة الزهر',
      titleEn: 'Backgammon',
      subtitleAr: 'قريباً — لعبة المقاهي الكلاسيكية',
      subtitleEn: 'Coming soon — classic café board game',
      icon: Icons.grid_view_rounded,
      available: false,
    ),
    const GameEntry(
      id: 'cards',
      titleAr: 'ألعاب الورق',
      titleEn: 'Card Games',
      subtitleAr: 'قريباً — تحديات ورق جماعية',
      subtitleEn: 'Coming soon — multiplayer card challenges',
      icon: Icons.style_rounded,
      available: false,
    ),
  ];
}
