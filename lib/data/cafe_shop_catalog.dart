import 'dart:math';

/// Top-level sections in the "المقهى" (`Al-Maqha`) Shop. Pure Dart.
enum ShopCategory {
  tables('tables'),
  frames('frames'),
  gamePieces('game_pieces'),
  cafeProps('cafe_props'),
  boosters('boosters'),
  vip('vip');

  const ShopCategory(this.id);
  final String id;

  String label(bool isAr) => switch (this) {
    ShopCategory.tables => isAr ? 'الطاولات والأعلام' : 'Tables & Flags',
    ShopCategory.frames => isAr ? 'إطارات الصور' : 'Avatar Frames',
    ShopCategory.gamePieces => isAr ? 'أحجار الألعاب' : 'Game Pieces',
    ShopCategory.cafeProps => isAr ? 'مقتنيات المقهى' : 'Café Props',
    ShopCategory.boosters => isAr ? 'المعززات' : 'Boosters',
    ShopCategory.vip => isAr ? 'مجلس الشيوخ VIP' : 'Sheikh VIP',
  };
}

/// Visual rarity tier for shop items. Pure Dart.
enum ItemRarity {
  classic('classic', 0xFFCD8B5B),
  rare('rare', 0xFF4FC3F7),
  royal('royal', 0xFFD4AF37),
  legendary('legendary', 0xFFE53935);

  const ItemRarity(this.id, this.colorHex);
  final String id;
  final int colorHex;

  String label(bool isAr) => switch (this) {
    ItemRarity.classic => isAr ? 'كلاسيكي' : 'Classic',
    ItemRarity.rare => isAr ? 'نادر' : 'Rare',
    ItemRarity.royal => isAr ? 'ملكي' : 'Royal',
    ItemRarity.legendary => isAr ? 'أسطوري' : 'Legendary',
  };
}

/// Rental vs permanent ownership duration options in the Shop. Pure Dart.
enum PurchaseDuration {
  days3('days_3', days: 3),
  days7('days_7', days: 7),
  permanent('permanent', days: 0);

  const PurchaseDuration(this.id, {required this.days});
  final String id;
  final int days;

  bool get isRental => days > 0;

  String label(bool isAr) => switch (this) {
    PurchaseDuration.days3 => isAr ? '3 أيام' : '3 Days',
    PurchaseDuration.days7 => isAr ? 'أسبوع' : '7 Days',
    PurchaseDuration.permanent => isAr ? 'دائم' : 'Permanent',
  };
}

/// Behavioral type of a catalog entry. Pure Dart.
enum ShopItemKind {
  /// Cosmetic item that can be rented (3d / 7d) or bought permanently and equipped.
  equippable,

  /// Instant-effect utility booster (e.g., 2x XP, Rating Shield, Daily Cap +1000).
  consumableBooster,

  /// Time-based membership in "مجلس شيوخ المقهى" (VIP).
  vipMembership,
}

/// Outcome returned when attempting a Shop purchase. Pure Dart.
enum ShopPurchaseStatus {
  success,
  insufficientDinars,
  alreadyOwnedPermanently,
  gameNotAvailableYet,
  itemNotFound,
}

/// Pure-Dart definition of a single item in the "المقهى" Shop.
class ShopItemDefinition {
  const ShopItemDefinition({
    required this.id,
    required this.category,
    required this.kind,
    required this.rarity,
    required this.titleAr,
    required this.titleEn,
    required this.descAr,
    required this.descEn,
    this.gameId,
    this.assetSkinId,
    this.isDefaultFree = false,
    this.requiresFutureGame = false,
    this.price3Days,
    this.price7Days,
    this.pricePermanent,
    this.singlePrice,
    this.durationDays = 0,
  });

  final String id;
  final ShopCategory category;
  final ShopItemKind kind;
  final ItemRarity rarity;
  final String titleAr;
  final String titleEn;
  final String descAr;
  final String descEn;

  /// Optional game scope (`'iraqi_domino'`, `'backgammon'`, `'cards'`) for
  /// [ShopCategory.gamePieces].
  final String? gameId;

  /// Underlying rendering skin ID when different from [id] (e.g. `'ivory'` for
  /// `'tile_ivory'`). Defaults to [id] when null.
  final String? assetSkinId;

  final bool isDefaultFree;
  final bool requiresFutureGame;

  final int? price3Days;
  final int? price7Days;
  final int? pricePermanent;

