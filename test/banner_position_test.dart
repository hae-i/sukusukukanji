import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:sukusukukanji/app/app_controller.dart';
import 'package:sukusukukanji/app/app_shell.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/features/ads/ad_banner.dart';
import 'package:sukusukukanji/features/ads/ad_config.dart';
import 'package:sukusukukanji/features/ads/admob_service.dart';

import 'test_repositories.dart';

class BannerService extends AdMobService {
  BannerService()
    : super(
        const AdConfig(
          mode: AdMode.test,
          banner: 'test-banner',
          interstitial: '',
          rewarded: '',
        ),
      );
  bool allowed = true;
  @override
  bool get canRequestAds => allowed;
  @override
  Future<void> initialize() async {}
  void disable() {
    allowed = false;
    notifyListeners();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'loaded banner sits below tabs at the bottom safe edge, with no duplicate inset',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      int? adId;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        instanceManager.channel,
        (call) async {
          if (call.method == 'loadBannerAd') {
            adId = call.arguments['adId'] as int;
            expect((call.arguments['size'] as AdSize).height, 50);
          }
          return null;
        },
      );
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async {
          if (call.method == 'resize') return {'width': 320.0, 'height': 50.0};
          return null;
        },
      );
      final service = BannerService();
      final controller = AppController(
        content: AssetKanjiRepository(),
        progress: MemoryProgressRepository(),
        settings: MemorySettingsRepository(),
        ads: service,
      );
      addTearDown(() {
        controller.dispose();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          instanceManager.channel,
          null,
        );
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        );
      });
      await tester.runAsync(controller.load);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: AppShell(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(adId, isNotNull);
      final event = Completer<void>();
      binding.channelBuffers.push(
        instanceManager.channel.name,
        instanceManager.channel.codec.encodeMethodCall(
          MethodCall('onAdEvent', {'adId': adId, 'eventName': 'onAdLoaded'}),
        ),
        (_) => event.complete(),
      );
      await event.future;
      await tester.pumpAndSettle();
      final banner = tester.getRect(find.byType(AdBanner));
      final navigation = tester.getRect(find.byType(NavigationBar));
      expect(banner.height, 50);
      expect(navigation.bottom, closeTo(banner.top, .01));
      expect(banner.bottom, closeTo(800 - 24, .01));
      service.disable();
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(NavigationBar)).bottom,
        closeTo(800 - 24, .01),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
