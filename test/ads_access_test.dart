import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sukusukukanji/app/app_controller.dart';
import 'package:sukusukukanji/app/app_shell.dart';
import 'package:sukusukukanji/data/models/learning_access.dart';
import 'package:sukusukukanji/data/models/kanji.dart';
import 'package:sukusukukanji/data/models/progress.dart';
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

/// Test-only later-course fixture. Reuses verified facts without publishing
/// grade 1 characters as real grade 2 content.
class LaterGradeRepository implements KanjiRepository {
  @override
  Future<KanjiCatalog> load() async {
    final catalog = await AssetKanjiRepository().load();
    final json = jsonDecode(
      await rootBundle.loadString('assets/data/kanji/grade1.json'),
    ) as Map<String, dynamic>;
    return KanjiCatalog(
      grades: catalog.grades,
      kanji: [
        for (final item in json['kanji'] as List)
          Kanji.fromJson({...item as Map<String, dynamic>, 'grade': 2}),
      ],
    );
  }
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
    bool gradeOneTrial = false,
  }) {
    final settings = MemorySettingsRepository();
    if (!gradeOneTrial) {
      progress.value = progress.value.copyWith(
        currentGrade: 2,
        completedGrades: {1},
        seenGradeCelebrations: {1},
      );
      settings.value = AppSettings(
        onboardingCompleted: true,
        icons: AppIconPreferences(
          unlockedIcons: {'grade1', 'grade2'},
          seenUnlockModals: {'grade2'},
        ),
      );
    }
    return AppController(
      content: gradeOneTrial ? AssetKanjiRepository() : LaterGradeRepository(),
      progress: progress,
      settings: settings,
      ads: ads,
      entitlements: entitlements,
      now: () => today,
    );
  }

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
    var access = policy.open(LearningAccess(), '2:1', today);
    access = policy.open(access, '2:1', today);
    expect(access.freeUsed, 1);
    access = policy.open(access, '2:2', today);
    expect(policy.canOpen(access, '2:3', today), isFalse);
    expect(() => policy.open(access, '2:3', today), throwsStateError);
    expect(policy.canOpen(access, '2:1', today), isTrue);
  });
  test('reward grants once, credits persist across midnight and free allowance is used first', () {
    var access = policy.open(LearningAccess(), '2:1', today);
    access = policy.open(access, '2:2', today);
    access = policy.grant(access, 'receipt');
    access = policy.grant(access, 'receipt');
    expect(access.rewardCredits, 1);
    final tomorrow = today.add(const Duration(days: 1));
    access = policy.open(access, '2:3', tomorrow);
    expect(access.freeUsed, 1);
    expect(access.rewardCredits, 1);
    access = policy.open(access, '2:4', tomorrow);
    access = policy.open(access, '2:5', tomorrow);
    expect(access.rewardCredits, 0);
    expect(access.rewardedLessons, {'2:5'});
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
    final review = controller.startLessonReview(2, 1)!;
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
  test('first 10 grade 1 lessons remain free with ads enabled and an exhausted allowance', () async {
    final access = LearningAccess(
      day: policy.dayKey(today),
      freeUsed: 2,
      rewardCredits: 1,
      openedLessons: {'1:1', '1:2'},
      grantedRewards: {'existing-reward'},
    );
    final repository = MemoryProgressRepository(
      UserProgress(learningAccess: access),
    );
    var ads = FakeAds();
    var controller = app(repository, ads, gradeOneTrial: true);
    addTearDown(() => controller.dispose());
    await controller.load();
    for (var i = 0; i < 10; i++) {
      expect(controller.accessLimitsEnabled, isFalse);
      expect(controller.needsRewardForNextLesson, isFalse);
      final session = await complete(controller);
      await controller.showCompletionAd(session);
      if (i == 2) {
        expect(ads.interstitialShows, 0);
        expect(ads.rewardedShows, 0);
        controller.dispose();
        ads = FakeAds();
        controller = app(repository, ads, gradeOneTrial: true);
        await controller.load();
      }
    }
    expect(controller.progress.totalLearned, 50);
    expect(controller.progress.completedGrades, isEmpty);
    expect(controller.currentGrade.grade, 1);
    expect(ads.interstitialShows, 0);
    expect(ads.rewardedShows, 0);
    expect(controller.progress.learningAccess.toJson(), access.toJson());
    expect(controller.showAds, isTrue); // Banners are retained.
    expect(controller.accessLimitsEnabled, isTrue);
    final eleventh = await complete(controller); // Existing credit is now used.
    await controller.showCompletionAd(eleventh);
    expect(controller.progress.learningAccess.rewardCredits, 0);
    expect(ads.interstitialShows, 0); // Rewarded lessons skip interstitials.
    expect(controller.needsRewardForNextLesson, isTrue);
    expect(await controller.prepareNextLesson(), isFalse);
  });

  testWidgets(
    'grade 1 home hides daily quota and rewarded entry after two lessons',
    (tester) async {
      final controller = app(
        MemoryProgressRepository(),
        FakeAds(),
        gradeOneTrial: true,
      );
      addTearDown(controller.dispose);
      await tester.runAsync(() async {
        await controller.load();
        await complete(controller);
        await complete(controller);
      });
      await tester.pumpWidget(
        MaterialApp(home: AppShell(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('오늘 무료 레슨'), findsNothing);
      expect(find.text('광고 보고 더 배우기'), findsNothing);
      await tester.ensureVisible(find.text('다음 한자 배우기'));
      await tester.tap(find.text('다음 한자 배우기'));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 한자'), findsOneWidget);
      expect(find.byType(RewardedLessonDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'elementary purchase bypasses quota but retains banners and completion ads',
    () async {
      final purchased = CourseEntitlements(
        verifiedProducts: {CourseProduct.elementary},
      );
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
      expect(ads.interstitialShows, 3);
      expect(controller.showAds, isTrue);
      expect(controller.progress.learningAccess.freeUsed, 0);
      expect(purchased.hasUnlimitedAccess(7), isFalse);
    },
  );
  test(
    'lesson 11 starts the daily allowance and lesson 13 requires a reward',
    () async {
      final ads = FakeAds();
      final controller = app(
        MemoryProgressRepository(),
        ads,
        gradeOneTrial: true,
      );
      addTearDown(controller.dispose);
      await controller.load();
      for (var i = 0; i < 10; i++) {
        await complete(controller);
      }
      expect(controller.progress.learningAccess.freeUsed, 0);
      for (var i = 0; i < 2; i++) {
        final session = await complete(controller);
        await controller.showCompletionAd(session);
      }
      expect(ads.interstitialShows, 2);
      expect(controller.progress.learningAccess.freeUsed, 2);
      expect(controller.needsRewardForNextLesson, isTrue);
      expect(await controller.prepareNextLesson(), isFalse);
      expect(controller.startLessonReview(1, 10), isNotNull);
    },
  );
  test(
    'only the all-course bundle removes ads and prices match the selected plan',
    () {
      for (final product in CourseProduct.values) {
        final rights = CourseEntitlements(verifiedProducts: {product});
        addTearDown(rights.dispose);
        expect(rights.hasUnlimitedAccess(1), product != CourseProduct.middle);
        expect(
          rights.hasUnlimitedAccess(9),
          product != CourseProduct.elementary,
        );
        expect(rights.removesAds(1), product == CourseProduct.allAdFree);
        expect(rights.removesAds(9), product == CourseProduct.allAdFree);
      }
      expect(CourseProduct.elementary.plannedPriceKrw, 5500);
      expect(CourseProduct.middle.plannedPriceKrw, 6600);
      expect(CourseProduct.allAdFree.plannedPriceKrw, 12100);
    },
  );
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
            learningAccess: policy.open(old.learningAccess, '2:1', today),
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
        expect(restored.learningAccess.openedLessons, {'2:1'});
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
        '2:1',
        '2:2',
        '2:3',
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
