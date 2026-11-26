import 'dart:math';

import 'player_account.dart';

/// Difficulty tier of a game-specific achievement badge. Pure Dart.
enum BadgeDifficulty {
  easy('easy', xpReward: 50),
  medium('medium', xpReward: 120),
  hard('hard', xpReward: 250),
  legendary('legendary', xpReward: 500);

  const BadgeDifficulty(this.id, {required this.xpReward});

  final String id;

  /// Bonus XP granted immediately on unlock (bypasses the daily match XP cap).
  final int xpReward;

  String label(bool isAr) => switch (this) {
    BadgeDifficulty.easy => isAr ? 'سهل' : 'Easy',
    BadgeDifficulty.medium => isAr ? 'متوسط' : 'Medium',
    BadgeDifficulty.hard => isAr ? 'صعب' : 'Hard',
    BadgeDifficulty.legendary => isAr ? 'أسطوري' : 'Legendary',
  };
}

/// Definition of one per-game achievement badge. Pure Dart.
class GameBadgeDefinition {
  const GameBadgeDefinition({
    required this.id,
    required this.gameId,
    required this.difficulty,
    required this.titleAr,
    required this.titleEn,
    required this.descAr,
    required this.descEn,
    required this.targetValue,
    required this.currentValueOf,
  });

  final String id;
  final String gameId;
  final BadgeDifficulty difficulty;
  final String titleAr;
  final String titleEn;
  final String descAr;
  final String descEn;
  final int targetValue;
  final int Function(PlayerStats stats) currentValueOf;

  String title(bool isAr) => isAr ? titleAr : titleEn;
  String description(bool isAr) => isAr ? descAr : descEn;

  int progressValue(PlayerStats stats) =>
      min(targetValue, max(0, currentValueOf(stats)));

  bool isMet(PlayerStats stats) => currentValueOf(stats) >= targetValue;
}

/// Pure-Dart progression engine for the Iraqi Café multi-game hub:
/// - **Max Level**: 50 (fast & easy from Level 1 to 10, progressively harder
///   from Level 11 to 50).
/// - **Daily Match XP Cap**: `2,000 XP/day` (doubled to `4,000 XP/day` for VIP).
///   Badge & event XP bypass the daily match cap.
/// - **Match XP Rule**:
///   - Offline vs AI gives **`0 XP`** from match/round play.
///   - Online play (even with AI filling open/disconnected seats) awards:
///     `+10 XP` per round won, `+5 XP` per round lost, `+60 XP` for match win,
///     `+20 XP` for match loss (all doubled `×2` for VIP).
/// - **Café Titles**: determined by Leaderboard Rank & Rating (general to the
///   Iraqi Café, not tied to a single game).
class CafeProgression {
  const CafeProgression._();

  static const int maxLevel = 50;
  static const int normalDailyMatchXpCap = 2000;
  static const int vipDailyMatchXpCap = 4000;

  static const int xpPerRoundWin = 10;
  static const int xpPerRoundLoss = 5;
  static const int xpPerMatchWin = 60;
  static const int xpPerMatchLoss = 20;

  static int dailyCapFor({required bool isVip, int extraDailyCapBonus = 0}) =>
      (isVip ? vipDailyMatchXpCap : normalDailyMatchXpCap) +
      max(0, extraDailyCapBonus);

  /// XP required to advance from [level] to `level + 1` (`1..49`).
  ///
  /// - Levels 1..9 (reaching 2..10): gentle curve (`80 .. 200 XP`) so new
  ///   players level up smoothly.
  /// - Levels 10..24: medium curve (`250 .. 810 XP`).
  /// - Levels 25..39: hard curve (`880 .. 1860 XP`).
  /// - Levels 40..49 (reaching 50): elite curve (`2000 .. 3080 XP`).
  static int xpForNextLevel(int level) {
    if (level >= maxLevel) return 0;
    if (level < 1) return 80;
    if (level <= 9) {
      return 80 + (level - 1) * 15;
    }
    if (level <= 24) {
      return 250 + (level - 10) * 40;
    }
    if (level <= 39) {
      return 880 + (level - 25) * 70;
    }
    return 2000 + (level - 40) * 120;
  }

  /// Resolves `(level, currentLevelXp, nextLevelXp, progress)` from cumulative
  /// [totalXp], capped at [maxLevel] (`50`).
  static ({
    int level,
    int currentLevelXp,
    int nextLevelXp,
    double progress,
  }) resolveLevel(int totalXp) {
    var remaining = max(0, totalXp);
    var level = 1;

    while (level < maxLevel) {
      final needed = xpForNextLevel(level);
      if (remaining < needed) {
        return (
          level: level,
          currentLevelXp: remaining,
          nextLevelXp: needed,
          progress: needed == 0 ? 1.0 : remaining / needed,
        );
      }
      remaining -= needed;
      level++;
    }

    return (
      level: maxLevel,
      currentLevelXp: 0,
      nextLevelXp: 0,
      progress: 1.0,
    );
  }

