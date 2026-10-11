import 'dart:async';
import 'dart:math';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'ad_service.dart';

class AdMobService extends AdService {
  AdMobService(this.config);
  final AdConfig config;
  bool _disposed = false, _canRequest = false, _privacyRequired = false;
  bool _initializedSdk = false, _showing = false;
  Future<void>? _initializing;
  Future<RewardedAd?>? _rewardLoading;
  Future<InterstitialAd?>? _interstitialLoading;
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  DateTime? _rewardLoadedAt, _interstitialLoadedAt, _lastFullscreen;
  int _generation = 0;
  final _random = Random.secure();

  @override
  bool get enabled => config.enabled;
  @override
  bool get canRequestAds => _canRequest && !_disposed;
  @override
  bool get privacyOptionsRequired => _privacyRequired;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> initialize() async {
    if (!enabled || _disposed) return;
    if (_initializing != null) return _initializing;
    if (_initializedSdk && _canRequest) return;
    _initializing = _initialize();
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    try {
      // Google's demo app IDs have no publisher-configured UMP message.
      // This path requests only Google's demo units; live mode always uses UMP.
      if (config.mode == AdMode.test && !config.testConsent) {
        await MobileAds.instance.initialize();
        if (_disposed) return;
        _initializedSdk = true;
        _canRequest = true;
        _notify();
        unawaited(_loadRewarded());
        unawaited(_loadInterstitial());
        return;
      }
      final updated = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          if (!updated.isCompleted) updated.complete();
        },
        (_) {
          if (!updated.isCompleted) updated.complete();
        },
      );
      await updated.future.timeout(const Duration(seconds: 12));
      if (_disposed) return;
      // Required consent forms must finish before requesting ads.
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      await _refreshConsent();
    } catch (_) {
      // Ads must never prevent the offline app from starting.
      _canRequest = false;
      _notify();
    }
  }

  Future<void> _refreshConsent() async {
    final allowed = await ConsentInformation.instance.canRequestAds();
    final privacy = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    if (_disposed) return;
    _privacyRequired = privacy == PrivacyOptionsRequirementStatus.required;
    _canRequest = allowed;
    if (allowed && !_initializedSdk) {
      await MobileAds.instance.initialize();
      if (_disposed) return;
      _initializedSdk = true;
    }
    _notify();
    if (canRequestAds) {
      unawaited(_loadRewarded());
      unawaited(_loadInterstitial());
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    if (!enabled || _disposed || _showing) return;
    _canRequest = false;
    _generation++;
    _clearCached();
    _notify();
    try {
      FormError? formError;
      await ConsentForm.showPrivacyOptionsForm((error) {
        formError = error;
      });
      await _refreshConsent();
      if (formError != null) throw StateError('Unable to show privacy options');
    } catch (_) {
      _notify();
      rethrow;
    }
  }

  bool _fresh(DateTime? date) =>
      date != null &&
      DateTime.now().difference(date) < const Duration(minutes: 50);

  Future<RewardedAd?> _loadRewarded() async {
    if (!canRequestAds) return null;
    if (_rewarded != null && _fresh(_rewardLoadedAt)) return _rewarded;
    if (_rewardLoading != null) return _rewardLoading;
    _rewarded?.dispose();
    _rewarded = null;
    final generation = _generation;
    final loaded = Completer<RewardedAd?>();
    _rewardLoading = loaded.future;
    try {
      await RewardedAd.load(
        adUnitId: config.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (loaded.isCompleted ||
                !canRequestAds ||
                generation != _generation) {
              ad.dispose();
              if (!loaded.isCompleted) loaded.complete(null);
              return;
            }
            _rewarded = ad;
            _rewardLoadedAt = DateTime.now();
            loaded.complete(ad);
          },
          onAdFailedToLoad: (_) {
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
      return await loaded.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          if (!loaded.isCompleted) loaded.complete(null);
          return null;
        },
      );
    } catch (_) {
      if (!loaded.isCompleted) loaded.complete(null);
      return null;
    } finally {
      _rewardLoading = null;
    }
  }

  Future<InterstitialAd?> _loadInterstitial() async {
    if (!canRequestAds) return null;
    if (_interstitial != null && _fresh(_interstitialLoadedAt)) {
      return _interstitial;
    }
    if (_interstitialLoading != null) return _interstitialLoading;
    _interstitial?.dispose();
    _interstitial = null;
    final generation = _generation;
    final loaded = Completer<InterstitialAd?>();
    _interstitialLoading = loaded.future;
    try {
      await InterstitialAd.load(
        adUnitId: config.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (loaded.isCompleted ||
                !canRequestAds ||
                generation != _generation) {
              ad.dispose();
              if (!loaded.isCompleted) loaded.complete(null);
              return;
            }
            _interstitial = ad;
            _interstitialLoadedAt = DateTime.now();
            loaded.complete(ad);
          },
          onAdFailedToLoad: (_) {
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
      return await loaded.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          if (!loaded.isCompleted) loaded.complete(null);
          return null;
        },
      );
    } catch (_) {
      if (!loaded.isCompleted) loaded.complete(null);
      return null;
    } finally {
      _interstitialLoading = null;
    }
  }

  @override
  Future<RewardedOutcome> showRewarded(
    Future<void> Function(String) onEarned,
  ) async {
    if (_showing || _disposed) return RewardedOutcome.unavailable;
    _showing = true;
    try {
      await initialize();
      final ad = await _loadRewarded();
      if (ad == null || !canRequestAds) return RewardedOutcome.unavailable;
      _rewarded = null;
      final dismissed = Completer<void>();
      var earned = false;
      Object? saveError;
      Future<void>? saving;
      final receipt =
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) {
          _lastFullscreen = DateTime.now();
        },
        onAdDismissedFullScreenContent: (_) {
          ad.dispose();
          if (!dismissed.isCompleted) dismissed.complete();
        },
        onAdFailedToShowFullScreenContent: (_, _) {
          ad.dispose();
          if (!dismissed.isCompleted) dismissed.complete();
        },
      );
      try {
        await ad.show(
          onUserEarnedReward: (_, _) {
            if (earned) return;
            earned = true;
            // Persist on the reward callback, not on dismissal or a timer.
            saving = Future.sync(() => onEarned(receipt))
                .catchError((Object error) {
                  saveError = error;
                });
          },
        );
        await dismissed.future;
        await saving;
        if (saveError != null) throw saveError!;
        return earned ? RewardedOutcome.earned : RewardedOutcome.dismissed;
      } finally {
        ad.dispose();
      }
    } finally {
      _showing = false;
      if (!_disposed) unawaited(_loadRewarded());
    }
  }

  @override
  Future<bool> showLessonInterstitial() async {
    if (!canRequestAds ||
        _showing ||
        (_lastFullscreen != null &&
            DateTime.now().difference(_lastFullscreen!) <
                const Duration(seconds: 90))) {
      return false;
    }
    // Only show an already-loaded ad at the result boundary. Never pop up late.
    final ad = _interstitial;
    if (ad == null || !_fresh(_interstitialLoadedAt)) {
      unawaited(_loadInterstitial());
      return false;
    }
    _interstitial = null;
    _showing = true;
    final closed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _lastFullscreen = DateTime.now();
      },
      onAdDismissedFullScreenContent: (_) {
        if (!closed.isCompleted) closed.complete(true);
      },
      onAdFailedToShowFullScreenContent: (_, _) {
        if (!closed.isCompleted) closed.complete(false);
      },
    );
    try {
      await ad.show();
      return await closed.future;
    } catch (_) {
      return false;
    } finally {
      ad.dispose();
      _showing = false;
      if (!_disposed) unawaited(_loadInterstitial());
    }
  }

  void _clearCached() {
    _rewarded?.dispose();
    _rewarded = null;
    _interstitial?.dispose();
    _interstitial = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _clearCached();
    super.dispose();
  }
}
