import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Use the same channel/codec seams as the cached official SDK's own tests.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';
import 'package:multiplayer_game/core/ads/ad_mob_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdMob inventory', () {
    testWidgets('deduplicates pending and cached loads', (tester) async {
      final inventory = _InventoryHarness();
      addTearDown(inventory.inventory.clear);
      inventory.inventory.request();
      inventory.inventory.request();
      expect(inventory.loaded, hasLength(1));
      final ad = Object();
      inventory.loaded.single(ad);
      inventory.inventory.request();
      expect(inventory.loaded, hasLength(1));
      expect(inventory.inventory.take(), same(ad));
      inventory.inventory.request();
      expect(inventory.loaded, hasLength(2));
    });

    testWidgets('retries at 2, 4, 8 seconds then stops', (tester) async {
      final inventory = _InventoryHarness();
      addTearDown(inventory.inventory.clear);
      inventory.inventory.request();
      for (final seconds in [2, 4, 8]) {
        final count = inventory.loaded.length;
        inventory.failed.last(StateError('no fill'));
        inventory.inventory.request();
        await tester.pump(Duration(seconds: seconds - 1));
        expect(inventory.loaded, hasLength(count));
        await tester.pump(const Duration(seconds: 1));
        expect(inventory.loaded, hasLength(count + 1));
      }
      inventory.failed.last(StateError('still no fill'));
      await tester.pump(const Duration(minutes: 5));
      inventory.inventory.request();
      expect(inventory.loaded, hasLength(4));
    });

    testWidgets('successful loads reset the retry budget', (tester) async {
      final inventory = _InventoryHarness();
      addTearDown(inventory.inventory.clear);
      inventory.inventory.request();
      inventory.failed.last(StateError('no fill'));
      await tester.pump(const Duration(seconds: 2));
      inventory.loaded.last(Object());
      inventory.inventory.take();
      inventory.inventory.request();
      inventory.failed.last(StateError('new no fill'));
      await tester.pump(const Duration(seconds: 2));
      expect(inventory.loaded, hasLength(4));
    });

    testWidgets('revocation disposes cache and cancels retries', (
      tester,
    ) async {
      final inventory = _InventoryHarness();
      inventory.inventory.request();
      final ad = Object();
      inventory.loaded.last(ad);
      inventory.allowed = false;
      inventory.inventory.clear();
      await tester.pump();
      expect(inventory.disposed, [ad]);
      expect(inventory.inventory.ready, isFalse);
      inventory.inventory.request();
      expect(inventory.loaded, hasLength(1));

      inventory.allowed = true;
      inventory.inventory.request();
      inventory.failed.last(StateError('no fill'));
      inventory.allowed = false;
      inventory.inventory.clear();
      await tester.pump(const Duration(minutes: 1));
      expect(inventory.loaded, hasLength(2));
    });

    testWidgets('stale callbacks cannot clobber a new pending load', (
      tester,
    ) async {
      final inventory = _InventoryHarness();
      addTearDown(inventory.inventory.clear);
      inventory.inventory.request();
      inventory.inventory.clear();
      inventory.inventory.request();
      final staleAd = Object();
      inventory.loaded.first(staleAd);
      inventory.failed.first(StateError('late failure'));
      inventory.inventory.request();
      expect(inventory.loaded, hasLength(2));
      expect(inventory.inventory.ready, isFalse);
      final currentAd = Object();
      inventory.loaded.last(currentAd);
      await tester.pump();
      expect(inventory.disposed, [staleAd]);
      expect(inventory.inventory.take(), same(currentAd));
    });

    testWidgets('duplicate callbacks do not dispose accepted inventory', (
      tester,
    ) async {
      final inventory = _InventoryHarness();
      addTearDown(inventory.inventory.clear);
      inventory.inventory.request();
      final ad = Object();
      inventory.loaded.single(ad);
      inventory.loaded.single(ad);
      inventory.failed.single(StateError('late failure'));
      await tester.pump(const Duration(seconds: 30));
      expect(inventory.loaded, hasLength(1));
      expect(inventory.disposed, isEmpty);
      inventory.inventory.clear();
      inventory.inventory.clear();
      await tester.pump();
      expect(inventory.disposed, [ad]);
    });

    testWidgets('synchronous load and disposal errors stay contained', (
      tester,
    ) async {
      var attempts = 0;
      final inventory = AdMobInventory<Object>(
        canLoad: () => true,
        load: (_, __) {
          attempts++;
          throw StateError('channel unavailable');
        },
        dispose: (_) async {},
      );
      inventory.request();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(attempts, 2);
      inventory.clear();
      final disposal = AdMobInventory<Object>(
        canLoad: () => true,
        load: (onLoaded, _) async => onLoaded(Object()),
        dispose: (_) => throw StateError('dispose unavailable'),
      );
      disposal.request();
      disposal.clear();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('AdMob service with official SDK channel', () {
    late _SdkHarness sdk;
    late AdMobService service;

    setUp(() {
      sdk = _SdkHarness();
      service = AdMobService.forTesting();
    });

    tearDown(() {
      service.disposeForTest();
    });

    testWidgets('shared initialization, sample IDs, no ad while loading', (
      tester,
    ) async {
      await Future.wait([service.initialize(), service.initialize()]);
      await tester.pump();
      expect(sdk.callsFor('MobileAds#initialize'), hasLength(1));
      expect(sdk.callsFor('loadInterstitialAd'), hasLength(1));
      expect(sdk.callsFor('loadRewardedInterstitialAd'), hasLength(1));
      expect(
        sdk.callsFor('loadInterstitialAd').single.arguments['adUnitId'],
        'ca-app-pub-3940256099942544/1033173712',
      );
      expect(
        sdk.callsFor('loadRewardedInterstitialAd').single.arguments['adUnitId'],
        'ca-app-pub-3940256099942544/5354046379',
      );
      expect(await service.showInterstitialAtMatchBreak(), isFalse);
    });

    testWidgets('denied consent makes no SDK or ad requests', (tester) async {
      sdk.allowed = false;
      await service.initialize();
      await tester.pump();
      expect(sdk.calls, isEmpty);
      expect(service.interstitialReady, isFalse);
      expect(await service.showInterstitialAtMatchBreak(), isFalse);
    });

    testWidgets(
      'privacy withdrawal disposes both formats and rejects late loads',
      (tester) async {
        await service.initialize();
        await tester.pump();
        final interstitial = sdk.interstitial;
        final rewarded = sdk.rewarded;
        interstitial.adLoadCallback.onAdLoaded(interstitial);
        rewarded.rewardedInterstitialAdLoadCallback.onAdLoaded(rewarded);
        sdk.allowed = false;
        await service.showPrivacyOptions();
        await tester.pump();
        expect(service.interstitialReady, isFalse);
        expect(service.rewardedInterstitialReady, isFalse);
        expect(sdk.callsFor('disposeAd'), hasLength(2));
        expect(await service.showInterstitialAtMatchBreak(), isFalse);
        expect(sdk.callsFor('loadInterstitialAd'), hasLength(1));

        // Start a fresh consent generation, then revoke while loads are pending.
        sdk.allowed = true;
        await service.showPrivacyOptions();
        await tester.pump();
        final pending = sdk.interstitial;
        sdk.allowed = false;
        await service.showPrivacyOptions();
        pending.adLoadCallback.onAdLoaded(pending);
        await tester.pump();
        expect(service.interstitialReady, isFalse);
        expect(sdk.callsFor('disposeAd'), hasLength(3));
      },
    );

    testWidgets('privacy form errors still recheck changed consent', (
      tester,
    ) async {
      await service.initialize();
      await tester.pump();
      final ad = sdk.interstitial;
      ad.adLoadCallback.onAdLoaded(ad);
      sdk.allowed = false;
      sdk.privacyFormFails = true;
      await service.showPrivacyOptions();
      await tester.pump();
      expect(service.interstitialReady, isFalse);
      expect(sdk.callsFor('disposeAd'), hasLength(1));
    });

    testWidgets('late full-screen callbacks dispose and reload only once', (
      tester,
    ) async {
      await service.initialize();
      await tester.pump();
      final ad = sdk.interstitial;
      ad.adLoadCallback.onAdLoaded(ad);
      final shown = service.showInterstitialAtMatchBreak();
      await tester.pump();
      ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
      expect(await shown, isTrue);
      ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
      await tester.pump();
      expect(sdk.callsFor('disposeAd'), hasLength(1));
      expect(sdk.callsFor('loadInterstitialAd'), hasLength(2));
      expect(await service.showInterstitialAtMatchBreak(), isFalse);
    });

    testWidgets(
      'show request failure releases the ad without gating gameplay',
      (tester) async {
        await service.initialize();
        await tester.pump();
        final ad = sdk.interstitial;
        ad.adLoadCallback.onAdLoaded(ad);
        sdk.showFails = true;
        final shown = service.showInterstitialAtMatchBreak();
        await tester.pump();
        expect(await shown, isFalse);
        expect(sdk.callsFor('disposeAd'), hasLength(1));
        expect(sdk.callsFor('loadInterstitialAd'), hasLength(2));
      },
    );

    for (final finish in ['dismiss', 'watchdog', 'dispose', 'revoke']) {
      testWidgets('reward is once-only and late reward ignored after $finish', (
        tester,
      ) async {
        await service.initialize();
        await tester.pump();
        final ad = sdk.rewarded;
        ad.rewardedInterstitialAdLoadCallback.onAdLoaded(ad);
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (value) {
                context = value;
                return const Scaffold();
              },
            ),
          ),
        );
        var rewards = 0;
        final shown = service.offerRewardedInterstitial(
          context,
          rewardDescription: 'An optional test reward',
          onReward: () => rewards++,
        );
        await tester.pumpAndSettle();
        expect(find.text('Skip'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        if (finish == 'dismiss') {
          ad.onUserEarnedRewardCallback!(ad, RewardItem(1, 'test'));
          ad.onUserEarnedRewardCallback!(ad, RewardItem(1, 'test'));
          expect(rewards, 1);
          ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
        } else if (finish == 'watchdog') {
          await tester.pump(const Duration(minutes: 2));
        } else if (finish == 'dispose') {
          service.disposeForTest();
        } else {
          sdk.allowed = false;
          await service.showPrivacyOptions();
        }
        expect(await shown, finish == 'dismiss');
        ad.onUserEarnedRewardCallback!(ad, RewardItem(1, 'test'));
        ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
        await tester.pump();
        expect(rewards, finish == 'dismiss' ? 1 : 0);
        expect(sdk.callsFor('disposeAd'), hasLength(1));
      });
    }

    for (final cancel in ['dispose', 'revoke']) {
      testWidgets('late SDK initialization cannot undo $cancel', (
        tester,
      ) async {
        final gate = Completer<InitializationStatus>();
        sdk.initializationGate = gate;
        final initializing = service.initialize();
        await tester.pump();
        expect(sdk.callsFor('MobileAds#initialize'), hasLength(1));
        if (cancel == 'dispose') {
          service.disposeForTest();
        } else {
          sdk.allowed = false;
          await service.showPrivacyOptions();
        }
        gate.complete(InitializationStatus({}));
        await initializing;
        await tester.pump();
        expect(sdk.callsFor('loadInterstitialAd'), isEmpty);
        expect(sdk.callsFor('loadRewardedInterstitialAd'), isEmpty);
        expect(service.interstitialReady, isFalse);
      });
    }

    testWidgets('skipping the disclosure never shows or rewards', (
      tester,
    ) async {
      await service.initialize();
      await tester.pump();
      final ad = sdk.rewarded;
      ad.rewardedInterstitialAdLoadCallback.onAdLoaded(ad);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const Scaffold();
            },
          ),
        ),
      );
      var rewards = 0;
      final shown = service.offerRewardedInterstitial(
        context,
        rewardDescription: 'An optional test reward',
        onReward: () => rewards++,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(await shown, isFalse);
      expect(rewards, 0);
      expect(sdk.callsFor('showAdWithoutView'), isEmpty);
      expect(service.rewardedInterstitialReady, isTrue);
    });

    testWidgets('pending loads after service disposal never become ready', (
      tester,
    ) async {
      await service.initialize();
      await tester.pump();
      final ad = sdk.interstitial;
      service.disposeForTest();
      ad.adLoadCallback.onAdLoaded(ad);
      await tester.pump();
      expect(service.interstitialReady, isFalse);
      expect(sdk.callsFor('disposeAd'), hasLength(1));
      await service.initialize();
      expect(sdk.callsFor('loadInterstitialAd'), hasLength(1));
    });
  });
}

