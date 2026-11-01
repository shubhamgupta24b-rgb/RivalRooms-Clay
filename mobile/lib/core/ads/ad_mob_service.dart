import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Owns the app's full-screen ad inventory so only one format can show at a time.
class AdMobService {
  AdMobService._();

  @visibleForTesting
  AdMobService.forTesting();

  static final instance = AdMobService._();

  // Test inventory is the safe default in debug, profile, and release builds.
  // Only release builds may opt into production with ADMOB_USE_TEST_ADS=false.
  static const _useTestAds =
      !kReleaseMode ||
      bool.fromEnvironment('ADMOB_USE_TEST_ADS', defaultValue: true);
  static const _productionInterstitialId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-2273708482671832/3168825409',
  );
  static const _productionRewardedInterstitialId = String.fromEnvironment(
    'ADMOB_REWARDED_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-2273708482671832/4842753743',
  );

  static const _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewardedInterstitialId =
      'ca-app-pub-3940256099942544/5354046379';

  late final _interstitial = AdMobInventory<InterstitialAd>(
    canLoad: () => !_disposed && _initialized && _canRequestAds,
    load: (onLoaded, onFailed) => InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: onFailed,
      ),
    ),
    dispose: (ad) => ad.dispose(),
  );
  late final _rewarded = AdMobInventory<RewardedInterstitialAd>(
    canLoad: () => !_disposed && _initialized && _canRequestAds,
    load: (onLoaded, onFailed) => RewardedInterstitialAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: onFailed,
      ),
    ),
    dispose: (ad) => ad.dispose(),
  );
  bool _disposed = false;
  int _consentGeneration = 0;
  VoidCallback? _finishActiveAd;
  Future<void>? _initializing;
  bool _initialized = false;
  Future<InitializationStatus>? _sdkInitialization;
  bool _canRequestAds = false;
  bool _showing = false;
  DateTime? _lastInterstitialAt;
  final ValueNotifier<bool> _privacyOptionsAvailable = ValueNotifier(false);

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get interstitialReady => _canRequestAds && _interstitial.ready;
  bool get rewardedInterstitialReady => _canRequestAds && _rewarded.ready;
  ValueListenable<bool> get privacyOptionsAvailable => _privacyOptionsAvailable;

  String get _interstitialId =>
      _useTestAds ? _testInterstitialId : _productionInterstitialId;
  String get _rewardedId => _useTestAds
      ? _testRewardedInterstitialId
      : _productionRewardedInterstitialId;

  Future<void> initialize() {
    if (!_supported || _disposed) return Future.value();
    if (_initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    final generation = _consentGeneration;
    try {
      final consentUpdated = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => consentUpdated.complete(),
        (error) => consentUpdated.completeError(error),
      );
      await consentUpdated.future.timeout(const Duration(seconds: 10));
      if (_disposed || generation != _consentGeneration) return;
      final formDone = Completer<void>();
      await ConsentForm.loadAndShowConsentFormIfRequired(
        (error) =>
            error == null ? formDone.complete() : formDone.completeError(error),
      );
      await formDone.future.timeout(const Duration(seconds: 10));
      if (_disposed || generation != _consentGeneration) return;
      await _refreshPrivacyOptionsRequirement();
      final allowed = await ConsentInformation.instance.canRequestAds().timeout(
        const Duration(seconds: 3),
      );
      if (_disposed || generation != _consentGeneration) return;
      _setConsent(allowed);
      if (!_canRequestAds) return;
      _sdkInitialization ??= MobileAds.instance.initialize();
      await _sdkInitialization!.timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('Mobile Ads SDK initialization timed out'),
      );
      if (_disposed || generation != _consentGeneration) return;
      _initialized = true;
      _loadInterstitial();
      _loadRewardedInterstitial();
    } catch (error, stack) {
      debugPrint('AdMob initialization unavailable: $error\n$stack');
      // A consent network error must never block app use. Cached consent can still
      // authorize requests after UMP has received the update attempt.
      try {
        final allowed = await ConsentInformation.instance
            .canRequestAds()
            .timeout(const Duration(seconds: 3));
        if (_disposed || generation != _consentGeneration) return;
        _setConsent(allowed);
        if (_canRequestAds) {
          _sdkInitialization ??= MobileAds.instance.initialize();
          await _sdkInitialization!.timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
              'Mobile Ads SDK initialization timed out',
            ),
          );
          if (_disposed || generation != _consentGeneration) return;
          _initialized = true;
          await _refreshPrivacyOptionsRequirement();
          _loadInterstitial();
          _loadRewardedInterstitial();
        }
      } catch (fallbackError) {
        debugPrint('AdMob fallback unavailable: $fallbackError');
      }
    }
  }

  void _loadInterstitial() => _interstitial.request();

  void _loadRewardedInterstitial() => _rewarded.request();

  void _setConsent(bool allowed) {
    _canRequestAds = allowed && !_disposed;
    if (_canRequestAds) return;
    _interstitial.clear();
    _rewarded.clear();
    _finishActiveAd?.call();
  }

  void _disposeAd(Ad ad) {
    unawaited(
      Future<void>.sync(ad.dispose).catchError((Object error) {
        debugPrint('Ad disposal unavailable: $error');
      }),
    );
  }

  /// Show only at a completed-match transition. A false result means the user
  /// can proceed immediately without an ad.
  Future<bool> showInterstitialAtMatchBreak() async {
    final now = DateTime.now();
    if (!_canRequestAds || _showing || !_interstitial.ready) return false;
    if (_lastInterstitialAt != null &&
        now.difference(_lastInterstitialAt!) < const Duration(minutes: 3)) {
      return false;
    }

    final ad = _interstitial.take()!;
    _showing = true;
    _lastInterstitialAt = now;
    final done = Completer<bool>();
    var finished = false;
    Timer? watchdog;
    void finish(bool shown) {
      if (finished) return;
      finished = true;
      watchdog?.cancel();
      if (!done.isCompleted) done.complete(shown);
      _showing = false;
      _finishActiveAd = null;
      _disposeAd(ad);
      _loadInterstitial();
    }

    _finishActiveAd = () => finish(false);
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(true),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Interstitial show failed: $error');
        finish(false);
      },
    );
    watchdog = Timer(const Duration(minutes: 2), () {
      debugPrint(
        'Interstitial did not finish within two minutes; releasing it.',
      );
      finish(false);
    });
    unawaited(
      Future<void>.sync(ad.show).catchError((Object error, StackTrace stack) {
        debugPrint('Interstitial show request failed: $error');
        finish(false);
      }),
    );
    return done.future;
  }

  /// Presents Google's required reward disclosure and skip option before show.
  /// The callback runs only from the SDK's earned-reward callback, at most once.
  Future<bool> offerRewardedInterstitial(
    BuildContext context, {
    required String rewardDescription,
    required VoidCallback onReward,
  }) async {
    try {
      await initialize().timeout(const Duration(seconds: 12));
    } catch (error) {
      debugPrint('Rewarded interstitial is unavailable: $error');
      return false;
    }
    if (!context.mounted || !_canRequestAds || _showing || !_rewarded.ready) {
      return false;
    }
    final generation = _consentGeneration;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Watch an ad for a reward?'),
        content: Text('$rewardDescription. You can skip this ad.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (accepted != true ||
        !context.mounted ||
        generation != _consentGeneration ||
        !_canRequestAds ||
        _showing ||
        !_rewarded.ready) {
      return false;
    }

    final ad = _rewarded.take()!;
    _showing = true;
    var rewardGranted = false;
    final done = Completer<bool>();
    var finished = false;
    Timer? watchdog;
    void finish() {
      if (finished) return;
      finished = true;
      watchdog?.cancel();
      if (!done.isCompleted) done.complete(rewardGranted);
      _showing = false;
      _finishActiveAd = null;
      _disposeAd(ad);
      _loadRewardedInterstitial();
    }

    _finishActiveAd = finish;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Rewarded interstitial show failed: $error');
        finish();
      },
    );
    watchdog = Timer(const Duration(minutes: 2), () {
      debugPrint(
        'Rewarded interstitial did not finish within two minutes; releasing it.',
      );
      finish();
    });
    unawaited(
      Future<void>.sync(
        () => ad.show(
          onUserEarnedReward: (_, __) {
            if (finished ||
                rewardGranted ||
                !_canRequestAds ||
                generation != _consentGeneration)
              return;
            rewardGranted = true;
            try {
              onReward();
            } catch (error, stack) {
              debugPrint('Reward callback failed: $error');
              debugPrintStack(stackTrace: stack);
            }
          },
        ),
      ).catchError((Object error, StackTrace stack) {
        debugPrint('Rewarded interstitial show request failed: $error');
        finish();
      }),
    );
    return done.future;
  }

  Future<void> showPrivacyOptions() async {
    if (!_supported || _disposed) return;
    final generation = ++_consentGeneration;
    // Do not reuse requests made under the previous consent decision.
    _setConsent(false);
    try {
      final formDone = Completer<void>();
      await ConsentForm.showPrivacyOptionsForm(
        (error) =>
            error == null ? formDone.complete() : formDone.completeError(error),
      );
      await formDone.future.timeout(const Duration(seconds: 10));
    } catch (error, stack) {
      debugPrint('Ad privacy form unavailable: $error');
      debugPrintStack(stackTrace: stack);
    }
    // Recheck even when the form reports an error: consent may have changed.
    try {
      final allowed = await ConsentInformation.instance.canRequestAds().timeout(
        const Duration(seconds: 3),
      );
      if (_disposed || generation != _consentGeneration) return;
      _setConsent(allowed);
      await _refreshPrivacyOptionsRequirement();
      if (_canRequestAds) {
        if (!_initialized) {
          // An older startup attempt may still be unwinding after invalidation.
          await _initializing;
          if (_disposed || generation != _consentGeneration) return;
          await initialize();
        } else {
          _loadInterstitial();
          _loadRewardedInterstitial();
        }
      }
    } catch (error, stack) {
      debugPrint('Ad privacy options unavailable: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> _refreshPrivacyOptionsRequirement() async {
    if (!_supported) return;
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus()
          .timeout(const Duration(seconds: 3));
      if (_disposed) return;
      _privacyOptionsAvailable.value =
          status == PrivacyOptionsRequirementStatus.required;
    } catch (error) {
      debugPrint('AdMob privacy status unavailable: $error');
      if (!_disposed) _privacyOptionsAvailable.value = false;
    }
  }

  @visibleForTesting
  void disposeForTest() {
    _disposed = true;
    _consentGeneration++;
    _setConsent(false);
  }
}

