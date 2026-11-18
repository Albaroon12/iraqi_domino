import 'package:flutter/widgets.dart';

/// Colors and settings that define how the wooden table looks.
class TableSkin {
  const TableSkin({
    required this.id,
    required this.woodLight,
    required this.woodDark,
    required this.grainLight,
    required this.grainDark,
    required this.rim,
    required this.vignette,
    required this.grainSeed,
  });

  final String id;

  /// Base wood gradient: top color and bottom color.
  final Color woodLight;
  final Color woodDark;

  /// Colors of the grain lines (light streaks and dark streaks).
  final Color grainLight;
  final Color grainDark;

  /// Table frame color and the dark fade around the edges.
  final Color rim;
  final Color vignette;

  /// Fixed seed so the grain looks the same on every launch.
  final int grainSeed;

  static const TableSkin walnut = TableSkin(
    id: 'walnut',
    woodLight: Color(0xFF5A3A24),
    woodDark: Color(0xFF2E1B10),
    grainLight: Color(0xFF8A5E3C),
    grainDark: Color(0xFF1A0E07),
    rim: Color(0xFF1D110A),
    vignette: Color(0x99000000),
    grainSeed: 7,
  );

  static const List<TableSkin> all = [walnut];

  static TableSkin byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => walnut);
}