  /// Single activation price for [ShopItemKind.consumableBooster] and
  /// [ShopItemKind.vipMembership].
  final int? singlePrice;

  /// Duration in days for time-based boosters / VIP memberships.
  final int durationDays;

  String get effectiveAssetId => assetSkinId ?? id;

  String title(bool isAr) => isAr ? titleAr : titleEn;
  String description(bool isAr) => isAr ? descAr : descEn;

  /// Computes the price in **دينار المقهى** (`Café Dinars`), applying the 15%
  /// `مجلس شيوخ المقهى (VIP)` discount on non-VIP items when [isVipActive] is true.
  int? priceFor(PurchaseDuration duration, {bool isVipActive = false}) {
    if (isDefaultFree) return 0;

    int? raw;
    if (kind == ShopItemKind.equippable) {
      raw = switch (duration) {
        PurchaseDuration.days3 => price3Days,
        PurchaseDuration.days7 => price7Days,
        PurchaseDuration.permanent => pricePermanent,
      };
    } else {
      raw = singlePrice;
    }

    if (raw == null) return null;
    if (isVipActive && kind != ShopItemKind.vipMembership) {
      return max(1, (raw * 0.85).round());
    }
    return raw;
  }
}

/// Central pure-Dart economy & shop catalog for **المقهى** (`Al-Maqha`):
/// - Single high-value currency: **دينار المقهى** (`Café Dinar`).
/// - **0 Dinars** from regular matches (Online or Offline).
/// - Earned strictly via Tournaments (including a daily free-entry tournament +
///   staked tournaments with a **10% Café rake**, e.g. `500 × 4 = 2000 -> 1800`)
///   and limited-time Events.
/// - Rental (`3 Days`, `7 Days`) & high-prestige `Permanent` ownership.
class CafeShopCatalog {
  const CafeShopCatalog._();

  /// Initial welcome balance granted once to a newly created profile.
  static const int starterWelcomeDinars = 250;

  /// Café house commission (`10%`) deducted from staked tournament pools to
  /// prevent currency inflation (`500 × 4 = 2,000` -> `1,800` prize pool).
  static const double tournamentRakeRate = 0.10;

  /// VIP discount (`15%`) applied across Shop categories for members of
  /// **مجلس شيوخ المقهى**.
  static const double vipShopDiscountRate = 0.15;

  /// Computes the net tournament prize pool after deducting the 10% Café rake.
  static int calculateTournamentPrizePool({
    required int entryFeeDinars,
    required int playerCount,
  }) {
    if (entryFeeDinars <= 0 || playerCount <= 0) return 0;
    final gross = entryFeeDinars * playerCount;
    final rake = (gross * tournamentRakeRate).round();
    return max(0, gross - rake);
  }

  /// Default starter items unlocked permanently for every player.
  static const Set<String> defaultFreeItemIds = {
    'table_classic_green',
    'frame_none',
    'tile_ivory',
    'prop_estekan_tea',
  };

  /// Interactive luxury table expressions unlocked by `'chat_sheikh_pack'`.
  static const List<({String ar, String en})> sheikhQuickPhrases = [
    (ar: 'دومينو يا غالي', en: 'Domino, my friend'),
    (ar: 'قفلنا المجلس', en: 'Table locked'),
    (ar: 'استكان جاي للشباب', en: 'Cardamom tea for everyone'),
    (ar: 'لعبة معلم', en: 'Masterful move'),
    (ar: 'حي الله شيوخ المقهى', en: 'Salute to the Sheikhs'),
  ];

