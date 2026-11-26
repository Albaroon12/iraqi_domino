import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/data/cafe_events_and_tournaments.dart';
import 'package:iraqi_domino/data/cafe_progression.dart';
import 'package:iraqi_domino/data/cafe_shop_catalog.dart';
import 'package:iraqi_domino/data/game_data_center.dart';
import 'package:iraqi_domino/data/player_account.dart';
import 'package:iraqi_domino/state/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> createContainer([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  test('GameDataCenter creates and persists a stable Guest identity', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final c1 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final guest1 = c1.read(gameDataCenterProvider);
    expect(guest1.isGuest, isTrue);
    expect(guest1.playerId, startsWith('guest_'));
    expect(guest1.guestDeviceId, guest1.playerId);

    c1.read(gameDataCenterProvider.notifier).updateDisplayName('أبو وسام');
    c1.dispose();

    // Re-open container on same storage: same playerId and updated displayName!
    final c2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    final guest2 = c2.read(gameDataCenterProvider);
    expect(guest2.playerId, guest1.playerId);
    expect(guest2.displayName, 'أبو وسام');
  });

  test('GameDataCenter upgrades Guest to Authenticated and signs back out to Guest', () async {
    final container = await createContainer();
    addTearDown(container.dispose);

    final notifier = container.read(gameDataCenterProvider.notifier);
    final initialGuestId = container.read(gameDataCenterProvider).guestDeviceId;

    notifier.recordMatchOutcome(won: true, ourScore: 155, roundsWonInMatch: 4);

    notifier.bindAuthenticatedAccount(
      userId: 'usr_998877',
      provider: AuthProviderKind.google,
      displayName: 'علي العراقي',
      email: 'ali@example.com',
      authToken: 'secret_jwt_token',
      rating: 1320,
    );

    final authed = container.read(gameDataCenterProvider);
    expect(authed.isAuthenticated, isTrue);
    expect(authed.playerId, 'usr_998877');
    expect(authed.guestDeviceId, initialGuestId);
    expect(authed.stats.matchesWon, 1);
    // Public profile never leaks auth tokens!
    final pubJson = notifier.publicProfile.toJson();
    expect(pubJson.containsKey('authToken'), isFalse);
    expect(pubJson['isGuest'], isFalse);

    // Sign out back to Guest mode: restores device guestId and clears tokens.
    notifier.continueAsGuest();
    final backToGuest = container.read(gameDataCenterProvider);
    expect(backToGuest.isGuest, isTrue);
    expect(backToGuest.playerId, initialGuestId);
    expect(backToGuest.authToken, isNull);
    expect(backToGuest.stats.matchesWon, 1);
  });

  test('Offline AI gives 0 match XP, Online gives exact round/match XP, and badges bypass daily 2000 cap', () async {
    final container = await createContainer();
    addTearDown(container.dispose);

    final notifier = container.read(gameDataCenterProvider.notifier);

    // 1. Offline vs AI match: 0 match XP! (Only unlocked badge XP is granted:
    //    `domino_first_win` = +50 XP).
    notifier.recordMatchOutcome(
      won: true,
      ourScore: 155,
      opponentScore: 40,
      roundsWonInMatch: 4,
      roundsLostInMatch: 1,
      isOnlineMatch: false,
      todayDateOverride: '2026-11-26',
    );

    final afterOffline = container.read(gameDataCenterProvider);
    expect(afterOffline.dailyMatchXp, 0);
    expect(afterOffline.unlockedBadgeIds, contains('domino_first_win'));
    expect(afterOffline.totalXp, 50); // +50 from badge only, 0 from offline match!

    // 2. Online match win with 3 rounds won (+30), 2 rounds lost (+10), match win (+60) = +100 Match XP:
    notifier.recordMatchOutcome(
      won: true,
      ourScore: 152,
      opponentScore: 80,
      roundsWonInMatch: 3,
      roundsLostInMatch: 2,
      isOnlineMatch: true,
      todayDateOverride: '2026-11-26',
    );

    final afterOnline = container.read(gameDataCenterProvider);
    expect(afterOnline.dailyMatchXp, 100);
    expect(afterOnline.totalXp, 150);
    expect(afterOnline.level, 2); // Lv1->2 required 80 XP!

    // 3. Fill daily match XP up to the 2,000 daily cap:
    for (var i = 0; i < 25; i++) {
      notifier.recordMatchOutcome(
        won: true,
        ourScore: 151,
        opponentScore: 20,
        roundsWonInMatch: 4, // 40 + 60 = 100 XP per match
        isOnlineMatch: true,
        todayDateOverride: '2026-11-26',
      );
    }

    final capped = container.read(gameDataCenterProvider);
    expect(capped.dailyMatchXp, 2000); // Strictly capped at 2,000 XP/day!

    // 4. Unlocking a new badge (`domino_first_block`, +50 XP) or event bonus
    //    STILL adds XP even when daily match cap (2000) is full!
    final xpBeforeBadge = capped.totalXp;
    notifier.recordMatchOutcome(
      won: false,
      ourScore: 60,
      opponentScore: 151,
      roundsWonInMatch: 1,
      blockedWinsInMatch: 1,
      isOnlineMatch: true,
      todayDateOverride: '2026-11-26',
    );
    final afterBadgeAtCap = container.read(gameDataCenterProvider);
    expect(afterBadgeAtCap.dailyMatchXp, 2000);
    expect(afterBadgeAtCap.unlockedBadgeIds, contains('domino_first_block'));
    expect(afterBadgeAtCap.totalXp, xpBeforeBadge + 50);

    // 5. VIP doubles daily cap to 4,000 XP and doubles match XP (×2):
    notifier.setVipStatus(true);
    notifier.recordMatchOutcome(
      won: true,
      ourScore: 151,
      opponentScore: 50,
      roundsWonInMatch: 2, // (2*10 + 60) * 2 = 160 VIP Match XP
      isOnlineMatch: true,
      todayDateOverride: '2026-11-26',
    );
    final afterVip = container.read(gameDataCenterProvider);
    expect(afterVip.dailyMatchXp, 2160);
  });

  test('Max level caps at 50 and Al-Maqha titles depend on Leaderboard Rank', () {
    final maxInfo = CafeProgression.resolveLevel(999999);
    expect(maxInfo.level, 50);
    expect(maxInfo.progress, 1.0);

    expect(
      CafeProgression.cafeTitleForRank(
        leaderboardRank: 1,
        rating: 1200,
        isAr: true,
      ),
      'شيخ المقهى',
    );
    expect(
      CafeProgression.cafeTitleForRank(
        leaderboardRank: 2,
        rating: 1100,
        isAr: true,
      ),
      'كبير المقهى',
    );
  });

  test('Phase 9 Economy: 0 Dinars from normal matches, 10% tournament rake, 3d/7d rental expiry, permanent buy, VIP 15% discount & Rating Shield', () async {
    final container = await createContainer();
    addTearDown(container.dispose);

    final notifier = container.read(gameDataCenterProvider.notifier);
    final t0 = DateTime(2026, 11, 26, 12);

    // 1. Starter welcome balance is 250 Dinars; normal matches award 0 Dinars!
    expect(container.read(gameDataCenterProvider).cafeDinars, 250);
    notifier.recordMatchOutcome(
      won: true,
      ourScore: 151,
      roundsWonInMatch: 4,
      isOnlineMatch: true,
      nowOverride: t0,
    );
    expect(container.read(gameDataCenterProvider).cafeDinars, 250);

    // 2. 10% Café tournament rake: 4 players × 500 Dinars = 2,000 -> 1,800 net pool!
    expect(
      CafeShopCatalog.calculateTournamentPrizePool(
        entryFeeDinars: 500,
        playerCount: 4,
      ),
      1800,
    );

    // 3. Grant event + tournament winnings to test rentals, VIP & permanent items:
    notifier.grantEventReward(dinars: 300); // 550 Dinars
    expect(notifier.enterTournament(entryFeeDinars: 500), isTrue); // 50 Dinars left
    notifier.awardTournamentPrize(prizeDinars: 15000); // 15,050 Dinars

    // 4. Rent Iraq Flag table for 3 days (650 Dinars): auto-equipped now, expires after 3 days!
    final rentRes = notifier.purchaseShopItem(
      itemId: 'table_flag_iraq',
      duration: PurchaseDuration.days3,
      now: t0,
    );
    expect(rentRes, ShopPurchaseStatus.success);
    expect(
      container.read(gameDataCenterProvider).effectiveTableId(t0),
      'table_flag_iraq',
    );
    final after4Days = t0.add(const Duration(days: 4));
    expect(
      container.read(gameDataCenterProvider).effectiveTableId(after4Days),
      'table_classic_green', // Automatically reverts to default on expiry!
    );

    // 5. Activate Council of Sheikhs VIP (7 days = 3,200 Dinars): grants 15% discount + 1 ticket!
    final vipRes = notifier.purchaseShopItem(
      itemId: 'vip_sheikh_7d',
      now: t0,
    );
    expect(vipRes, ShopPurchaseStatus.success);
    final afterVip = container.read(gameDataCenterProvider);
    expect(afterVip.isVipActive(t0), isTrue);
    expect(afterVip.extraTournamentTickets, 1);

    // Royal Gold frame permanent base price is 6,800 -> with 15% VIP discount = 5,780 Dinars!
    final frameItem = CafeShopCatalog.byId('frame_royal_gold')!;
    expect(
      frameItem.priceFor(PurchaseDuration.permanent, isVipActive: true),
      5780,
    );
    final dinarsBeforeFrame = afterVip.cafeDinars;
    expect(
      notifier.purchaseShopItem(
        itemId: 'frame_royal_gold',
        duration: PurchaseDuration.permanent,
        now: t0,
      ),
      ShopPurchaseStatus.success,
    );
    final afterPerm = container.read(gameDataCenterProvider);
    expect(afterPerm.cafeDinars, dinarsBeforeFrame - 5780);
    // Permanent item never expires even a year later!
    expect(
      afterPerm.effectiveFrameId(t0.add(const Duration(days: 365))),
      'frame_royal_gold',
    );

    // 6. Rating Shield (3 losses) protects rating from dropping on defeat:
    notifier.purchaseShopItem(itemId: 'boost_rating_shield_3', now: t0);
    final ratingBeforeLoss = container.read(gameDataCenterProvider).rating;
    notifier.recordMatchOutcome(
      won: false,
      ourScore: 40,
      opponentScore: 151,
      roundsWonInMatch: 1,
      roundsLostInMatch: 4,
      isOnlineMatch: true,
      nowOverride: t0,
    );
    final afterProtectedLoss = container.read(gameDataCenterProvider);
    expect(afterProtectedLoss.rating, ratingBeforeLoss); // 0 loss!
    expect(afterProtectedLoss.ratingShieldCharges, 2);
  });

  test('Phase 10 Tournaments & Seasonal Events: daily free entry, ticket re-entry, 10%-rake staked cup & Ramadan event claim', () async {
    final container = await createContainer();
    addTearDown(container.dispose);

    final notifier = container.read(gameDataCenterProvider.notifier);
    final freeCup = CafeLiveOpsDefaults.tournaments.firstWhere(
      (t) => t.isDailyFree,
    );
    final maestrosCup = CafeLiveOpsDefaults.tournaments.firstWhere(
      (t) => t.id == 'cup_maestros_500',
    );
    expect(maestrosCup.netPrizeDinars, 1800); // 500 * 4 - 10% = 1800

    // 1. Enter Daily Free Cup on 2026-11-26 -> free! Second entry same day blocked without ticket:
    expect(
      notifier.startTournamentSession(freeCup, todayDateOverride: '2026-11-26'),
      TournamentEntryStatus.enteredFreeDaily,
    );
    expect(
      notifier.startTournamentSession(freeCup, todayDateOverride: '2026-11-26'),
      TournamentEntryStatus.dailyFreeAlreadyUsed,
    );
    notifier.completeTournamentMatch(tier: freeCup, won: true);
    expect(container.read(gameDataCenterProvider).cafeDinars, 350); // 250 + 100
    expect(container.read(gameDataCenterProvider).tournamentsWon, 1);

    // 2. Complete a Recurring Daily Event (win 2 matches -> claim on day 1 -> resets on day 2 requiring 2 fresh wins!):
    const dailyEv = CafeEventDefinition(
      id: 'ev_daily_test',
      titleAr: 'إيفنت يومي ثابت',
      titleEn: 'Daily Event',
      descAr: 'اربح مباراتين',
      descEn: 'Win 2 matches',
      theme: EventThemeKind.cafeNight,
      recurrence: EventRecurrenceKind.daily,
      metric: EventMetricKind.matchesWon,
      targetValue: 2,
      rewardDinars: 400,
      rewardBonusXp: 300,
    );
    expect(
      notifier.claimEventReward(dailyEv, todayDateOverride: '2026-11-26'),
      isFalse,
    );

    notifier.recordMatchOutcome(won: true, ourScore: 151, roundsWonInMatch: 3);
    notifier.recordMatchOutcome(won: true, ourScore: 151, roundsWonInMatch: 3);
    expect(
      notifier.claimEventReward(dailyEv, todayDateOverride: '2026-11-26'),
      isTrue,
    );
    // Cannot claim twice on the same day:
    expect(
      notifier.claimEventReward(dailyEv, todayDateOverride: '2026-11-26'),
      isFalse,
    );
    // Next day (2026-11-27): resets automatically, requiring 2 NEW wins!
    expect(
      notifier.claimEventReward(dailyEv, todayDateOverride: '2026-11-27'),
      isFalse,
    );
    expect(container.read(gameDataCenterProvider).cafeDinars, 750); // 350 + 400

    // 3. Enter Staked 500-Dinar Maestros Cup -> deducts 500 -> win awards 1,800 net prize!
    expect(
      notifier.startTournamentSession(maestrosCup),
      TournamentEntryStatus.enteredPaid,
    );
    expect(container.read(gameDataCenterProvider).cafeDinars, 250); // 750 - 500
    notifier.completeTournamentMatch(tier: maestrosCup, won: true);
    expect(container.read(gameDataCenterProvider).cafeDinars, 2050); // 250 + 1800
    expect(container.read(gameDataCenterProvider).tournamentsWon, 2);
  });
}
