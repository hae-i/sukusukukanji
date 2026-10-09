import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/app/app.dart';
import 'package:sukusukukanji/app/app_controller.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/models/study_session.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/features/study/study_hub_screen.dart';
import 'package:sukusukukanji/features/study/study_flow_screen.dart';
import 'package:sukusukukanji/features/quiz/quiz_view.dart';
import 'package:sukusukukanji/widgets/page_dots.dart';

import 'test_repositories.dart';

class InteractionContent implements KanjiRepository {
  InteractionContent(this.catalog);
  final KanjiCatalog catalog;
  @override
  Future<KanjiCatalog> load() async => catalog;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KanjiCatalog catalog;
  setUp(() async {
    catalog = await AssetKanjiRepository().load();
  });
  testWidgets('onboarding cards slide both ways with dots and fit large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      SukuSukuApp(
        repository: InteractionContent(catalog),
        progressRepository: MemoryProgressRepository(),
        settingsRepository: MemorySettingsRepository(
          onboardingCompleted: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsOneWidget);
    expect(find.text('1 / 3'), findsNothing);
    expect(tester.widget<PageDots>(find.byType(PageDots)).index, 0);
    await tester.drag(find.byType(PageView), const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageDots>(find.byType(PageDots)).index, 1);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(tester.widget<PageDots>(find.byType(PageDots)).index, 2);
    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(tester.widget<PageDots>(find.byType(PageDots)).index, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'study swipes back without completing, supports favorites, and shows red check feedback',
    (tester) async {
      final app = AppController(
        content: InteractionContent(catalog),
        progress: MemoryProgressRepository(),
        settings: MemorySettingsRepository(),
      );
      addTearDown(app.dispose);
      await app.load();
      final session = app.start()!;
      await tester.pumpWidget(
        MaterialApp(
          home: StudyFlowScreen(
            session: session,
            appController: app,
            onSave: app.saveSession,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('一 즐겨찾기 추가'));
      await tester.pumpAndSettle();
      expect(app.progress.favoriteKanjiIds, {catalog.kanji.first.id});
      expect(app.progress.totalLearned, 0);
      await tester.drag(find.byType(PageView), const Offset(-650, 0));
      await tester.pumpAndSettle();
      expect(find.text('한자 2 / 5'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(650, 0));
      await tester.pumpAndSettle();
      expect(find.text('한자 1 / 5'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(PageView), const Offset(-650, 0));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('퀴즈 시작하기'));
      await tester.tap(find.text('퀴즈 시작하기'));
      await tester.pumpAndSettle();
      final view = tester.widget<QuizView>(find.byType(QuizView));
      final answer = view.controller.question.options.indexOf(
        view.controller.question.answer,
      );
      final choice = find.byKey(ValueKey('option-$answer'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
      expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('✓ 정답이에요!'), findsOneWidget);
      expect(
        find.textContaining('✓ 정답', findRichText: false),
        findsOneWidget,
      ); // Feedback only.
      expect(tester.widget<Icon>(find.byIcon(Icons.check)).color, Colors.red);
      expect(app.progress.totalLearned, 0);
    },
  );
  testWidgets(
    'favorites filter updates immediately and survives app reconstruction',
    (tester) async {
      final progress = MemoryProgressRepository();
      final settings = MemorySettingsRepository();
      Widget create() => SukuSukuApp(
        repository: InteractionContent(catalog),
        progressRepository: progress,
        settingsRepository: settings,
      );
      await tester.pumpWidget(create());
      await tester.pumpAndSettle();
      await tester.tap(find.text('내 한자'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('一 즐겨찾기 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      expect(find.text('一'), findsOneWidget);
      expect(find.text('二'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(create());
      await tester.pumpAndSettle();
      await tester.tap(find.text('내 한자'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('一 즐겨찾기 해제'));
      await tester.pumpAndSettle();
      expect(find.text('별을 눌러 즐겨찾는 한자를 모아 보세요.'), findsOneWidget);
    },
  );
  testWidgets(
    'completed lessons can be reviewed after promotion, later lessons show disabled prerequisite',
    (tester) async {
      final progress = MemoryProgressRepository(
        UserProgress(
          kanji: {
            for (final k in catalog.kanji.take(5))
              k.id: KanjiProgress(
                kanjiId: k.id,
                firstStudiedAt: DateTime(2026, 10, 9),
              ),
          },
        ),
      );
      final app = AppController(
        content: InteractionContent(catalog),
        progress: progress,
        settings: MemorySettingsRepository(),
      );
      addTearDown(app.dispose);
      await app.load();
      int? reviewed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudyHubScreen(
              controller: app,
              onStart: () {},
              onReview: (g, l) {
                reviewed = l;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('복습하기').first);
      expect(reviewed, 1);
      final locked = find.text('Lesson 2 학습 필요');
      await tester.ensureVisible(locked);
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(of: locked, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNull,
      );
      expect(app.startLessonReview(1, 2), isNull);
      final review = app.startLessonReview(1, 1)!;
      expect(review.isReview, isTrue);
      final firstDate =
          app.progress.kanji[catalog.kanji.first.id]!.firstStudiedAt;
      await app.saveSession(
        CompletedSession(
          session: review,
          completedAt: DateTime(2026, 10, 9),
          answers: [
            for (final q in review.questions) q.options.indexOf(q.answer),
          ],
        ),
      );
      expect(app.progress.totalLearned, 5);
      expect(
        app.progress.kanji[catalog.kanji.first.id]!.firstStudiedAt,
        firstDate,
      );
      progress.value = UserProgress(
        currentGrade: 2,
        completedGrades: {1},
        seenGradeCelebrations: {1},
        kanji: {
          for (final k in catalog.kanji)
            k.id: KanjiProgress(kanjiId: k.id, firstStudiedAt: firstDate),
        },
      );
      await app.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudyHubScreen(
              controller: app,
              onStart: () {},
              onReview: (g, l) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1학년 · 한 번에 5자'), findsOneWidget);
      expect(app.startLessonReview(1, 16), isNotNull);
    },
  );
}
