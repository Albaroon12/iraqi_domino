import 'package:flutter/widgets.dart';

/// All colors that define how a domino tile looks.
/// A new skin is just a new constant here: no painting code changes.
class TileSkin {
  const TileSkin({
    required this.id,
    required this.bodyLight,
    required this.bodyDark,
    required this.bevelLight,
    required this.bevelDark,
    required this.grooveColor,
    required this.grooveEdge,
    required this.pipHighlight,
    required this.pipDark,
    required this.pipRim,
  });

  /// Stable identifier saved in settings / player profile.
  final String id;

  /// Tile body gradient: top-left color and bottom-right color.
  final Color bodyLight;
  final Color bodyDark;

  /// Inner edge: bright side and dark side.
  final Color bevelLight;
  final Color bevelDark;

  /// Center line: the groove and the light edge below it.
  final Color grooveColor;
  final Color grooveEdge;

  /// Pip radial gradient: lighter spot and main color.
  final Color pipHighlight;
  final Color pipDark;

  /// Thin ring under each pip that gives the engraved look.
  final Color pipRim;

  static const TileSkin ivory = TileSkin(
    id: 'ivory',
    bodyLight: Color(0xFFFBF6E9),
    bodyDark: Color(0xFFE8DEC5),
    bevelLight: Color(0xCCFFFFFF),
    bevelDark: Color(0x558A7550),
    grooveColor: Color(0x66000000),
    grooveEdge: Color(0xAAFFFFFF),
    pipHighlight: Color(0xFF3C3C3C),
    pipDark: Color(0xFF050505),
    pipRim: Color(0xAAFFFFFF),
  );

  static const TileSkin ebony = TileSkin(
    id: 'ebony',
    bodyLight: Color(0xFF3A3A3A),
    bodyDark: Color(0xFF0F0F0F),
    bevelLight: Color(0x55FFFFFF),
    bevelDark: Color(0x88000000),
    grooveColor: Color(0xAA000000),
    grooveEdge: Color(0x33FFFFFF),
    pipHighlight: Color(0xFFFFFFFF),
    pipDark: Color(0xFFD9CFB4),
    pipRim: Color(0x66000000),
  );

  static const TileSkin ruby = TileSkin(
    id: 'ruby',
    bodyLight: Color(0xFFC4443A),
    bodyDark: Color(0xFF7A1F19),
    bevelLight: Color(0x66FFFFFF),
    bevelDark: Color(0x88300000),
    grooveColor: Color(0x88000000),
    grooveEdge: Color(0x44FFFFFF),
    pipHighlight: Color(0xFFFFFFFF),
    pipDark: Color(0xFFF1E6CC),
    pipRim: Color(0x55000000),
  );

  static const TileSkin amber = TileSkin(
    id: 'amber',
    bodyLight: Color(0xFFF6BE58),
    bodyDark: Color(0xFFB86A14),
    bevelLight: Color(0x99FFF2C2),
    bevelDark: Color(0x775E2D00),
    grooveColor: Color(0x88421E00),
    grooveEdge: Color(0x88FFE49E),
    pipHighlight: Color(0xFF4A2508),
    pipDark: Color(0xFF1E0B00),
    pipRim: Color(0x77FFE6A8),
  );

  static const TileSkin turquoise = TileSkin(
    id: 'turquoise',
    bodyLight: Color(0xFF3BC4C0),
    bodyDark: Color(0xFF106A70),
    bevelLight: Color(0x88CCFBF8),
    bevelDark: Color(0x77053336),
    grooveColor: Color(0x88042B2E),
    grooveEdge: Color(0x66B8F5F0),
    pipHighlight: Color(0xFFFFF8DC),
    pipDark: Color(0xFFE6C667),
    pipRim: Color(0x55042B2E),
  );

  static const TileSkin pearl = TileSkin(
    id: 'pearl',
    bodyLight: Color(0xFFFFFFFF),
    bodyDark: Color(0xFFDCE4EE),
    bevelLight: Color(0xEEFFFFFF),
    bevelDark: Color(0x447C8EA6),
    grooveColor: Color(0x663B4D66),
    grooveEdge: Color(0xCCFFFFFF),
    pipHighlight: Color(0xFF28467A),
    pipDark: Color(0xFF0E1F3D),
    pipRim: Color(0xAAFFFFFF),
  );

  static const TileSkin royalEmerald = TileSkin(
    id: 'royal_emerald',
    bodyLight: Color(0xFF1D6B48),
    bodyDark: Color(0xFF072B1A),
    bevelLight: Color(0x77D4AF37),
    bevelDark: Color(0x9902120A),
    grooveColor: Color(0xCCD4AF37),
    grooveEdge: Color(0x66FFE082),
    pipHighlight: Color(0xFFFFF3B0),
    pipDark: Color(0xFFD4AF37),
    pipRim: Color(0x77031A0F),
  );

  /// Every Domino stone skin available in the game.
  static const List<TileSkin> all = [
    ivory,
    ebony,
    ruby,
    amber,
    turquoise,
    pearl,
    royalEmerald,
  ];

  /// Finds a skin by its saved id; falls back to ivory if unknown.
  static TileSkin byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => ivory);
}