  /// Computes match XP earned from a completed match after applying the
  /// offline-AI zero rule, VIP / 2x-XP multiplier, and daily match XP cap.
  static ({int awardedXp, int rawUncappedXp, bool hitDailyCap}) computeMatchXp({
    required bool isOnlineMatch,
    required bool wonMatch,
    required int roundsWon,
    required int roundsLost,
    required int dailyMatchXpAlreadyEarned,
    required bool isVip,
    bool hasDoubleXpBooster = false,
    int extraDailyCapBonus = 0,
  }) {
    // No match XP against offline AI!
    if (!isOnlineMatch) {
      return (awardedXp: 0, rawUncappedXp: 0, hitDailyCap: false);
    }

    final baseXp = (roundsWon * xpPerRoundWin) +
        (roundsLost * xpPerRoundLoss) +
        (wonMatch ? xpPerMatchWin : xpPerMatchLoss);
    final multiplier = (isVip ? 2 : 1) * (hasDoubleXpBooster ? 2 : 1);
    final raw = baseXp * multiplier;

    final cap = dailyCapFor(
      isVip: isVip,
      extraDailyCapBonus: extraDailyCapBonus,
    );
    final availableToday = max(0, cap - dailyMatchXpAlreadyEarned);
    final awarded = min(raw, availableToday);

    return (
      awardedXp: awarded,
      rawUncappedXp: raw,
      hitDailyCap: awarded < raw,
    );
  }

  /// General Al-Maqha ("المقهى") title determined by the player's Leaderboard
  /// Rank and competitive Rating (general across all Café games).
  static String cafeTitleForRank({
    int? leaderboardRank,
    required int rating,
    required bool isAr,
  }) {
    if (leaderboardRank == 1 || rating >= 1750) {
      return isAr ? 'شيخ المقهى' : 'Sheikh of Al-Maqha';
    }
    if ((leaderboardRank != null && leaderboardRank <= 3) || rating >= 1500) {
      return isAr ? 'كبير المقهى' : 'Elder of Al-Maqha';
    }
    if ((leaderboardRank != null && leaderboardRank <= 10) || rating >= 1320) {
      return isAr ? 'أستاذ المجلس' : 'Grand Master';
    }
    if ((leaderboardRank != null && leaderboardRank <= 50) || rating >= 1180) {
      return isAr ? 'حريف المقهى' : 'Al-Maqha Maestro';
    }
    if (rating >= 1080) {
      return isAr ? 'صاحب مجلس' : 'Majlis Companion';
    }
    if (rating > 1000) {
      return isAr ? 'روّاد المقهى' : 'Al-Maqha Regular';
    }
    return isAr ? 'زبون جديد' : 'Newcomer';
  }

