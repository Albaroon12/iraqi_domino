import 'dart:math' as math;

/// Visual accessory style drawn by `AiPersonaAvatar` in the UI layer.
enum AiAvatarStyle {
  sidara,
  glasses,
  mustache,
  keffiyeh,
  classic,
  beard,
  headband,
  fez,
  scarf,
  crown,
}

/// One of the 10 named Iraqi Domino AI characters.
///
/// Pure Dart (no Flutter imports) so both the client UI and a future Dart
/// server can assign and serialize AI personas identically.
class AiPersona {
  const AiPersona({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.primaryColorHex,
    required this.accentColorHex,
    required this.avatarStyle,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final int primaryColorHex;
  final int accentColorHex;
  final AiAvatarStyle avatarStyle;

  String name(bool isAr) => isAr ? nameAr : nameEn;

  /// All 10 distinct AI personas available in the game.
  static const List<AiPersona> all = [
    AiPersona(
      id: 'abu_ali',
      nameAr: 'أبو علي',
      nameEn: 'Abu Ali',
      primaryColorHex: 0xFF6B3F21,
      accentColorHex: 0xFFD9A441,
      avatarStyle: AiAvatarStyle.sidara,
    ),
    AiPersona(
      id: 'haider',
      nameAr: 'حيدر',
      nameEn: 'Haider',
      primaryColorHex: 0xFF1A4E5E,
      accentColorHex: 0xFF5EC2D6,
      avatarStyle: AiAvatarStyle.glasses,
    ),
    AiPersona(
      id: 'karrar',
      nameAr: 'كرار',
      nameEn: 'Karrar',
      primaryColorHex: 0xFF5B1E28,
      accentColorHex: 0xFFE07A5F,
      avatarStyle: AiAvatarStyle.mustache,
    ),
    AiPersona(
      id: 'hajji_jassim',
      nameAr: 'الحجّي جاسم',
      nameEn: 'Hajji Jassim',
      primaryColorHex: 0xFF474B24,
      accentColorHex: 0xFFE2C97E,
      avatarStyle: AiAvatarStyle.keffiyeh,
    ),
    AiPersona(
      id: 'zaid',
      nameAr: 'زيد',
      nameEn: 'Zaid',
      primaryColorHex: 0xFF1E3563,
      accentColorHex: 0xFF7FA6EE,
      avatarStyle: AiAvatarStyle.classic,
    ),
    AiPersona(
      id: 'mustafa',
      nameAr: 'مصطفى',
      nameEn: 'Mustafa',
      primaryColorHex: 0xFF1E4A34,
      accentColorHex: 0xFF6FCF97,
      avatarStyle: AiAvatarStyle.beard,
    ),
    AiPersona(
      id: 'aws',
      nameAr: 'أوس',
      nameEn: 'Aws',
      primaryColorHex: 0xFF44285B,
      accentColorHex: 0xFFB88AE6,
      avatarStyle: AiAvatarStyle.headband,
    ),
    AiPersona(
      id: 'sajjad',
      nameAr: 'سجاد',
      nameEn: 'Sajjad',
      primaryColorHex: 0xFF692B1C,
      accentColorHex: 0xFFF2994A,
      avatarStyle: AiAvatarStyle.fez,
    ),
    AiPersona(
      id: 'noor',
      nameAr: 'نور',
      nameEn: 'Noor',
      primaryColorHex: 0xFF5A2346,
      accentColorHex: 0xFFF29BC2,
      avatarStyle: AiAvatarStyle.scarf,
    ),
    AiPersona(
      id: 'reem',
      nameAr: 'ريم',
      nameEn: 'Reem',
      primaryColorHex: 0xFF174F4A,
      accentColorHex: 0xFF7CE0D3,
      avatarStyle: AiAvatarStyle.crown,
    ),
  ];

  /// Looks up a persona by [id], falling back to `all.first` (`أبو علي`).
  static AiPersona byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return all.first;
  }

  /// Picks [count] distinct AI personas excluding any IDs in [excludeIds].
  static List<AiPersona> pickDistinct(
    int count,
    math.Random random, {
    Set<String> excludeIds = const {},
  }) {
    final pool = [
      for (final p in all)
        if (!excludeIds.contains(p.id)) p,
    ]..shuffle(random);

    if (pool.length >= count) {
      return pool.sublist(0, count);
    }
    // Fallback if count ever exceeded pool length.
    final full = [...all]..shuffle(random);
    return full.sublist(0, math.min(count, full.length));
  }
}
