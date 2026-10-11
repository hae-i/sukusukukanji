import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Exercise the actual plugin channel codec; no native ad traffic in tests.
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';
import 'package:sukusukukanji/features/ads/ad_config.dart';
import 'package:sukusukukanji/features/ads/ad_service.dart';
import 'package:sukusukukanji/features/ads/admob_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final ump = MethodChannel(
    'plugins.flutter.io/google_mobile_ads/ump',
    StandardMethodCodec(UserMessagingCodec()),
  );
  late AdMobService service;
  late List<String> calls;
  late Map<int, String> adTypes;
  bool consent = false;
  bool earnsReward = true;

  Future<void> event(
    int id,
    String name, [
    Map<String, Object> extra = const {},
  ]) {
    final completed = Completer<void>();
    binding.channelBuffers.push(
      instanceManager.channel.name,
      instanceManager.channel.codec.encodeMethodCall(
        MethodCall('onAdEvent', {'adId': id, 'eventName': name, ...extra}),
      ),
      (_) => completed.complete(),
    );
    return completed.future;
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = [];
    adTypes = {};
    consent = false;
    earnsReward = true;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(ump, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'ConsentInformation#canRequestAds' => consent,
        'ConsentInformation#getPrivacyOptionsRequirementStatus' => 1,
        _ => null,
      };
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      instanceManager.channel,
      (call) async {
        calls.add(call.method);
        if (call.method == 'MobileAds#initialize') {
          return InitializationStatus({});
        }
        if (call.method == 'loadRewardedAd' ||
            call.method == 'loadInterstitialAd') {
          final id = call.arguments['adId'] as int;
          adTypes[id] = call.method;
          await event(id, 'onAdLoaded');
        }
        if (call.method == 'showAdWithoutView') {
          final id = call.arguments['adId'] as int;
          await event(id, 'onAdShowedFullScreenContent');
          if (adTypes[id] == 'loadRewardedAd' && earnsReward) {
            await event(id, 'onRewardedAdUserEarnedReward', {
              'rewardItem': RewardItem(1, 'lesson'),
            });
            await event(id, 'onRewardedAdUserEarnedReward', {
              'rewardItem': RewardItem(1, 'lesson'),
            });
          }
          await event(id, 'onAdDismissedFullScreenContent');
        }
        return null;
      },
    );
  });
  tearDown(() async {
    service.dispose();
    // Finish plugin dispose method calls before removing the test transport.
    await Future<void>.delayed(Duration.zero);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(ump, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      instanceManager.channel,
      null,
    );
    debugDefaultTargetPlatformOverride = null;
  });
  AdMobService liveService() => AdMobService(
    const AdConfig(
      mode: AdMode.live,
      banner: 'ca-app-pub-1234567890123456/1234567890',
      interstitial: 'ca-app-pub-1234567890123456/1234567891',
      rewarded: 'ca-app-pub-1234567890123456/1234567892',
    ),
  );
  AdMobService testService() => AdMobService(
    AdConfig.resolve(
      platform: TargetPlatform.android,
      web: false,
      release: false,
    ),
  );

  test(
    'live mode never initializes or requests ads when UMP disallows requests',
    () async {
      service = liveService();
      await service.initialize();
      expect(service.canRequestAds, isFalse);
      expect(service.privacyOptionsRequired, isTrue);
      expect(calls, isNot(contains('MobileAds#initialize')));
      expect(
        calls.any((c) => c == 'loadRewardedAd' || c == 'loadInterstitialAd'),
        isFalse,
      );
    },
  );
  test('live ad loading follows updated consent and required form, privacy withdrawal clears readiness', () async {
    consent = true;
    service = liveService();
    await service.initialize();
    expect(service.canRequestAds, isTrue);
    expect(
      calls.indexOf('ConsentInformation#requestConsentInfoUpdate'),
      lessThan(calls.indexOf('ConsentInformation#canRequestAds')),
    );
    expect(
      calls.indexOf('UserMessagingPlatform#loadAndShowConsentFormIfRequired'),
      lessThan(calls.indexOf('MobileAds#initialize')),
    );
    consent = false;
    await service.showPrivacyOptions();
    expect(service.canRequestAds, isFalse);
  });
  test(
    'Google demo units initialize without a publisher UMP configuration',
    () async {
      service = testService();
      await service.initialize();
      expect(service.canRequestAds, isTrue);
      expect(calls, contains('loadRewardedAd'));
      expect(
        calls,
        isNot(contains('ConsentInformation#requestConsentInfoUpdate')),
      );
    },
  );
  test('SDK reward callback persists immediately and exactly once; dismissal awaits storage', () async {
    service = testService();
    final started = Completer<void>(), saved = Completer<void>();
    var grants = 0, finished = false;
    final showing = service
        .showRewarded((receipt) async {
          expect(receipt, isNotEmpty);
          grants++;
          started.complete();
          await saved.future;
        })
        .then((outcome) {
          finished = true;
          return outcome;
        });
    await started.future;
    expect(grants, 1);
    expect(finished, isFalse);
    saved.complete();
    expect(await showing, RewardedOutcome.earned);
    expect(grants, 1);
    expect(
      await service.showLessonInterstitial(),
      isFalse,
    ); // No immediate back-to-back ad.
  });
  test('SDK dismissal without earned callback never grants a reward', () async {
    earnsReward = false;
    service = testService();
    var grants = 0;
    expect(
      await service.showRewarded((_) async {
        grants++;
      }),
      RewardedOutcome.dismissed,
    );
    expect(grants, 0);
  });
  test('SDK reward persistence errors reach the retry UI instead of claiming success', () async {
    service = testService();
    await expectLater(
      service.showRewarded((_) async {
        throw StateError('disk full');
      }),
      throwsStateError,
    );
  });
}
