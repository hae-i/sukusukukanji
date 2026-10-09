import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/models/study_session.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/data/services/quiz_generator.dart';
import 'package:sukusukukanji/data/services/session_planner.dart';
import 'package:sukusukukanji/features/study/session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KanjiCatalog catalog;
  setUp(() async {
    catalog = await AssetKanjiRepository().load();
  });
  test(
    'five ordered cards produce eight valid questions covering three kinds',
    () {
      final selected = const SessionPlanner().nextLesson(
        catalog,
        UserProgress(),
        1,
      );
      expect(selected.map((k) => k.character).join(), '一二三四五');
      final questions = QuizGenerator(random: Random(7))
          .generate(selected, catalog.kanji);
      expect(questions.length, 8);
      expect(questions.map((q) => q.kind).toSet(), QuizKind.values.toSet());
      expect(
        questions.map((q) => q.kanjiId).toSet(),
        selected.map((k) => k.id).toSet(),
      );
      for (final q in questions) {
        expect(q.options.toSet().length, 4);
        final pool = switch (q.kind) {
          QuizKind.meaning => catalog.kanji.expand((k) => k.koreanMeanings),
          QuizKind.reading => catalog.kanji.expand(
            (k) => [...k.kunyomi, ...k.onyomi],
          ),
          QuizKind.wordReading => catalog.kanji.expand(
            (k) => k.examples.map((e) => e.reading),
          ),
        };
        expect(q.options.every(pool.contains), isTrue);
      }
    },
  );
  test('quiz cannot offer another valid reading as a wrong answer', () {
    final questions = QuizGenerator(random: Random(1))
        .generate([catalog.kanji[3]], catalog.kanji);
    final reading = questions.singleWhere((q) => q.kind == QuizKind.reading);
    expect(
      reading.options.where((s) => catalog.kanji[3].kunyomi.contains(s)).length,
      1,
    );
  });
  test(
    'session rejects double answers and retries the same completion',
    () async {
      final session = const SessionPlanner().create(
        catalog.kanji.take(5).toList(),
        catalog,
      );
      var attempts = 0;
      final received = <CompletedSession>[];
      final controller = SessionController(
        session,
        save: (completed) async {
          received.add(completed);
          if (attempts++ == 0) throw Exception('disk full');
        },
      );
      addTearDown(controller.dispose);
      for (var i = 0; i < 5; i++) {
        controller.nextCard();
      }
      expect(controller.stage, SessionStage.quiz);
      for (final q in session.questions) {
        controller.answer(q.options.indexOf(q.answer));
        controller.answer((q.options.indexOf(q.answer) + 1) % q.options.length);
        await controller.nextQuestion();
      }
      expect(controller.stage, SessionStage.saveError);
      await controller.persist();
      expect(controller.stage, SessionStage.result);
      expect(controller.completed!.correctCount, 8);
      expect(identical(received[0], received[1]), isTrue);
      await controller.persist();
      expect(attempts, 2);
    },
  );
  test('new lessons exclude completed records, not just seen cards', () {
    final progress = UserProgress(
      kanji: {
        for (final k in catalog.kanji.take(5))
          k.id: KanjiProgress(
            kanjiId: k.id,
            firstStudiedAt: DateTime(2026, 10, 8),
          ),
      },
    );
    expect(
      const SessionPlanner()
          .nextLesson(catalog, progress, 1)
          .map((k) => k.character)
          .join(),
      '六七八九十',
    );
  });
}
