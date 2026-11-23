/// AI difficulty levels for computer opponents and partners.
/// Pure Dart (no Flutter imports).
enum AiDifficulty {
  easy('easy'),
  medium('medium'),
  hard('hard'),
  expert('expert');

  const AiDifficulty(this.id);

  final String id;

  static AiDifficulty byId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return AiDifficulty.medium;
  }
}