/// One cached ad and one pending request per format and consent generation.
/// Load/dispose functions keep retry and invalidation tests independent of native
/// platform channels; production still uses the official SDK ad objects.
@visibleForTesting
class AdMobInventory<T extends Object> {
  AdMobInventory({
    required this.canLoad,
    required this.load,
    required this.dispose,
  });

  final bool Function() canLoad;
  final Future<void> Function(
    void Function(T) onLoaded,
    void Function(Object) onFailed,
  )
  load;
  final Future<void> Function(T) dispose;
  static const _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];
  T? _ad;
  bool _loading = false;
  int _generation = 0;
  int _failures = 0;
  Timer? _retry;

  bool get ready => _ad != null;

  T? take() {
    final ad = _ad;
    _ad = null;
    return ad;
  }

  void request() {
    if (!canLoad() ||
        _ad != null ||
        _loading ||
        _retry != null ||
        _failures > _retryDelays.length)
      return;
    _loading = true;
    final generation = _generation;
    var settled = false;
    T? delivered;

    void failed(Object error) {
      if (settled || generation != _generation) return;
      settled = true;
      _loading = false;
      debugPrint('Ad inventory load unavailable: $error');
      if (!canLoad()) return;
      _failures++;
      if (_failures > _retryDelays.length) return;
      _retry = Timer(_retryDelays[_failures - 1], () {
        _retry = null;
        request();
      });
    }

    void loaded(T ad) {
      if (settled) {
        if (!identical(ad, delivered)) _dispose(ad);
        return;
      }
      settled = true;
      delivered = ad;
      // Native loads cannot be cancelled. Reject results from old consent.
      if (generation != _generation || !canLoad()) {
        _dispose(ad);
        if (generation == _generation) _loading = false;
        return;
      }
      _loading = false;
      _failures = 0;
      _ad = ad;
    }

    unawaited(
      Future<void>.sync(
        () => load(loaded, failed),
      ).catchError((Object error) => failed(error)),
    );
  }

  void clear() {
    _generation++;
    _retry?.cancel();
    _retry = null;
    _loading = false;
    _failures = 0;
    final ad = take();
    if (ad != null) _dispose(ad);
  }

  void _dispose(T ad) {
    unawaited(
      Future<void>.sync(() => dispose(ad)).catchError((Object error) {
        debugPrint('Ad inventory disposal unavailable: $error');
      }),
    );
  }
}
