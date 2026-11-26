import 'package:flutter/widgets.dart';

/// Center ornament or country flag woven into a `BoardFrame` playing cloth.
enum BoardMotifKind {
  classic,
  damascusStar,
  heritageCarpet,
  abbasidMosaic,
  obsidianGold,
  flagIraq,
  flagSaudi,
  flagKuwait,
  flagUae,
  flagQatar,
  flagJordan,
  flagEgypt,
  flagPalestine,
  flagSyria,
  flagTurkey,
}

/// Visual configuration for a Café playing table (`ShopCategory.tables`).
class BoardTheme {
  const BoardTheme({
    required this.id,
    required this.feltLight,
    required this.feltDark,
    this.frameLight = const Color(0xFF7B4E2D),
    this.frameDark = const Color(0xFF28150A),
    this.motif = BoardMotifKind.classic,
  });

  final String id;
  final Color feltLight;
  final Color feltDark;
  final Color frameLight;
  final Color frameDark;
  final BoardMotifKind motif;

  static const BoardTheme classicGreen = BoardTheme(
    id: 'table_classic_green',
    feltLight: Color(0xFF235C3D),
    feltDark: Color(0xFF0E2C1C),
    motif: BoardMotifKind.classic,
  );

  static const BoardTheme royalCrimson = BoardTheme(
    id: 'table_royal_crimson',
    feltLight: Color(0xFF6E1E26),
    feltDark: Color(0xFF2E090D),
    frameLight: Color(0xFF8A5630),
    frameDark: Color(0xFF2B1408),
    motif: BoardMotifKind.damascusStar,
  );

  static const BoardTheme damascusBlue = BoardTheme(
    id: 'table_damascus_blue',
    feltLight: Color(0xFF1D466B),
    feltDark: Color(0xFF0B1F33),
    frameLight: Color(0xFF6E472B),
    frameDark: Color(0xFF221208),
    motif: BoardMotifKind.damascusStar,
  );

  static const BoardTheme heritageCarpet = BoardTheme(
    id: 'table_heritage_carpet',
    feltLight: Color(0xFF6B241C),
    feltDark: Color(0xFF2A0D0A),
    frameLight: Color(0xFF8C5A2B),
    frameDark: Color(0xFF2E180A),
    motif: BoardMotifKind.heritageCarpet,
  );

  static const BoardTheme abbasidMosaic = BoardTheme(
    id: 'table_abbasid_mosaic',
    feltLight: Color(0xFF165B5C),
    feltDark: Color(0xFF072829),
    frameLight: Color(0xFF8F6B29),
    frameDark: Color(0xFF291B07),
    motif: BoardMotifKind.abbasidMosaic,
  );

  static const BoardTheme obsidianGold = BoardTheme(
    id: 'table_obsidian_gold',
    feltLight: Color(0xFF2B2825),
    feltDark: Color(0xFF100E0C),
    frameLight: Color(0xFFA67C2E),
    frameDark: Color(0xFF2B1E08),
    motif: BoardMotifKind.obsidianGold,
  );

  static const BoardTheme flagIraq = BoardTheme(
    id: 'table_flag_iraq',
    feltLight: Color(0xFF1E4D33),
    feltDark: Color(0xFF0C2417),
    motif: BoardMotifKind.flagIraq,
  );

  static const BoardTheme flagSaudi = BoardTheme(
    id: 'table_flag_saudi',
    feltLight: Color(0xFF185E36),
    feltDark: Color(0xFF092B18),
    motif: BoardMotifKind.flagSaudi,
  );

  static const BoardTheme flagKuwait = BoardTheme(
    id: 'table_flag_kuwait',
    feltLight: Color(0xFF1E5245),
    feltDark: Color(0xFF0B261F),
    motif: BoardMotifKind.flagKuwait,
  );

  static const BoardTheme flagUae = BoardTheme(
    id: 'table_flag_uae',
    feltLight: Color(0xFF1F543D),
    feltDark: Color(0xFF0C261B),
    motif: BoardMotifKind.flagUae,
  );

  static const BoardTheme flagQatar = BoardTheme(
    id: 'table_flag_qatar',
    feltLight: Color(0xFF6B1D35),
    feltDark: Color(0xFF2E0915),
    motif: BoardMotifKind.flagQatar,
  );

  static const BoardTheme flagJordan = BoardTheme(
    id: 'table_flag_jordan',
    feltLight: Color(0xFF1F5238),
    feltDark: Color(0xFF0B2618),
    motif: BoardMotifKind.flagJordan,
  );

  static const BoardTheme flagEgypt = BoardTheme(
    id: 'table_flag_egypt',
    feltLight: Color(0xFF4F2222),
    feltDark: Color(0xFF210B0B),
    motif: BoardMotifKind.flagEgypt,
  );

  static const BoardTheme flagPalestine = BoardTheme(
    id: 'table_flag_palestine',
    feltLight: Color(0xFF1E5438),
    feltDark: Color(0xFF0C2618),
    motif: BoardMotifKind.flagPalestine,
  );

  static const BoardTheme flagSyria = BoardTheme(
    id: 'table_flag_syria',
    feltLight: Color(0xFF1F4E3B),
    feltDark: Color(0xFF0B241A),
    motif: BoardMotifKind.flagSyria,
  );

  static const BoardTheme flagTurkey = BoardTheme(
    id: 'table_flag_turkey',
    feltLight: Color(0xFF701C24),
    feltDark: Color(0xFF30090D),
    motif: BoardMotifKind.flagTurkey,
  );

  static const List<BoardTheme> all = [
    classicGreen,
    royalCrimson,
    damascusBlue,
    heritageCarpet,
    abbasidMosaic,
    obsidianGold,
    flagIraq,
    flagSaudi,
    flagKuwait,
    flagUae,
    flagQatar,
    flagJordan,
    flagEgypt,
    flagPalestine,
    flagSyria,
    flagTurkey,
  ];

  static BoardTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => classicGreen);
}