  static final List<ShopItemDefinition> items = [
    // =========================================================================
    // 1. TABLES: Cloths, Ornaments & Country Flags ('tables')
    // =========================================================================
    const ShopItemDefinition(
      id: 'table_classic_green',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.classic,
      isDefaultFree: true,
      titleAr: 'الجوخ الأخضر الكلاسيكي',
      titleEn: 'Classic Green Baize',
      descAr: 'طاولة المقهى الافتراضية',
      descEn: 'Default emerald café table',
    ),
    const ShopItemDefinition(
      id: 'table_royal_crimson',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.rare,
      titleAr: 'المخمل العنابي الملكي',
      titleEn: 'Royal Crimson Velvet',
      descAr: 'مخمل عنابي بإطار مذهّب',
      descEn: 'Crimson velvet with gold inlay',
      price3Days: 450,
      price7Days: 850,
      pricePermanent: 4800,
    ),
    const ShopItemDefinition(
      id: 'table_damascus_blue',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.rare,
      titleAr: 'الأزرق الدمشقي المزخرف',
      titleEn: 'Damascus Azure Cloth',
      descAr: 'قماش كحلي بنجمة هندسية',
      descEn: 'Midnight azure geometric star',
      price3Days: 500,
      price7Days: 950,
      pricePermanent: 5400,
    ),
    const ShopItemDefinition(
      id: 'table_heritage_carpet',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'طاولة الديوان التراثي',
      titleEn: 'Heritage Diwan Carpet',
      descAr: 'نقشة سجاد شرقي منسوج',
      descEn: 'Woven oriental carpet pattern',
      price3Days: 700,
      price7Days: 1350,
      pricePermanent: 7800,
    ),
    const ShopItemDefinition(
      id: 'table_abbasid_mosaic',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'الفسيفساء المذهّبة',
      titleEn: 'Gilded Arabesque Mosaic',
      descAr: 'سطح فيروزي بزخارف ذهبية',
      descEn: 'Deep teal with gilded mosaic',
      price3Days: 900,
      price7Days: 1750,
      pricePermanent: 10500,
    ),
    const ShopItemDefinition(
      id: 'table_obsidian_gold',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.legendary,
      titleAr: 'الرخام الأسود الملكي',
      titleEn: 'Obsidian & Gold Marble',
      descAr: 'رخام أسود معرّق بالذهب',
      descEn: 'Black obsidian veined with gold',
      price3Days: 1250,
      price7Days: 2400,
      pricePermanent: 15000,
    ),

    // Country Flag Tables
    const ShopItemDefinition(
      id: 'table_flag_iraq',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'طاولة علم العراق',
      titleEn: 'Iraq Flag Table',
      descAr: 'راية العراق بإطار مذهّب',
      descEn: 'Iraq flag woven table',
      price3Days: 650,
      price7Days: 1250,
      pricePermanent: 7200,
    ),
    const ShopItemDefinition(
      id: 'table_flag_saudi',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'طاولة علم السعودية',
      titleEn: 'Saudi Arabia Flag Table',
      descAr: 'راية السعودية بإطار مذهّب',
      descEn: 'Saudi flag woven table',
      price3Days: 650,
      price7Days: 1250,
      pricePermanent: 7200,
    ),
    const ShopItemDefinition(
      id: 'table_flag_kuwait',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'طاولة علم الكويت',
      titleEn: 'Kuwait Flag Table',
      descAr: 'راية الكويت بإطار مذهّب',
      descEn: 'Kuwait flag woven table',
      price3Days: 650,
      price7Days: 1250,
      pricePermanent: 7200,
    ),
    const ShopItemDefinition(
      id: 'table_flag_uae',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'طاولة علم الإمارات',
      titleEn: 'UAE Flag Table',
      descAr: 'راية الإمارات بإطار مذهّب',
      descEn: 'UAE flag woven table',
      price3Days: 650,
      price7Days: 1250,
      pricePermanent: 7200,
    ),
    const ShopItemDefinition(
      id: 'table_flag_qatar',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'طاولة علم قطر',
      titleEn: 'Qatar Flag Table',
      descAr: 'راية قطر بإطار مذهّب',
      descEn: 'Qatar flag woven table',
      price3Days: 650,
      price7Days: 1250,
      pricePermanent: 7200,
    ),
    const ShopItemDefinition(
      id: 'table_flag_jordan',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'طاولة علم الأردن',
      titleEn: 'Jordan Flag Table',
      descAr: 'راية الأردن بإطار مذهّب',
      descEn: 'Jordan flag woven table',
      price3Days: 650,
      price7Days: 1250,
      pricePermanent: 7200,
    ),
    const ShopItemDefinition(
      id: 'table_flag_egypt',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'طاولة علم مصر',
      titleEn: 'Egypt Flag Table',
      descAr: 'راية مصر بإطار مذهّب',
      descEn: 'Egypt flag woven table',
      price3Days: 650,
      price7Days: 1250,
      pricePermanent: 7200,
    ),
    const ShopItemDefinition(
      id: 'table_flag_palestine',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'طاولة علم فلسطين',
      titleEn: 'Palestine Flag Table',
      descAr: 'راية فلسطين بإطار مذهّب',
      descEn: 'Palestine flag woven table',
      price3Days: 650,
      price7Days: 1250,
      pricePermanent: 7200,
    ),
    const ShopItemDefinition(
      id: 'table_flag_syria',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'طاولة علم سوريا',
      titleEn: 'Syria Flag Table',
      descAr: 'راية سوريا بإطار مذهّب',
      descEn: 'Syria flag woven table',
      price3Days: 650,
      price7Days: 1250,
      pricePermanent: 7200,
    ),
    const ShopItemDefinition(
      id: 'table_flag_turkey',
      category: ShopCategory.tables,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'طاولة علم تركيا',
      titleEn: 'Turkey Flag Table',
      descAr: 'راية تركيا بإطار مذهّب',
      descEn: 'Turkey flag woven table',
      price3Days: 650,
      price7Days: 1250,
      pricePermanent: 7200,
    ),

    // =========================================================================
    // 2. AVATAR FRAMES ('frames')
    // =========================================================================
    const ShopItemDefinition(
      id: 'frame_none',
      category: ShopCategory.frames,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.classic,
      isDefaultFree: true,
      titleAr: 'الإطار الافتراضي',
      titleEn: 'Default Ring',
      descAr: 'إطار الصورة الأساسي',
      descEn: 'Standard portrait ring',
    ),
    const ShopItemDefinition(
      id: 'frame_silver_engraved',
      category: ShopCategory.frames,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.rare,
      titleAr: 'إطار الفضة المنقوش',
      titleEn: 'Engraved Silver Frame',
      descAr: 'حلقة فضية بنقوش هندسية',
      descEn: 'Polished silver ring',
      price3Days: 350,
      price7Days: 650,
      pricePermanent: 3800,
    ),
    const ShopItemDefinition(
      id: 'frame_iraq_pride',
      category: ShopCategory.frames,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'إطار البيرق الثلاثي',
      titleEn: 'Tricolor Pride Frame',
      descAr: 'تدرج ثلاثي بنجوم زمردية',
      descEn: 'Tricolor heritage ring',
      price3Days: 550,
      price7Days: 1050,
      pricePermanent: 6000,
    ),
    const ShopItemDefinition(
      id: 'frame_royal_gold',
      category: ShopCategory.frames,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'إطار الذهب الملكي',
      titleEn: 'Royal Gold Crown Frame',
      descAr: 'حلقة ذهبية متوّجة',
      descEn: 'Gold ring with royal crest',
      price3Days: 650,
      price7Days: 1200,
      pricePermanent: 6800,
    ),
    const ShopItemDefinition(
      id: 'frame_amber_fire',
      category: ShopCategory.frames,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'إطار الكهرب المتوهج',
      titleEn: 'Glowing Amber Frame',
      descAr: 'فصوص كهرب كهرمانية',
      descEn: 'Warm amber portrait ring',
      price3Days: 850,
      price7Days: 1600,
      pricePermanent: 9500,
    ),
    const ShopItemDefinition(
      id: 'frame_emerald_sultan',
      category: ShopCategory.frames,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'إطار الزمرد السلطاني',
      titleEn: 'Sultan Emerald Frame',
      descAr: 'زمرد أخضر بفصوص ذهبية',
      descEn: 'Emerald ring with gold gems',
      price3Days: 1000,
      price7Days: 1900,
      pricePermanent: 11500,
    ),
    const ShopItemDefinition(
      id: 'frame_diamond_sheikh',
      category: ShopCategory.frames,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.legendary,
      titleAr: 'إطار ألماس الشيوخ',
      titleEn: 'Sheikh Diamond Halo',
      descAr: 'هالة ألماسية بتاج ذهبي',
      descEn: 'Diamond halo with Sheikh crown',
      price3Days: 1600,
      price7Days: 3000,
      pricePermanent: 18500,
    ),

    // =========================================================================
    // 3. GAME PIECES: Domino Stones & Future Café Games ('game_pieces')
    // =========================================================================
    const ShopItemDefinition(
      id: 'tile_ivory',
      category: ShopCategory.gamePieces,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.classic,
      gameId: 'iraqi_domino',
      assetSkinId: 'ivory',
      isDefaultFree: true,
      titleAr: 'حجر العاج الكلاسيكي',
      titleEn: 'Classic Ivory Stone',
      descAr: 'أحجار عاجية تقليدية',
      descEn: 'Classic ivory domino stones',
    ),
    const ShopItemDefinition(
      id: 'tile_ebony',
      category: ShopCategory.gamePieces,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.rare,
      gameId: 'iraqi_domino',
      assetSkinId: 'ebony',
      titleAr: 'حجر الأبنوس الأسود',
      titleEn: 'Black Ebony Stone',
      descAr: 'أحجار سوداء بنقاط عاجية',
      descEn: 'Dark ebony stones with ivory pips',
      price3Days: 450,
      price7Days: 850,
      pricePermanent: 4800,
    ),
    const ShopItemDefinition(
      id: 'tile_ruby',
      category: ShopCategory.gamePieces,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.rare,
      gameId: 'iraqi_domino',
      assetSkinId: 'ruby',
      titleAr: 'حجر الياقوت الأحمر',
      titleEn: 'Crimson Ruby Stone',
      descAr: 'أحجار ياقوتية عنابية',
      descEn: 'Crimson ruby stones',
      price3Days: 550,
      price7Days: 1050,
      pricePermanent: 5800,
    ),
    const ShopItemDefinition(
      id: 'tile_amber',
      category: ShopCategory.gamePieces,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      gameId: 'iraqi_domino',
      assetSkinId: 'amber',
      titleAr: 'حجر الكهرب الكهرماني',
      titleEn: 'Golden Amber Stone',
      descAr: 'لون الكهرب العسلي الأصيل',
      descEn: 'Honey-gold amber stones',
      price3Days: 750,
      price7Days: 1400,
      pricePermanent: 8200,
    ),
    const ShopItemDefinition(
      id: 'tile_turquoise',
      category: ShopCategory.gamePieces,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      gameId: 'iraqi_domino',
      assetSkinId: 'turquoise',
      titleAr: 'حجر الفيروز الشرقي',
      titleEn: 'Oriental Turquoise Stone',
      descAr: 'فيروز شرقي بلمسة ذهبية',
      descEn: 'Turquoise stones with gold trim',
      price3Days: 850,
      price7Days: 1600,
      pricePermanent: 9200,
    ),
    const ShopItemDefinition(
      id: 'tile_pearl',
      category: ShopCategory.gamePieces,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      gameId: 'iraqi_domino',
      assetSkinId: 'pearl',
      titleAr: 'حجر الصدف الدمشقي',
      titleEn: 'Mother of Pearl Stone',
      descAr: 'صدف ناصع بنقاط كحلية',
      descEn: 'Lustrous pearl stones',
      price3Days: 1050,
      price7Days: 2000,
      pricePermanent: 12000,
    ),
    const ShopItemDefinition(
      id: 'tile_royal_emerald',
      category: ShopCategory.gamePieces,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.legendary,
      gameId: 'iraqi_domino',
      assetSkinId: 'royal_emerald',
      titleAr: 'حجر الزمرد والذهب',
      titleEn: 'Emerald & Gold Stone',
      descAr: 'زمرد داكن بنقاط ذهبية',
      descEn: 'Deep emerald with gold pips',
      price3Days: 1500,
      price7Days: 2850,
      pricePermanent: 17500,
    ),

    // Future Café Games Pieces (Backgammon & Cards — ready for multi-game catalog)
    const ShopItemDefinition(
      id: 'bg_walnut_pearl',
      category: ShopCategory.gamePieces,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      gameId: 'backgammon',
      requiresFutureGame: true,
      titleAr: 'أقراص الجوز والصدف',
      titleEn: 'Walnut & Pearl Checkers',
      descAr: 'لطاولة الزهر — يتوفر قريباً',
      descEn: 'For Backgammon — coming soon',
      price3Days: 600,
      price7Days: 1150,
      pricePermanent: 6500,
    ),
    const ShopItemDefinition(
      id: 'bg_amber_gold',
      category: ShopCategory.gamePieces,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.legendary,
      gameId: 'backgammon',
      requiresFutureGame: true,
      titleAr: 'أقراص الكهرب ونرد الذهب',
      titleEn: 'Amber Checkers & Gold Dice',
      descAr: 'لطاولة الزهر — يتوفر قريباً',
      descEn: 'For Backgammon — coming soon',
      price3Days: 1200,
      price7Days: 2250,
      pricePermanent: 13500,
    ),
    const ShopItemDefinition(
      id: 'cards_arabesque_gold',
      category: ShopCategory.gamePieces,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      gameId: 'cards',
      requiresFutureGame: true,
      titleAr: 'ورق الزخرفة المذهّبة',
      titleEn: 'Gilded Arabesque Deck',
      descAr: 'لألعاب الورق — يتوفر قريباً',
      descEn: 'For Card Games — coming soon',
      price3Days: 550,
      price7Days: 1050,
      pricePermanent: 5800,
    ),
    const ShopItemDefinition(
      id: 'cards_sheikh_obsidian',
      category: ShopCategory.gamePieces,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.legendary,
      gameId: 'cards',
      requiresFutureGame: true,
      titleAr: 'شدة الشيوخ السوداء',
      titleEn: 'Sheikh Obsidian Deck',
      descAr: 'لألعاب الورق — يتوفر قريباً',
      descEn: 'For Card Games — coming soon',
      price3Days: 1100,
      price7Days: 2100,
      pricePermanent: 12000,
    ),

    // =========================================================================
    // 4. CAFÉ TABLE PROPS ('cafe_props' — drawn next to player on table!)
    // =========================================================================
    const ShopItemDefinition(
      id: 'prop_estekan_tea',
      category: ShopCategory.cafeProps,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.classic,
      isDefaultFree: true,
      titleAr: 'استكان جاي مهيل',
      titleEn: 'Cardamom Estekan Tea',
      descAr: 'ضيافة الطاولة الأساسية',
      descEn: 'Default table tea glass',
    ),
    const ShopItemDefinition(
      id: 'prop_loomi_tea',
      category: ShopCategory.cafeProps,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.rare,
      titleAr: 'جاي نومي بصرة',
      titleEn: 'Black Lime Tea',
      descAr: 'استكان نومي بصرة دافئ',
      descEn: 'Dark black-lime tea glass',
      price3Days: 250,
      price7Days: 480,
      pricePermanent: 2600,
    ),
    const ShopItemDefinition(
      id: 'prop_kleicha_plate',
      category: ShopCategory.cafeProps,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.rare,
      titleAr: 'ماعون كليجة بالتمر',
      titleEn: 'Date Kleicha Plate',
      descAr: 'ماعون نحاسي بكليجة التمر',
      descEn: 'Brass saucer with date pastries',
      price3Days: 400,
      price7Days: 750,
      pricePermanent: 4200,
    ),
    const ShopItemDefinition(
      id: 'prop_arabic_coffee',
      category: ShopCategory.cafeProps,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'دلة وفنجان قهوة',
      titleEn: 'Golden Dallah & Finjan',
      descAr: 'دلة مذهّبة وفنجان عربي',
      descEn: 'Gilded dallah & finjan cup',
      price3Days: 500,
      price7Days: 950,
      pricePermanent: 5200,
    ),
    const ShopItemDefinition(
      id: 'prop_amber_misbaha',
      category: ShopCategory.cafeProps,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'مسبحة كهرب كهرمان',
      titleEn: 'Pure Amber Misbaha',
      descAr: 'مسبحة كهرب بكركوشة فضية',
      descEn: 'Honey-amber beads',
      price3Days: 650,
      price7Days: 1250,
      pricePermanent: 7000,
    ),
    const ShopItemDefinition(
      id: 'prop_brass_samovar',
      category: ShopCategory.cafeProps,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'سماور نحاسي تراثي',
      titleEn: 'Heritage Brass Samovar',
      descAr: 'سماور نحاسي مصغّر',
      descEn: 'Miniature brass samovar',
      price3Days: 950,
      price7Days: 1800,
      pricePermanent: 10800,
    ),
    const ShopItemDefinition(
      id: 'prop_oud_burner',
      category: ShopCategory.cafeProps,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.legendary,
      titleAr: 'مبخرة عود ملكية',
      titleEn: 'Royal Oud Burner',
      descAr: 'مبخرة مذهّبة ببخور هادئ',
      descEn: 'Golden oud incense censer',
      price3Days: 1150,
      price7Days: 2200,
      pricePermanent: 13200,
    ),

    // =========================================================================
    // 5. SMART BOOSTERS & INTERACTIONS ('boosters')
    // =========================================================================
    const ShopItemDefinition(
      id: 'boost_xp_2x_24h',
      category: ShopCategory.boosters,
      kind: ShopItemKind.consumableBooster,
      rarity: ItemRarity.rare,
      singlePrice: 650,
      durationDays: 1,
      titleAr: 'مضاعف الخبرة 2x (24 ساعة)',
      titleEn: '2x XP Booster (24h)',
      descAr: 'مضاعفة خبرة الأونلاين ليوم',
      descEn: '2x online XP for 24h',
    ),
    const ShopItemDefinition(
      id: 'boost_xp_2x_3d',
      category: ShopCategory.boosters,
      kind: ShopItemKind.consumableBooster,
      rarity: ItemRarity.royal,
      singlePrice: 1500,
      durationDays: 3,
      titleAr: 'مضاعف الخبرة 2x (3 أيام)',
      titleEn: '2x XP Booster (3 Days)',
      descAr: 'مضاعفة خبرة الأونلاين لـ 3 أيام',
      descEn: '2x online XP for 3 days',
    ),
    const ShopItemDefinition(
      id: 'boost_daily_cap_1000',
      category: ShopCategory.boosters,
      kind: ShopItemKind.consumableBooster,
      rarity: ItemRarity.rare,
      singlePrice: 500,
      titleAr: 'رفع الحد اليومي (+1,000 XP)',
      titleEn: 'Daily Cap +1,000 XP',
      descAr: 'إضافة 1,000 XP لسقف اليوم',
      descEn: '+1,000 XP to today\'s cap',
    ),
    const ShopItemDefinition(
      id: 'boost_rating_shield_3',
      category: ShopCategory.boosters,
      kind: ShopItemKind.consumableBooster,
      rarity: ItemRarity.royal,
      singlePrice: 950,
      titleAr: 'درع التقييم (3 مباريات)',
      titleEn: 'Rating Shield (3 Losses)',
      descAr: 'حماية التقييم لـ 3 خسارات',
      descEn: 'Protects rating for 3 losses',
    ),
    const ShopItemDefinition(
      id: 'boost_tournament_ticket',
      category: ShopCategory.boosters,
      kind: ShopItemKind.consumableBooster,
      rarity: ItemRarity.rare,
      singlePrice: 350,
      titleAr: 'تذكرة بطولة إضافية',
      titleEn: 'Extra Tournament Ticket',
      descAr: 'دخول إضافي للبطولة اليومية',
      descEn: 'Extra daily cup entry',
    ),
    const ShopItemDefinition(
      id: 'chat_sheikh_pack',
      category: ShopCategory.boosters,
      kind: ShopItemKind.equippable,
      rarity: ItemRarity.royal,
      titleAr: 'حزمة عبارات المجلس',
      titleEn: 'Table Expressions Pack',
      descAr: 'عبارات تفاعلية سريعة بالطاولة',
      descEn: 'Quick table callouts',
      price3Days: 350,
      price7Days: 650,
      pricePermanent: 3900,
    ),

    // =========================================================================
    // 6. VIP MEMBERSHIP: مجلس شيوخ المقهى ('vip')
    // =========================================================================
    const ShopItemDefinition(
      id: 'vip_sheikh_7d',
      category: ShopCategory.vip,
      kind: ShopItemKind.vipMembership,
      rarity: ItemRarity.royal,
      singlePrice: 3200,
      durationDays: 7,
      titleAr: 'مجلس الشيوخ VIP (7 أيام)',
      titleEn: 'Sheikh VIP (7 Days)',
      descAr: 'خبرة 2x • حد 4,000 • خصم 15% • تذكرة',
      descEn: '2x XP • 4k Cap • 15% Off • +1 Ticket',
    ),
    const ShopItemDefinition(
      id: 'vip_sheikh_30d',
      category: ShopCategory.vip,
      kind: ShopItemKind.vipMembership,
      rarity: ItemRarity.legendary,
      singlePrice: 10500,
      durationDays: 30,
      titleAr: 'مجلس الشيوخ VIP (30 يوماً)',
      titleEn: 'Sheikh VIP (30 Days)',
      descAr: 'خبرة 2x • حد 4,000 • خصم 15% • 3 تذاكر',
      descEn: '2x XP • 4k Cap • 15% Off • +3 Tickets',
    ),
  ];

  static ShopItemDefinition? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  static List<ShopItemDefinition> byCategory(
    ShopCategory category, {
    String? gameIdFilter,
  }) => [
    for (final item in items)
      if (item.category == category &&
          (gameIdFilter == null || item.gameId == gameIdFilter))
        item,
  ];
}
