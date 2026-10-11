import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sukusukukanji/app/app_controller.dart';
import 'package:sukusukukanji/app/app_shell.dart';
import 'package:sukusukukanji/data/models/learning_access.dart';
import 'package:sukusukukanji/data/models/study_session.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/data/services/course_entitlements.dart';
import 'package:sukusukukanji/data/services/learning_access_policy.dart';
import 'package:sukusukukanji/data/storage/sqlite_progress_repository.dart';
import 'package:sukusukukanji/features/ads/ad_config.dart';
import 'package:sukusukukanji/features/ads/ad_service.dart';
import 'package:sukusukukanji/features/ads/rewarded_lesson_dialog.dart';

import 'test_repositories.dart';

class FakeAds extends AdService {
  RewardedOutcome outcome = RewardedOutcome.earned;
  int rewardedShows = 0, interstitialShows = 0;
  @override
  bool get enabled => true;
  @override
  Future<RewardedOutcome> showRewarded(
    Future<void> Function(String) onEarned,
  ) async {
    rewardedShows++;
    if (outcome == RewardedOutcome.earned) {
      await onEarned('test-reward-$rewardedShows');
    }
    return outcome;
  }

  @override
  Future<bool> showLessonInterstitial() async {
    interstitialShows++;
    return true;
  }
}

class ElementaryPurchase extends CourseEntitlements {
  @override
  bool hasUnlimitedAccess(int grade) => grade <= 6;
  @override
  bool removesAds(int grade) => grade <= 6;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const policy = LearningAccessPolicy();
  final today = DateTime(2026, 10, 11, 10);
  AppController app(
    MemoryProgressRepository progress,
    FakeAds ads, {
    CourseEntitlements? entitlements,
  }) => AppController(
    content: AssetKanjiRepository(),
    progress: progress,
    settings: MemorySettingsRepository(),
    ads: ads,
    entitlements: entitlements,
    now: () => today,
  );
  Future<StudySession> complete(AppController controller) async {
    expect(await controller.prepareNextLesson(), isTrue);
    final session = controller.start()!;
    await controller.saveSession(
      CompletedSession(
        session: session,
        answers: [
          for (final q in session.questions) q.options.indexOf(q.answer),
        ],
        completedAt: today,
      ),
    );
    return session;
  }

