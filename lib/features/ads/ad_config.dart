import 'package:flutter/foundation.dart';

enum AdMode { off, test, live }

class AdConfig {
  const AdConfig({
    required this.mode,
    required this.banner,
    required this.interstitial,
    required this.rewarded,
    this.testConsent = false,
  });
  const AdConfig.off()
    : mode = AdMode.off,
      banner = '',
      interstitial = '',
      rewarded = '',
      testConsent = false;
  final bool testConsent;
  final AdMode mode;
  final String banner, interstitial, rewarded;
  bool get enabled => mode != AdMode.off;

  factory AdConfig.fromEnvironment() => AdConfig.resolve(
    platform: defaultTargetPlatform,
    web: kIsWeb,
    release: kReleaseMode,
    requestedMode: const String.fromEnvironment('ADMOB_MODE'),
    banner: const String.fromEnvironment('ADMOB_BANNER_ID'),
    interstitial: const String.fromEnvironment('ADMOB_INTERSTITIAL_ID'),
    rewarded: const String.fromEnvironment('ADMOB_REWARDED_ID'),
    testConsent: const bool.fromEnvironment('ADMOB_TEST_CONSENT'),
  );

  static AdConfig resolve({
    required TargetPlatform platform,
    required bool web,
    required bool release,
    String requestedMode = '',
    String banner = '',
    String interstitial = '',
    String rewarded = '',
    bool testConsent = false,
  }) {
    if (web ||
        (platform != TargetPlatform.android &&
            platform != TargetPlatform.iOS)) {
      return const AdConfig.off();
    }
    final mode = requestedMode.isEmpty
        ? (release ? 'off' : 'test')
        : requestedMode;
    if (mode == 'off') return const AdConfig.off();
    if (mode == 'test') {
      final android = platform == TargetPlatform.android;
      return AdConfig(
        mode: AdMode.test,
        testConsent: testConsent,
        banner: android
            ? 'ca-app-pub-3940256099942544/6300978111'
            : 'ca-app-pub-3940256099942544/2934735716',
        interstitial: android
            ? 'ca-app-pub-3940256099942544/1033173712'
            : 'ca-app-pub-3940256099942544/4411468910',
        rewarded: android
            ? 'ca-app-pub-3940256099942544/5224354917'
            : 'ca-app-pub-3940256099942544/1712485313',
      );
    }
    if (mode != 'live' || !release) {
      throw ArgumentError(
        'Use test ads in development; live ads require a release build',
      );
    }
    for (final id in [banner, interstitial, rewarded]) {
      if (!RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(id) ||
          id.startsWith('ca-app-pub-3940256099942544/')) {
        throw ArgumentError('Live AdMob mode requires three real ad unit IDs');
      }
    }
    return AdConfig(
      mode: AdMode.live,
      banner: banner,
      interstitial: interstitial,
      rewarded: rewarded,
    );
  }
}
