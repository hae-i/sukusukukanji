import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/app/theme/app_theme.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/data/services/session_planner.dart';
import 'package:sukusukukanji/features/quiz/quiz_view.dart';
import 'package:sukusukukanji/features/study/session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KanjiCatalog catalog;
  setUpAll(() async => catalog = await AssetKanjiRepository().load());

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'feedback overlays options at viewport bottom and next works without scrolling at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final session = const SessionPlanner().create(
          catalog.kanji.take(5).toList(),
          catalog,
        );
        final controller = SessionController(session, save: (_) async {});
        addTearDown(controller.dispose);
        for (var i = 0; i < 5; i++) {
          controller.nextCard();
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              appBar: AppBar(title: const Text('오늘의 한자')),
              body: SafeArea(
                bottom: false,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (_, _) => QuizView(controller: controller),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Exercise both correct and wrong feedback with an unchanged next-button position.
        for (var step = 0; step < 2; step++) {
          final answer = controller.question.options.indexOf(
            controller.question.answer,
          );
          final choice = find.byKey(
            ValueKey(
              'option-${step == 0 ? answer : (answer + 1) % controller.question.options.length}',
            ),
          );
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pump();
          final positions = <double>[];
          for (var frame = 0; frame < 8; frame++) {
            await tester.pump(const Duration(milliseconds: 60));
            positions.add(
              tester
                  .getTopLeft(find.byKey(const ValueKey('quiz-feedback-panel')))
                  .dy,
            );
          }
          await tester.pumpAndSettle();
          final panel = tester.getRect(
            find.byKey(const ValueKey('quiz-feedback-panel')),
          );
          final viewport = tester.getRect(find.byType(QuizView));
          expect(panel.bottom, closeTo(viewport.bottom, .01));
          expect(panel.bottom, closeTo(568, .01));
          for (var frame = 0; frame < positions.length; frame++) {
            expect(positions[frame], greaterThanOrEqualTo(panel.top - .01));
            if (frame > 0) {
              expect(
                positions[frame],
                lessThanOrEqualTo(positions[frame - 1] + .01),
              );
            }
          }
          expect(panel.width, closeTo(viewport.width, .01));
          // The sheet actually covers options instead of reserving space below them.
          expect(
            List.generate(
              controller.question.options.length,
              (i) => tester.getRect(find.byKey(ValueKey('option-$i'))),
            ).any(panel.overlaps),
            isTrue,
          );
          expect(find.text(step == 0 ? '✓ 정답이에요!' : '✕ 아쉬워요!'), findsOneWidget);
          expect(find.text('다음 문제').hitTestable(), findsOneWidget);
          final button = tester.getRect(
            find.widgetWithText(FilledButton, '다음 문제'),
          );
          expect(button.bottom, lessThanOrEqualTo(viewport.bottom - 24));
          await tester.tap(find.text('다음 문제'));
          await tester.pumpAndSettle();
          expect(controller.questionIndex, step + 1);
          expect(
            find.byKey(const ValueKey('quiz-feedback-panel')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
