import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/catalog/data/manifest_provider.dart';
import 'package:puzzles/features/catalog/domain/content_manifest.dart';
import 'package:puzzles/features/purchase/data/purchase_providers.dart';
import 'package:puzzles/features/purchase/data/revenuecat_purchase_service.dart';
import 'package:puzzles/features/purchase/domain/parental_challenge.dart';
import 'package:puzzles/features/purchase/domain/purchase_service.dart';
import 'package:puzzles/features/puzzle/domain/difficulty.dart';
import 'package:puzzles/features/puzzle/puzzle_controller.dart';
import 'package:puzzles/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

PuzzleEntry entry(String id, {required bool free}) => PuzzleEntry(
  id: id,
  categoryId: 'sea',
  title: const LocalizedText({'en': 'x'}),
  free: free,
  asset: 'images/free/$id.webp',
);

void main() {
  final manifest = ContentManifest.fromJson(
    jsonDecode(File('assets/manifest.json').readAsStringSync()),
  );

  group('canPlay', () {
    test('free pictures always, paid ones only with the full version', () {
      final free = entry('a', free: true);
      final paid = entry('b', free: false);
      expect(canPlay(free, fullAccess: false), isTrue);
      expect(canPlay(free, fullAccess: true), isTrue);
      expect(canPlay(paid, fullAccess: false), isFalse);
      expect(canPlay(paid, fullAccess: true), isTrue);
    });
  });

  group('ParentalChallenge', () {
    test('accepts only the product, typed in digits', () {
      const challenge = ParentalChallenge(7, 8);
      expect(challenge.check('56'), isTrue);
      expect(challenge.check(' 56 '), isTrue);
      expect(challenge.check('54'), isFalse);
      expect(challenge.check(''), isFalse);
      expect(challenge.check('fifty-six'), isFalse);
    });

    test('random factors stay in 2..9', () {
      final random = Random(1);
      for (var i = 0; i < 500; i++) {
        final c = ParentalChallenge.random(random);
        expect(c.a, inInclusiveRange(2, 9));
        expect(c.b, inInclusiveRange(2, 9));
      }
    });
  });

  test('release builds need a Google Play RevenueCat key', () {
    expect(
      () => checkRevenueCatConfigured(release: true, apiKey: ''),
      throwsStateError,
    );
    expect(
      () => checkRevenueCatConfigured(release: true, apiKey: 'test_x'),
      throwsStateError,
    );
    checkRevenueCatConfigured(release: true, apiKey: 'goog_x');
    // Debug and profile: no key, or the RevenueCat Test Store.
    checkRevenueCatConfigured(release: false, apiKey: '');
    checkRevenueCatConfigured(release: false, apiKey: 'test_x');
  });

  test('a Test Store key uses the real RevenueCat service', () {
    final container = ProviderContainer(
      overrides: [revenueCatApiKeyProvider.overrideWithValue('test_x')],
    );
    addTearDown(container.dispose);
    expect(
      container.read(purchaseServiceProvider),
      isA<RevenueCatPurchaseService>(),
    );
  });

  test('without a key the fake test store is used', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(purchaseServiceProvider);
    expect(service, isA<FakePurchaseService>());
    expect((service as FakePurchaseService).testStore, isTrue);
  });

  group('PurchaseController', () {
    late FakePurchaseService store;
    late ProviderContainer container;
    final paid = entry('paid', free: false);

    setUp(() {
      store = FakePurchaseService();
      container = ProviderContainer(
        overrides: [purchaseServiceProvider.overrideWithValue(store)],
      );
      container.listen(canPlayProvider(paid), (_, _) {});
      container.listen(purchaseControllerProvider, (_, _) {});
    });
    tearDown(() => container.dispose());

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    PurchaseController controller() =>
        container.read(purchaseControllerProvider.notifier);
    PurchaseStatus status() => container.read(purchaseControllerProvider);
    bool canPlayPaid() => container.read(canPlayProvider(paid));

    test('a purchase unlocks paid pictures at once', () async {
      await settle();
      expect(canPlayPaid(), isFalse);
      await controller().purchase();
      await settle();
      expect(status(), PurchaseStatus.purchased);
      expect(canPlayPaid(), isTrue);
    });

    test('a cancelled purchase keeps them locked', () async {
      store.purchaseBehavior = FakePurchaseBehavior.cancel;
      await controller().purchase();
      await settle();
      expect(status(), PurchaseStatus.cancelled);
      expect(canPlayPaid(), isFalse);
    });

    test('a store error is reported', () async {
      store.purchaseBehavior = FakePurchaseBehavior.fail;
      await controller().purchase();
      await settle();
      expect(status(), PurchaseStatus.failed);
      expect(canPlayPaid(), isFalse);
    });

    test('a pending payment is reported as pending', () async {
      store.purchaseBehavior = FakePurchaseBehavior.pending;
      await controller().purchase();
      await settle();
      expect(status(), PurchaseStatus.pending);
      expect(canPlayPaid(), isFalse);
    });

    test('an already owned version is restored', () async {
      store
        ..purchaseBehavior = FakePurchaseBehavior.alreadyOwned
        ..restorable = true;
      await controller().purchase();
      await settle();
      expect(status(), PurchaseStatus.purchased);
      expect(canPlayPaid(), isTrue);
    });

    test('already owned with nothing to restore fails', () async {
      store.purchaseBehavior = FakePurchaseBehavior.alreadyOwned;
      await controller().purchase();
      await settle();
      expect(status(), PurchaseStatus.failed);
      expect(canPlayPaid(), isFalse);
    });

    test('a store error during restore is a restore failure', () async {
      store.restoreFails = true;
      await controller().restore();
      expect(status(), PurchaseStatus.restoreFailed);
    });

    test('restore brings back an earlier purchase', () async {
      await controller().restore();
      expect(status(), PurchaseStatus.nothingToRestore);
      store.restorable = true;
      await controller().restore();
      await settle();
      expect(status(), PurchaseStatus.restored);
      expect(canPlayPaid(), isTrue);
    });

    test('a refund locks the paid pictures again', () async {
      await controller().purchase();
      await settle();
      expect(canPlayPaid(), isTrue);
      store.setFullAccess(false);
      await settle();
      expect(canPlayPaid(), isFalse);
    });
  });

  group('access in the puzzle', () {
    late FakePurchaseService store;
    late ProviderContainer container;

    setUp(() async {
      store = FakePurchaseService();
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          purchaseServiceProvider.overrideWithValue(store),
          sharedPreferencesProvider.overrideWithValue(prefs),
          manifestProvider.overrideWith((ref) async => manifest),
        ],
      );
    });
    tearDown(() => container.dispose());

    test('the controller refuses a locked picture', () async {
      const args = (puzzleId: 'sea_seal_ice', difficulty: Difficulty.easy);
      final provider = puzzleControllerProvider(args);
      container.listen(provider, (_, _) {});
      await expectLater(
        container.read(provider.future),
        throwsA(isA<PuzzleLockedException>()),
      );
    });

    test('"Next" skips locked pictures until the full version', () async {
      final provider = nextPlayableProvider('sea_whale_spout');
      container.listen(provider, (_, _) {});
      await container.read(manifestProvider.future);
      await Future<void>.delayed(Duration.zero);
      // Whale is the last free sea picture: wrap to the first one.
      expect(container.read(provider)?.id, 'sea_turtle');
      store.setFullAccess(true);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider)?.id, 'sea_seal_ice');
    });
  });
}