  test('two new lessons are free; interrupted lesson reopens without consuming another allowance', () {
    var access = policy.open(LearningAccess(), '1:1', today);
    access = policy.open(access, '1:1', today);
    expect(access.freeUsed, 1);
    access = policy.open(access, '1:2', today);
    expect(policy.canOpen(access, '1:3', today), isFalse);
    expect(() => policy.open(access, '1:3', today), throwsStateError);
    expect(policy.canOpen(access, '1:1', today), isTrue);
  });
  test('reward grants once, credits persist across midnight and free allowance is used first', () {
    var access = policy.open(LearningAccess(), '1:1', today);
    access = policy.open(access, '1:2', today);
    access = policy.grant(access, 'receipt');
    access = policy.grant(access, 'receipt');
    expect(access.rewardCredits, 1);
    final tomorrow = today.add(const Duration(days: 1));
    access = policy.open(access, '1:3', tomorrow);
    expect(access.freeUsed, 1);
    expect(access.rewardCredits, 1);
    access = policy.open(access, '1:4', tomorrow);
    access = policy.open(access, '1:5', tomorrow);
    expect(access.rewardCredits, 0);
    expect(access.rewardedLessons, {'1:5'});
    expect(
      policy.freeRemaining(access, today),
      0,
    ); // No reset by moving clock back.
  });
  test(
    'malformed persisted access is rejected instead of granting free access',
    () {
      final json = LearningAccess().toJson();
      json['day'] = '2026-02-30';
      expect(() => LearningAccess.fromJson(json), throwsFormatException);
    },
  );
  test('controller gates lesson three; review remains free; rewarded lesson skips completion ad', () async {
    final repository = MemoryProgressRepository();
    final ads = FakeAds();
    final controller = app(repository, ads);
    addTearDown(controller.dispose);
    await controller.load();
    final first = await complete(controller);
    await controller.showCompletionAd(first);
    await controller.showCompletionAd(first);
    expect(ads.interstitialShows, 1);
    final second = await complete(controller);
    await controller.showCompletionAd(second);
    expect(controller.needsRewardForNextLesson, isTrue);
    expect(await controller.prepareNextLesson(), isFalse);
    expect(controller.start(), isNull);
    final review = controller.startLessonReview(1, 1)!;
    expect(review.isReview, isTrue);
    await controller.showCompletionAd(review);
    expect(ads.interstitialShows, 2);
    await controller.grantAdReward('rewarded');
    final third = await complete(controller);
    await controller.showCompletionAd(third);
    expect(ads.interstitialShows, 2);
    expect(controller.progress.learningAccess.rewardCredits, 0);
    expect(controller.progress.totalLearned, 15);
  });
  test('future verified elementary entitlement bypasses quota and ads without spending credits', () async {
    final purchased = ElementaryPurchase();
    addTearDown(purchased.dispose);
    final ads = FakeAds();
    final controller = app(
      MemoryProgressRepository(),
      ads,
      entitlements: purchased,
    );
    addTearDown(controller.dispose);
    await controller.load();
    for (var i = 0; i < 3; i++) {
      final session = await complete(controller);
      await controller.showCompletionAd(session);
    }
    expect(ads.interstitialShows, 0);
    expect(controller.showAds, isFalse);
    expect(controller.progress.learningAccess.freeUsed, 0);
    expect(purchased.hasUnlimitedAccess(7), isFalse);
  });
  test(
    'SQLite restores credits and idempotent reward receipts across reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp('ad-access-');
      final path = '${directory.path}/progress.db';
      var repository = SqliteProgressRepository(
        factory: databaseFactoryFfi,
        path: path,
      );
      try {
        await Future.wait(
          List.generate(
            3,
            (_) => repository.update(
              (old) => old.copyWith(
                learningAccess: policy.grant(old.learningAccess, 'one-receipt'),
              ),
            ),
          ),
        );
        await repository.update(
          (old) => old.copyWith(
            learningAccess: policy.open(old.learningAccess, '1:1', today),
          ),
        );
        await repository.close();
        repository = SqliteProgressRepository(
          factory: databaseFactoryFfi,
          path: path,
        );
        final restored = await repository.load();
        expect(restored.learningAccess.rewardCredits, 1);
        expect(restored.learningAccess.freeUsed, 1);
        expect(restored.learningAccess.openedLessons, {'1:1'});
        await repository.update(
          (old) => old.copyWith(
            learningAccess: policy.grant(old.learningAccess, 'one-receipt'),
          ),
        );
        expect((await repository.load()).learningAccess.rewardCredits, 1);
      } finally {
        await repository.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test('v2 database migrates to access ledger while preserving existing favorites and progress', () async {
    final directory = await Directory.systemTemp.createTemp('ad-migration-');
    final path = '${directory.path}/progress.db';
    final repo = SqliteProgressRepository(
      factory: databaseFactoryFfi,
      path: path,
    );
    try {
      await repo.update(
        (p) => p.copyWith(streak: 3, favoriteKanjiIds: {'g1-4e00'}),
      );
      await repo.close();
      final old = await databaseFactoryFfi.openDatabase(path);
      await old.execute('DROP TABLE learning_access');
      await old.setVersion(2);
      await old.close();
      final upgraded = await repo.load();
      expect(upgraded.streak, 3);
      expect(upgraded.favoriteKanjiIds, {'g1-4e00'});
      expect(upgraded.learningAccess.freeUsed, 0);
      expect(upgraded.learningAccess.rewardCredits, 0);
    } finally {
      await repo.close();
      await directory.delete(recursive: true);
    }
  });
  test('failed access write cannot spend a free lesson or start an unauthorized session', () async {
    final repository = MemoryProgressRepository();
    final controller = app(repository, FakeAds());
    addTearDown(controller.dispose);
    await controller.load();
    repository.failWrites = true;
    await expectLater(controller.prepareNextLesson(), throwsStateError);
    expect(controller.start(), isNull);
    expect(controller.freeLessonsRemaining, 2);
  });
  test('configuration uses platform test units and disables unconfigured release and desktop', () {
    final android = AdConfig.resolve(
      platform: TargetPlatform.android,
      web: false,
      release: false,
    );
    final ios = AdConfig.resolve(
      platform: TargetPlatform.iOS,
      web: false,
      release: false,
    );
    expect(android.mode, AdMode.test);
    expect(android.rewarded, endsWith('/5224354917'));
    expect(ios.rewarded, endsWith('/1712485313'));
    expect(
      AdConfig.resolve(
        platform: TargetPlatform.android,
        web: false,
        release: true,
      ).enabled,
      isFalse,
    );
    expect(
      AdConfig.resolve(
        platform: TargetPlatform.linux,
        web: false,
        release: false,
      ).enabled,
      isFalse,
    );
    expect(
      () => AdConfig.resolve(
        platform: TargetPlatform.android,
        web: false,
        release: true,
        requestedMode: 'live',
      ),
      throwsArgumentError,
    );
    expect(
      () => AdConfig.resolve(
        platform: TargetPlatform.android,
        web: false,
        release: false,
        requestedMode: 'live',
      ),
      throwsArgumentError,
    );
  });

  testWidgets(
    'home gates the third lesson and reopens an interrupted rewarded lesson without another ad',
    (tester) async {
      final ads = FakeAds();
      final controller = app(MemoryProgressRepository(), ads);
      addTearDown(controller.dispose);
      await tester.runAsync(() async {
        await controller.load();
        await complete(controller);
        await complete(controller);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: controller,
            builder: (_, _) => AppShell(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('광고 보고 더 배우기'));
      await tester.tap(find.text('광고 보고 더 배우기'));
      await tester.pumpAndSettle();
      expect(find.text('한 레슨 더 배워볼까요?'), findsOneWidget);
      expect(controller.progress.totalLearned, 10);
      await tester.tap(find.text('광고 보고 레슨 1개 열기'));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 한자'), findsOneWidget);
      expect(controller.progress.learningAccess.openedLessons, {
        '1:1',
        '1:2',
        '1:3',
      });
      expect(controller.progress.learningAccess.rewardCredits, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('다음 한자 배우기'));
      await tester.tap(find.text('다음 한자 배우기'));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 한자'), findsOneWidget);
      expect(ads.rewardedShows, 1);
      expect(controller.progress.totalLearned, 10);
      expect(tester.takeException(), isNull);
    },
  );

  for (final outcome in [
    RewardedOutcome.dismissed,
    RewardedOutcome.unavailable,
  ]) {
    testWidgets('$outcome never grants a lesson and offers a safe exit', (
      tester,
    ) async {
      final ads = FakeAds()..outcome = outcome;
      final controller = app(MemoryProgressRepository(), ads);
      addTearDown(controller.dispose);
      await tester.runAsync(controller.load);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => RewardedLessonDialog(controller: controller),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('광고 보고 레슨 1개 열기'));
      await tester.pumpAndSettle();
      expect(controller.progress.learningAccess.rewardCredits, 0);
      expect(find.text('나중에'), findsOneWidget);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  }
  testWidgets(
    'reward storage retry does not replay an ad or grant a duplicate reward at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final ads = FakeAds();
      final repository = MemoryProgressRepository();
      final controller = app(repository, ads);
      addTearDown(controller.dispose);
      await tester.runAsync(controller.load);
      repository.failWrites = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => RewardedLessonDialog(controller: controller),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('광고 보고 레슨 1개 열기'));
      await tester.pumpAndSettle();
      expect(find.text('보상 저장 다시 시도'), findsOneWidget);
      expect(controller.hasPendingReward, isTrue);
      repository.failWrites = false;
      await tester.tap(find.text('보상 저장 다시 시도'));
      await tester.pumpAndSettle();
      expect(controller.progress.learningAccess.rewardCredits, 1);
      expect(ads.rewardedShows, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
