import 'dart:math';

import 'cafe_progression.dart';
import 'cafe_shop_catalog.dart';
import 'player_account.dart';

/// Seasonal, recurring, or sponsored visual theme for an Event in **المقهى**.
/// Pure Dart (zero Flutter imports).
enum EventThemeKind {
  ramadan('ramadan', 0xFF155D3B),
  eid('eid', 0xFF284A5E),
  national('national', 0xFF1D4F4B),
  monthly('monthly', 0xFF1A466B),
  sponsored('sponsored', 0xFF3E4B28),
  cafeNight('cafe_night', 0xFF17403E);

  const EventThemeKind(this.id, this.bannerHex);
  final String id;
  final int bannerHex;

  static EventThemeKind byId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return EventThemeKind.cafeNight;
  }

  String badgeLabel(bool isAr) => switch (this) {
    EventThemeKind.ramadan => isAr ? 'موسم رمضان' : 'Ramadan',
    EventThemeKind.eid => isAr ? 'مهرجان العيد' : 'Eid Fest',
    EventThemeKind.national => isAr ? 'مناسبة خاصة' : 'Special Event',
    EventThemeKind.monthly => isAr ? 'إيفنت دوري' : 'Periodic Event',
    EventThemeKind.sponsored => isAr ? 'برعاية رسمية' : 'Sponsored',
    EventThemeKind.cafeNight => isAr ? 'أمسية المقهى' : 'Café Night',
  };
}

/// Automatic rotation schedule for fixed recurring events. Pure Dart.
enum EventRecurrenceKind {
  once('once'),
  daily('daily'),
  weekly('weekly'),
  monthly('monthly');

  const EventRecurrenceKind(this.id);
  final String id;

  static EventRecurrenceKind byId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return EventRecurrenceKind.once;
  }

  String? badgeLabel(bool isAr) => switch (this) {
    EventRecurrenceKind.once => null,
    EventRecurrenceKind.daily => isAr ? 'يتجدد يومياً' : 'Daily',
    EventRecurrenceKind.weekly => isAr ? 'يتجدد أسبوعياً' : 'Weekly',
    EventRecurrenceKind.monthly => isAr ? 'يتجدد شهرياً' : 'Monthly',
  };

  /// Computes a deterministic period bucket from `YYYY-MM-DD` so recurring
  /// events automatically reset on each new day, week, or month!
  String periodKey([String? dateKey]) {
    final key = dateKey ?? CafeProgression.todayDateKey();
    switch (this) {
      case EventRecurrenceKind.once:
        return '';
      case EventRecurrenceKind.daily:
        return key;
      case EventRecurrenceKind.monthly:
        return key.length >= 7 ? key.substring(0, 7) : key;
      case EventRecurrenceKind.weekly:
        final dt = DateTime.tryParse(key) ?? DateTime.now();
        final dayOfYear =
            dt.difference(DateTime(dt.year, 1, 1)).inDays + 1;
        final week = ((dayOfYear - 1) ~/ 7) + 1;
        return '${dt.year}-W${week.toString().padLeft(2, '0')}';
    }
  }
}

/// Player statistic tracked by a [CafeEventDefinition]. Pure Dart.
enum EventMetricKind {
  matchesWon('matches_won'),
  matchesPlayed('matches_played'),
  roundsWon('rounds_won'),
  dominoWins('domino_wins'),
  blockedWins('blocked_wins'),
  tournamentsWon('tournaments_won');

  const EventMetricKind(this.id);
  final String id;

  static EventMetricKind byId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return EventMetricKind.matchesWon;
  }

  String labelAr() => switch (this) {
    EventMetricKind.matchesWon => 'الفوز بالمباريات',
    EventMetricKind.matchesPlayed => 'لعب المباريات',
    EventMetricKind.roundsWon => 'الفوز بالجولات',
    EventMetricKind.dominoWins => 'صكات الدومينو',
    EventMetricKind.blockedWins => 'الفوز بقفلة الطاولة',
    EventMetricKind.tournamentsWon => 'الفوز بالبطولات',
  };
}