class _InventoryHarness {
  bool allowed = true;
  final loaded = <void Function(Object)>[];
  final failed = <void Function(Object)>[];
  final disposed = <Object>[];
  late final inventory = AdMobInventory<Object>(
    canLoad: () => allowed,
    load: (onLoaded, onFailed) async {
      loaded.add(onLoaded);
      failed.add(onFailed);
    },
    dispose: (ad) async => disposed.add(ad),
  );
}

class _SdkHarness {
  _SdkHarness() {
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      calls.add(call);
      if (call.method == 'MobileAds#initialize') {
        return initializationGate?.future ?? InitializationStatus({});
      }
      if (call.method == 'showAdWithoutView' && showFails) {
        throw PlatformException(code: 'show_failed');
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      MethodChannel(
        'plugins.flutter.io/google_mobile_ads/ump',
        StandardMethodCodec(UserMessagingCodec()),
      ),
      (call) async {
        if (call.method == 'ConsentInformation#canRequestAds') return allowed;
        if (call.method ==
            'ConsentInformation#getPrivacyOptionsRequirementStatus') {
          return 1;
        }
        if (call.method == 'UserMessagingPlatform#showPrivacyOptionsForm' &&
            privacyFormFails) {
          throw PlatformException(code: '1', message: 'form unavailable');
        }
        return null;
      },
    );
  }

  bool allowed = true;
  bool showFails = false;
  bool privacyFormFails = false;
  Completer<InitializationStatus>? initializationGate;
  final calls = <MethodCall>[];
  List<MethodCall> callsFor(String method) =>
      calls.where((call) => call.method == method).toList();
  InterstitialAd get interstitial =>
      instanceManager.adFor(
            callsFor('loadInterstitialAd').last.arguments['adId'] as int,
          )
          as InterstitialAd;
  RewardedInterstitialAd get rewarded =>
      instanceManager.adFor(
            callsFor('loadRewardedInterstitialAd').last.arguments['adId']
                as int,
          )
          as RewardedInterstitialAd;
}
