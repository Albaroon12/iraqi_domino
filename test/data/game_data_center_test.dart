import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
