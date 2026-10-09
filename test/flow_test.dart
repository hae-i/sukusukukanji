import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/app/app.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/features/quiz/quiz_view.dart';

import 'grade_policy_test.dart' show shortCourse;
import 'test_repositories.dart';

class FixedContent implements KanjiRepository {
  FixedContent(this.catalog);
  final KanjiCatalog catalog;
  @override
  Future<KanjiCatalog> load() async => catalog;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> finishCardsAndQuiz(
  WidgetTester tester,
  int cards, {
  bool missFirst = false,
}) async {
  for (var i = 0; i < cards; i++) {
    await tapText(tester, i == cards - 1 ? '퀴즈 시작하기' : '알겠어요 →');
  }
  var index = 0;
  while (find.byType(QuizView).evaluate().isNotEmpty) {
    final view = tester.widget<QuizView>(find.byType(QuizView));
    final q = view.controller.question;
    final correct = q.options.indexOf(q.answer);
    final chosen = missFirst && index == 0
        ? (correct + 1) % q.options.length
        : correct;
    final option = find.byKey(ValueKey('option-$chosen'));
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(
      find.text(missFirst && index == 0 ? '✕ 아쉬워요!' : '✓ 정답이에요!'),
      findsOneWidget,
    );
    await tapText(
      tester,
      index == view.controller.session.questions.length - 1 ? '결과 보기' : '다음 문제',
    );
    index++;
  }
  expect(find.text('오늘 공부 끝!'), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  late KanjiCatalog catalog;
  setUp(() async {
    catalog = await AssetKanjiRepository().load();
  });

  testWidgets(
    'onboarding, five cards, quiz, result, restart and two successful reviews',
    (tester) async {
      final progress = MemoryProgressRepository();
      final settings = MemorySettingsRepository(onboardingCompleted: false);
      Widget app() => SukuSukuApp(
        repository: FixedContent(catalog),
        progressRepository: progress,
        settingsRepository: settings,
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('한자를 외우지 말고\n연결해서 배워보세요.'), findsOneWidget);
      await tapText(tester, '다음');
      await tapText(tester, '다음');
      await tapText(tester, '1학년 시작하기');
      expect(settings.value.onboardingCompleted, isTrue);
      await tapText(tester, '오늘의 한자 배우기');
      await finishCardsAndQuiz(tester, 5, missFirst: true);
      expect(progress.value.totalLearned, 5);
      expect(progress.value.kanji.values.where((p) => p.needsReview).length, 1);
      expect(find.text('정답 7 / 8'), findsOneWidget);
      await tapText(tester, '오늘은 여기까지');
      expect(find.text('5 / 80자'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('1학년 시작하기'), findsNothing);
      expect(find.text('5 / 80자'), findsOneWidget);
      await tapText(tester, '복습하기');
      await finishCardsAndQuiz(tester, 1);
      expect(progress.value.kanji.values.where((p) => p.needsReview).length, 1);
      await tapText(tester, '한 번 더 복습하기');
      await finishCardsAndQuiz(tester, 1);
      expect(progress.value.kanji.values.any((p) => p.needsReview), isFalse);
      expect(find.text('한 번 더 복습하기'), findsNothing);
      await tapText(tester, '오늘은 여기까지');
      expect(find.text('복습하기'), findsNothing);
      expect(progress.value.totalLearned, 5);
      expect(progress.value.streak, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'abandoned lesson does not record progress and can be restarted',
    (tester) async {
      final progress = MemoryProgressRepository();
      await tester.pumpWidget(
        SukuSukuApp(
          repository: FixedContent(catalog),
          progressRepository: progress,
          settingsRepository: MemorySettingsRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, '오늘의 한자 배우기');
      await tapText(tester, '알겠어요 →');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('학습을 잠시 멈출까요?'), findsOneWidget);
      await tapText(tester, '나가기');
      expect(progress.value.totalLearned, 0);
      await tapText(tester, '오늘의 한자 배우기');
      expect(find.text('한자 1 / 5'), findsOneWidget);
    },
  );

  testWidgets('failed onboarding save stays on onboarding with retry', (
    tester,
  ) async {
    final settings = MemorySettingsRepository(onboardingCompleted: false)
      ..failWrites = true;
    await tester.pumpWidget(
      SukuSukuApp(
        repository: FixedContent(catalog),
        progressRepository: MemoryProgressRepository(),
        settingsRepository: settings,
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, '다음');
    await tapText(tester, '다음');
    await tapText(tester, '1학년 시작하기');
    expect(settings.value.onboardingCompleted, isFalse);
    expect(find.text('시작 설정을 저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    settings.failWrites = false;
    await tapText(tester, '1학년 시작하기');
    expect(find.text('오늘도 한자 5분만!'), findsOneWidget);
  });

  testWidgets(
    'save failure preserves quiz answers and result appears only after retry',
    (tester) async {
      final progress = MemoryProgressRepository()..failWrites = true;
      await tester.pumpWidget(
        SukuSukuApp(
          repository: FixedContent(catalog),
          progressRepository: progress,
          settingsRepository: MemorySettingsRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, '오늘의 한자 배우기');
      for (var i = 0; i < 5; i++) {
        await tapText(tester, i == 4 ? '퀴즈 시작하기' : '알겠어요 →');
      }
      for (var i = 0; i < 8; i++) {
        final q = tester
            .widget<QuizView>(find.byType(QuizView))
            .controller
            .question;
        final option = find.byKey(
          ValueKey('option-${q.options.indexOf(q.answer)}'),
        );
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        await tapText(tester, i == 7 ? '결과 보기' : '다음 문제');
      }
      expect(find.text('저장 다시 시도'), findsOneWidget);
      expect(progress.value.totalLearned, 0);
      progress.failWrites = false;
      await tapText(tester, '저장 다시 시도');
      expect(find.text('정답 8 / 8'), findsOneWidget);
      expect(progress.value.totalLearned, 5);
      expect(progress.sessions.length, 1);
    },
  );

  testWidgets(
    'manual review from detail updates filter and survives app reconstruction',
    (tester) async {
      final progress = MemoryProgressRepository();
      final settings = MemorySettingsRepository();
      Widget app() => SukuSukuApp(
        repository: FixedContent(catalog),
        progressRepository: progress,
        settingsRepository: settings,
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tapText(tester, '내 한자');
      await tapText(tester, '一');
      await tapText(tester, '복습에 추가');
      expect(find.text('복습에 추가됨'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tapText(tester, '헷갈리는 한자');
      expect(find.text('一'), findsOneWidget);
      expect(find.text('二'), findsNothing);
      expect(progress.value.totalLearned, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('헷갈리는 한자 1개'), findsOneWidget);
    },
  );

  testWidgets(
    'grade completion celebrates after result, unlocks preparation screen and is acknowledged once',
    (tester) async {
      final fixture = shortCourse(catalog);
      final progress = MemoryProgressRepository(
        UserProgress(
          kanji: {
            for (final k in catalog.kanji.take(9))
              k.id: KanjiProgress(
                kanjiId: k.id,
                firstStudiedAt: DateTime(2026, 10, 8),
              ),
          },
        ),
      );
      final settings = MemorySettingsRepository();
      Widget app() => SukuSukuApp(
        repository: FixedContent(fixture),
        progressRepository: progress,
        settingsRepository: settings,
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tapText(tester, '오늘의 한자 배우기');
      await finishCardsAndQuiz(tester, 1);
      expect(find.text('1학년을 졸업했어요!'), findsNothing);
      await tapText(tester, '오늘은 여기까지');
      expect(find.text('1학년을 졸업했어요!'), findsOneWidget);
      expect(progress.value.currentGrade, 2);
      expect(progress.value.completedGrades, {1});
      await tapText(tester, '성장 과정 보기');
      expect(find.text('새로운 아이콘이 열렸어요!'), findsOneWidget);
      await tapText(tester, '나중에');
      expect(find.text('해금됨 · 콘텐츠 준비 중'), findsOneWidget);
      expect(progress.value.seenGradeCelebrations, {1});
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('1학년을 졸업했어요!'), findsNothing);
      expect(find.text('2학년'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