/// Server-configurable Event supporting:
/// 1. Fixed Recurring Events (`daily`, `weekly`, `monthly`)
/// 2. Seasonal / Occasion Events (`Ramadan`, `Eid`, etc.)
/// 3. Custom Sponsored / Ad Events (`isSponsored`, `sponsorName`,
///    `bannerImageUrl` supporting URL or uploaded `data:image/...;base64,...`,
///    `sponsorCtaLabel`, and `sponsorUrl`).
/// Pure Dart.
class CafeEventDefinition {
  const CafeEventDefinition({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.descAr,
    required this.descEn,
    this.theme = EventThemeKind.cafeNight,
    this.recurrence = EventRecurrenceKind.once,
    this.metric = EventMetricKind.matchesWon,
    required this.targetValue,
    required this.rewardDinars,
    this.rewardBonusXp = 100,
    this.startDateIso = '',
    this.endDateIso = '',
    this.isSponsored = false,
    this.sponsorName = '',
    this.bannerImageUrl = '',
    this.sponsorCtaLabel = '',
    this.sponsorUrl = '',
    this.enabled = true,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String descAr;
  final String descEn;
  final EventThemeKind theme;
  final EventRecurrenceKind recurrence;
  final EventMetricKind metric;
  final int targetValue;

  /// Liquidity reward in **دينار المقهى**.
  final int rewardDinars;

  /// Bonus XP granted outside the daily 2,000 match XP cap.
  final int rewardBonusXp;

  /// Optional inclusive `YYYY-MM-DD` start/end window (`''` = open-ended).
  final String startDateIso;
  final String endDateIso;

  /// Sponsored / Branded Ad fields (custom sponsor name, image banner, & CTA).
  final bool isSponsored;
  final String sponsorName;
  final String bannerImageUrl;
  final String sponsorCtaLabel;
  final String sponsorUrl;

  final bool enabled;

  String title(bool isAr) => isAr ? titleAr : titleEn;
  String description(bool isAr) => isAr ? descAr : descEn;

  /// Period-aware claim key so recurring daily/weekly/monthly events can be
  /// claimed once per period and automatically unlock again in the next period.
  String claimKey([String? dateKey]) {
    if (recurrence == EventRecurrenceKind.once) return id;
    return '$id::${recurrence.periodKey(dateKey)}';
  }

  bool isClaimedBy(PlayerAccount account, [String? dateKey]) =>
      account.claimedEventIds.contains(claimKey(dateKey));

  /// Checks whether this event is live on [dateKey] (`YYYY-MM-DD`).
  bool isActiveOn([String? dateKey]) {
    if (!enabled) return false;
    final key = dateKey ?? CafeProgression.todayDateKey();
    if (startDateIso.isNotEmpty && key.compareTo(startDateIso) < 0) {
      return false;
    }
    if (endDateIso.isNotEmpty && key.compareTo(endDateIso) > 0) {
      return false;
    }
    return true;
  }

  int rawProgressOf(PlayerAccount account) => switch (metric) {
    EventMetricKind.matchesWon => account.stats.matchesWon,
    EventMetricKind.matchesPlayed => account.stats.matchesPlayed,
    EventMetricKind.roundsWon => account.stats.roundsWon,
    EventMetricKind.dominoWins => account.stats.dominoRoundWins,
    EventMetricKind.blockedWins => account.stats.blockedRoundWins,
    EventMetricKind.tournamentsWon => account.tournamentsWon,
  };

  /// Progress within the current recurrence period (for `once` events, total
  /// progress; for `daily`/`weekly`/`monthly`, progress earned since the last
  /// claimed baseline!).
  int periodProgressOf(PlayerAccount account, [String? dateKey]) {
    if (isClaimedBy(account, dateKey)) return max(1, targetValue);
    final raw = rawProgressOf(account);
    if (recurrence == EventRecurrenceKind.once) return max(0, raw);
    final base = account.eventProgressBaselines[id] ?? 0;
    return max(0, raw - base);
  }

  int clampedProgressOf(PlayerAccount account, [String? dateKey]) =>
      min(max(1, targetValue), periodProgressOf(account, dateKey));

  bool isCompletedBy(PlayerAccount account, [String? dateKey]) =>
      periodProgressOf(account, dateKey) >= max(1, targetValue);

  Map<String, Object?> toJson() => {
    'id': id,
    'titleAr': titleAr,
    'titleEn': titleEn,
    'descAr': descAr,
    'descEn': descEn,
    'theme': theme.id,
    'recurrence': recurrence.id,
    'metric': metric.id,
    'targetValue': targetValue,
    'rewardDinars': rewardDinars,
    'rewardBonusXp': rewardBonusXp,
    'startDateIso': startDateIso,
    'endDateIso': endDateIso,
    'isSponsored': isSponsored,
    'sponsorName': sponsorName,
    'bannerImageUrl': bannerImageUrl,
    'sponsorCtaLabel': sponsorCtaLabel,
    'sponsorUrl': sponsorUrl,
    'enabled': enabled,
  };

  factory CafeEventDefinition.fromJson(Map<String, Object?> json) {
    final sponsor = (json['sponsorName'] as String?)?.trim() ?? '';
    final img = (json['bannerImageUrl'] as String?)?.trim() ?? '';
    return CafeEventDefinition(
      id: (json['id'] as String?)?.trim() ?? 'ev_custom',
      titleAr: (json['titleAr'] as String?)?.trim() ?? 'إيفنت المقهى',
      titleEn: (json['titleEn'] as String?)?.trim() ?? 'Al-Maqha Event',
      descAr: (json['descAr'] as String?)?.trim() ?? '',
      descEn: (json['descEn'] as String?)?.trim() ?? '',
      theme: EventThemeKind.byId(json['theme'] as String?),
      recurrence: EventRecurrenceKind.byId(json['recurrence'] as String?),
      metric: EventMetricKind.byId(json['metric'] as String?),
      targetValue: max(1, (json['targetValue'] as num?)?.toInt() ?? 3),
      rewardDinars: max(0, (json['rewardDinars'] as num?)?.toInt() ?? 100),
      rewardBonusXp: max(0, (json['rewardBonusXp'] as num?)?.toInt() ?? 100),
      startDateIso: (json['startDateIso'] as String?)?.trim() ?? '',
      endDateIso: (json['endDateIso'] as String?)?.trim() ?? '',
      isSponsored:
          (json['isSponsored'] as bool?) ??
          (sponsor.isNotEmpty || img.isNotEmpty),
      sponsorName: sponsor,
      bannerImageUrl: img,
      sponsorCtaLabel: (json['sponsorCtaLabel'] as String?)?.trim() ?? '',
      sponsorUrl: (json['sponsorUrl'] as String?)?.trim() ?? '',
      enabled: (json['enabled'] as bool?) ?? true,
    );
  }
}

/// Server-configurable Tournament tier in **المقهى** (daily free cup or staked
/// Dinar cup with a 10% Café house commission). Pure Dart.
class CafeTournamentTier {
  const CafeTournamentTier({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.descAr,
    required this.descEn,
    this.isDailyFree = false,
    required this.entryFeeDinars,
    this.playerCount = 4,
    this.targetScore = 151,
    this.aiDifficultyId = 'hard',
    this.fixedPrizeDinars,
    this.bonusXpForWinner = 120,
    this.enabled = true,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String descAr;
  final String descEn;
  final bool isDailyFree;
  final int entryFeeDinars;
  final int playerCount;
  final int targetScore;
  final String aiDifficultyId;

  /// Used for free-entry tournaments (e.g. `100` Dinars). When `null`, prize is
  /// `(entryFeeDinars * playerCount) * 90%` (`10%` Café rake).
  final int? fixedPrizeDinars;
  final int bonusXpForWinner;
  final bool enabled;

  String title(bool isAr) => isAr ? titleAr : titleEn;
  String description(bool isAr) => isAr ? descAr : descEn;

  int get grossPoolDinars => max(0, entryFeeDinars * playerCount);

  /// Net prize won by 1st place (`500 × 4 = 2000` -> `1800` Dinars).
  int get netPrizeDinars =>
      fixedPrizeDinars ??
      CafeShopCatalog.calculateTournamentPrizePool(
        entryFeeDinars: entryFeeDinars,
        playerCount: playerCount,
      );

  /// House commission (`10%`) removed from circulation.
  int get rakeDeductedDinars =>
      isDailyFree ? 0 : max(0, grossPoolDinars - netPrizeDinars);

  Map<String, Object?> toJson() => {
    'id': id,
    'titleAr': titleAr,
    'titleEn': titleEn,
    'descAr': descAr,
    'descEn': descEn,
    'isDailyFree': isDailyFree,
    'entryFeeDinars': entryFeeDinars,
    'playerCount': playerCount,
    'targetScore': targetScore,
    'aiDifficultyId': aiDifficultyId,
    'fixedPrizeDinars': fixedPrizeDinars,
    'bonusXpForWinner': bonusXpForWinner,
    'enabled': enabled,
  };

  factory CafeTournamentTier.fromJson(Map<String, Object?> json) {
    final rawPc = (json['playerCount'] as num?)?.toInt() ?? 4;
    return CafeTournamentTier(
      id: (json['id'] as String?)?.trim() ?? 'cup_custom',
      titleAr: (json['titleAr'] as String?)?.trim() ?? 'بطولة المقهى',
      titleEn: (json['titleEn'] as String?)?.trim() ?? 'Al-Maqha Cup',
      descAr: (json['descAr'] as String?)?.trim() ?? '',
      descEn: (json['descEn'] as String?)?.trim() ?? '',
      isDailyFree: (json['isDailyFree'] as bool?) ?? false,
      entryFeeDinars: max(0, (json['entryFeeDinars'] as num?)?.toInt() ?? 100),
      playerCount: rawPc == 2 ? 2 : 4,
      targetScore: max(51, (json['targetScore'] as num?)?.toInt() ?? 151),
      aiDifficultyId: (json['aiDifficultyId'] as String?) ?? 'hard',
      fixedPrizeDinars: (json['fixedPrizeDinars'] as num?)?.toInt(),
      bonusXpForWinner: max(
        0,
        (json['bonusXpForWinner'] as num?)?.toInt() ?? 100,
      ),
      enabled: (json['enabled'] as bool?) ?? true,
    );
  }
}

/// Entry outcome when joining a Tournament. Pure Dart.
enum TournamentEntryStatus {
  enteredFreeDaily,
  enteredWithTicket,
  enteredPaid,
  dailyFreeAlreadyUsed,
  insufficientDinars,
  tournamentDisabled,
}

/// Default Tournaments & Fixed Recurring / Seasonal Events seeded on the Server.
class CafeLiveOpsDefaults {
  const CafeLiveOpsDefaults._();

  static const List<CafeTournamentTier> tournaments = [
    CafeTournamentTier(
      id: 'cup_daily_free',
      titleAr: 'البطولة اليومية المجانية',
      titleEn: 'Daily Free Cup',
      descAr: 'دخول مجاني يومي أو بتذكرة',
      descEn: 'One free daily entry or ticket',
      isDailyFree: true,
      entryFeeDinars: 0,
      playerCount: 4,
      targetScore: 151,
      aiDifficultyId: 'medium',
      fixedPrizeDinars: 100,
      bonusXpForWinner: 80,
    ),
    CafeTournamentTier(
      id: 'cup_regulars_100',
      titleAr: 'بطولة روّاد المقهى',
      titleEn: 'Regulars Cup',
      descAr: '4 لاعبين • مجموع 400 د',
      descEn: '4 players • 400 D pool',
      entryFeeDinars: 100,
      playerCount: 4,
      targetScore: 151,
      aiDifficultyId: 'medium',
      bonusXpForWinner: 110,
    ),
    CafeTournamentTier(
      id: 'cup_duel_300',
      titleAr: 'تحدي راس براس',
      titleEn: 'Head-to-Head Duel',
      descAr: 'لاعبان (1 ضد 1) • الصافي 540 د',
      descEn: '2 players (1v1) • 540 D net',
      entryFeeDinars: 300,
      playerCount: 2,
      targetScore: 151,
      aiDifficultyId: 'hard',
      bonusXpForWinner: 130,
    ),
    CafeTournamentTier(
      id: 'cup_maestros_500',
      titleAr: 'بطولة حريفة المقهى',
      titleEn: 'Maestros Cup',
      descAr: '4 لاعبين • الصافي 1,800 د',
      descEn: '4 players • 1,800 D net',
      entryFeeDinars: 500,
      playerCount: 4,
      targetScore: 151,
      aiDifficultyId: 'hard',
      bonusXpForWinner: 180,
    ),
    CafeTournamentTier(
      id: 'cup_masters_2500',
      titleAr: 'بطولة أساتذة المجلس',
      titleEn: 'Grand Masters Cup',
      descAr: '4 لاعبين • الصافي 9,000 د',
      descEn: '4 players • 9,000 D net',
      entryFeeDinars: 2500,
      playerCount: 4,
      targetScore: 200,
      aiDifficultyId: 'expert',
      bonusXpForWinner: 260,
    ),
    CafeTournamentTier(
      id: 'cup_sheikhs_10000',
      titleAr: 'بطولة مجلس الشيوخ الكبرى',
      titleEn: 'Council of Sheikhs Cup',
      descAr: '4 لاعبين • الصافي 36,000 د',
      descEn: '4 players • 36,000 D net',
      entryFeeDinars: 10000,
      playerCount: 4,
      targetScore: 200,
      aiDifficultyId: 'expert',
      bonusXpForWinner: 400,
    ),
  ];

  static const List<CafeEventDefinition> events = [
    // 1. Fixed Daily Recurring Event
    CafeEventDefinition(
      id: 'ev_daily_warmup',
      titleAr: 'مهمة المقهى اليومية',
      titleEn: 'Daily Warmup',
      descAr: 'اربح مباراتين اليوم',
      descEn: 'Win 2 matches today',
      theme: EventThemeKind.cafeNight,
      recurrence: EventRecurrenceKind.daily,
      metric: EventMetricKind.matchesWon,
      targetValue: 2,
      rewardDinars: 65,
      rewardBonusXp: 75,
    ),
    // 2. Fixed Weekly Recurring Event
    CafeEventDefinition(
      id: 'ev_weekly_locks',
      titleAr: 'مهمة القفلات الأسبوعية',
      titleEn: 'Weekly Lock Masters',
      descAr: 'اربح 4 جولات بقفل الطاولة',
      descEn: 'Win 4 blocked rounds',
      theme: EventThemeKind.national,
      recurrence: EventRecurrenceKind.weekly,
      metric: EventMetricKind.blockedWins,
      targetValue: 4,
      rewardDinars: 180,
      rewardBonusXp: 160,
    ),
    // 3. Fixed Monthly Recurring Event
    CafeEventDefinition(
      id: 'ev_monthly_challenge',
      titleAr: 'تحدي المقهى الشهري',
      titleEn: 'Monthly Challenge',
      descAr: 'اربح 15 جولة هذا الشهر',
      descEn: 'Win 15 rounds this month',
      theme: EventThemeKind.monthly,
      recurrence: EventRecurrenceKind.monthly,
      metric: EventMetricKind.roundsWon,
      targetValue: 15,
      rewardDinars: 300,
      rewardBonusXp: 240,
    ),
    // 4. Pre-seeded Ramadan Event (ready to enable from /admin)
    CafeEventDefinition(
      id: 'ev_ramadan_majlis',
      titleAr: 'أمسيات رمضان في المقهى',
      titleEn: 'Ramadan Nights',
      descAr: 'اربح 5 مباريات خلال الموسم',
      descEn: 'Win 5 matches this season',
      theme: EventThemeKind.ramadan,
      recurrence: EventRecurrenceKind.once,
      metric: EventMetricKind.matchesWon,
      targetValue: 5,
      rewardDinars: 450,
      rewardBonusXp: 300,
      enabled: false,
    ),
  ];
}