  /// Today's UTC/local calendar key (`YYYY-MM-DD`) used to reset the daily
  /// `2,000 XP` match cap at midnight.
  static String todayDateKey([DateTime? now]) {
    final dt = now ?? DateTime.now();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Per-game badge registry, graded from [BadgeDifficulty.easy] to
  /// [BadgeDifficulty.legendary]. New games in `GameCatalog` simply add their
  /// badge list under their `gameId`.
  static final List<GameBadgeDefinition> allBadges = [
    // -------------------------------------------------------------------------
    // Iraqi Domino ('iraqi_domino') — Easy (Bronze, +50 XP)
    // -------------------------------------------------------------------------
    GameBadgeDefinition(
      id: 'domino_first_win',
      gameId: 'iraqi_domino',
      difficulty: BadgeDifficulty.easy,
      titleAr: 'استفتاح الخير',
      titleEn: 'First Victory',
      descAr: 'اربح أول مباراة دومينو لك',
      descEn: 'Win your first Domino match',
      targetValue: 1,
      currentValueOf: (s) => s.matchesWon,
    ),
    GameBadgeDefinition(
      id: 'domino_first_block',
      gameId: 'iraqi_domino',
      difficulty: BadgeDifficulty.easy,
      titleAr: 'أول قفلة',
      titleEn: 'First Lock',
      descAr: 'اربح جولة واحدة عن طريق قفل الطاولة',
      descEn: 'Win 1 round by blocking the board',
      targetValue: 1,
      currentValueOf: (s) => s.blockedRoundWins,
    ),
    GameBadgeDefinition(
      id: 'domino_clean_hand_3',
      gameId: 'iraqi_domino',
      difficulty: BadgeDifficulty.easy,
      titleAr: 'يد نظيفة',
      titleEn: 'Clean Hand',
      descAr: 'اربح 3 جولات بتصفير يدك (دومينو)',
      descEn: 'Win 3 rounds by going Domino',
      targetValue: 3,
      currentValueOf: (s) => s.dominoRoundWins,
    ),

    // -------------------------------------------------------------------------
    // Iraqi Domino ('iraqi_domino') — Medium (Silver, +120 XP)
    // -------------------------------------------------------------------------
    GameBadgeDefinition(
      id: 'domino_streak_3',
      gameId: 'iraqi_domino',
      difficulty: BadgeDifficulty.medium,
      titleAr: 'سلسلة المقهى',
      titleEn: 'Hot Streak',
      descAr: 'حقق 3 انتصارات متتالية بدون خسارة',
      descEn: 'Win 3 matches in a row',
      targetValue: 3,
      currentValueOf: (s) => s.bestWinStreak,
    ),
    GameBadgeDefinition(
      id: 'domino_big_round_40',
      gameId: 'iraqi_domino',
      difficulty: BadgeDifficulty.medium,
      titleAr: 'صيّاد النقاط',
      titleEn: 'Point Hunter',
      descAr: 'سجّل 40 نقطة أو أكثر في جولة واحدة',
      descEn: 'Score 40+ points in a single round',
      targetValue: 40,
      currentValueOf: (s) => s.highestSingleRoundScore,
    ),
    GameBadgeDefinition(
      id: 'domino_block_master_10',
      gameId: 'iraqi_domino',
      difficulty: BadgeDifficulty.medium,
      titleAr: 'معلم القفلات',
      titleEn: 'Lock Tactician',
      descAr: 'اربح 10 جولات عن طريق قفل الطاولة',
      descEn: 'Win 10 rounds by blocking the board',
      targetValue: 10,
      currentValueOf: (s) => s.blockedRoundWins,
    ),

    // -------------------------------------------------------------------------
    // Iraqi Domino ('iraqi_domino') — Hard (Gold, +250 XP)
    // -------------------------------------------------------------------------
    GameBadgeDefinition(
      id: 'domino_streak_7',
      gameId: 'iraqi_domino',
      difficulty: BadgeDifficulty.hard,
      titleAr: 'لا يُقهر',
      titleEn: 'Unstoppable',
      descAr: 'حقق 7 انتصارات متتالية بدون خسارة',
      descEn: 'Win 7 matches in a row',
      targetValue: 7,
      currentValueOf: (s) => s.bestWinStreak,
    ),
    GameBadgeDefinition(
      id: 'domino_beat_expert',
      gameId: 'iraqi_domino',
      difficulty: BadgeDifficulty.hard,
      titleAr: 'قاهر الخبير',
      titleEn: 'Expert Slayer',
      descAr: 'اهزم مستوى الخبير في 5 مباريات',
      descEn: 'Win 5 matches at Expert difficulty',
      targetValue: 5,
      currentValueOf: (s) => s.expertAiWins,
    ),
    GameBadgeDefinition(
      id: 'domino_points_1500',
      gameId: 'iraqi_domino',
      difficulty: BadgeDifficulty.hard,
      titleAr: 'تاجر النقاط',
      titleEn: 'Score Tycoon',
      descAr: 'اجمع 1,500 نقطة إجمالية في الدومينو',
      descEn: 'Accumulate 1,500 total points in Domino',
      targetValue: 1500,
      currentValueOf: (s) => s.totalPointsScored,
    ),

    // -------------------------------------------------------------------------
    // Iraqi Domino ('iraqi_domino') — Legendary (Ruby, +500 XP)
    // -------------------------------------------------------------------------
    GameBadgeDefinition(
      id: 'domino_wins_50',
      gameId: 'iraqi_domino',
      difficulty: BadgeDifficulty.legendary,
      titleAr: 'أسطورة الدومينو',
      titleEn: 'Domino Legend',
      descAr: 'اربح 50 مباراة في الدومينو العراقي',
      descEn: 'Win 50 Iraqi Domino matches',
      targetValue: 50,
      currentValueOf: (s) => s.matchesWon,
    ),
    GameBadgeDefinition(
      id: 'domino_clean_sweep',
      gameId: 'iraqi_domino',
      difficulty: BadgeDifficulty.legendary,
      titleAr: 'اكتساح كامل',
      titleEn: 'Flawless Sweep',
      descAr: 'اربح مباراة كاملة دون أن يسجل الخصم أي نقطة (0)',
      descEn: 'Win a full match while holding the opponent to 0 points',
      targetValue: 1,
      currentValueOf: (s) => s.cleanSweepWins,
    ),
    GameBadgeDefinition(
      id: 'domino_domino_50',
      gameId: 'iraqi_domino',
      difficulty: BadgeDifficulty.legendary,
      titleAr: 'سيد الدوشيش',
      titleEn: 'Master of Dooshaysh',
      descAr: 'اربح 50 جولة بتصفير يدك (دومينو)',
      descEn: 'Win 50 rounds by going Domino',
      targetValue: 50,
      currentValueOf: (s) => s.dominoRoundWins,
    ),
  ];

  static List<GameBadgeDefinition> badgesForGame(String gameId) => [
    for (final b in allBadges)
      if (b.gameId == gameId) b,
  ];
}
