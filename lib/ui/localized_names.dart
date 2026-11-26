import '../ai/ai_difficulty.dart';
import '../l10n/app_localizations.dart';
import '../rendering/tile_skin.dart';

/// Display name of a tile skin in the current language.
String tileSkinName(AppLocalizations l10n, TileSkin skin) {
  final isAr = l10n.localeName.startsWith('ar');
  return switch (skin.id) {
    'ebony' => l10n.skinEbony,
    'ruby' => l10n.skinRuby,
    'amber' => isAr ? 'كهرب' : 'Amber',
    'turquoise' => isAr ? 'فيروزي' : 'Turquoise',
    'pearl' => isAr ? 'صدفي' : 'Pearl',
    'royal_emerald' => isAr ? 'زمرد ملكي' : 'Royal Emerald',
    _ => l10n.skinIvory,
  };
}

/// Display name of an AI difficulty level in Arabic or English.
String aiDifficultyName(bool isAr, AiDifficulty difficulty) {
  return switch (difficulty) {
    AiDifficulty.easy => isAr ? 'سهل' : 'Easy',
    AiDifficulty.medium => isAr ? 'متوسط' : 'Medium',
    AiDifficulty.hard => isAr ? 'صعب' : 'Hard',
    AiDifficulty.expert => isAr ? 'خبير' : 'Expert',
  };
}
