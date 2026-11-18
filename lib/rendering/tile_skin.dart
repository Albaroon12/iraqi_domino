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

  /// Stable identifier. This is what we will save in the player's profile.
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

  /// Every skin available in the game (later: filtered by what is owned).
  static const List<TileSkin> all = [ivory, ebony, ruby];

  /// Finds a skin by its saved id; falls back to ivory if unknown.
  static TileSkin byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => ivory);
}
