import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sukusukukanji/app/app_controller.dart';
import 'package:sukusukukanji/data/models/study_session.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/data/storage/sqlite_progress_repository.dart';

import 'test_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('production controller commits to real SQLite and reconstructs the next lesson and review queue', () async {
    final directory = await Directory.systemTemp.createTemp('sukusuku-app-');
    final settings = MemorySettingsRepository(onboardingCompleted: false);
    SqliteProgressRepository open() => SqliteProgressRepository(
      factory: databaseFactoryFfi,
      path: '${directory.path}/app.db',
    );
    AppController create(SqliteProgressRepository db) => AppController(
      content: AssetKanjiRepository(),
      progress: db,
      settings: settings,
    );
    var db = open();
    var controller = create(db);
    try {
      await controller.load();
      expect(controller.status, AppStatus.ready);
      await controller.completeOnboarding();
      final session = controller.start()!;
      final completed = CompletedSession(
        session: session,
        completedAt: DateTime(2026, 10, 9),
        answers: [
          for (var i = 0; i < session.questions.length; i++)
            i == 0
                ? (session.questions[i].options.indexOf(
                            session.questions[i].answer,
                          ) +
                          1) %
                      4
                : session.questions[i].options.indexOf(
                    session.questions[i].answer,
                  ),
        ],
      );
      await controller.saveSession(completed);
      controller.dispose();
      await db.close();
      db = open();
      controller = create(db);
      await controller.load();
      expect(controller.settings.onboardingCompleted, isTrue);
      expect(controller.progress.totalLearned, 5);
      expect(controller.progress.streak, 1);
      expect(controller.reviewCount, 1);
      expect(controller.nextLesson.map((k) => k.character).join(), '六七八九十');
      final before = controller.progress.kanji.values.fold(
        0,
        (n, p) => n + p.correctCount,
      );
      await controller.saveSession(completed);
      expect(
        controller.progress.kanji.values.fold(0, (n, p) => n + p.correctCount),
        before,
      );
      for (var round = 0; round < 2; round++) {
        final review = controller.start(review: true)!;
        await controller.saveSession(
          CompletedSession(
            session: review,
            completedAt: DateTime(2026, 10, 9),
            answers: [
              for (final q in review.questions) q.options.indexOf(q.answer),
            ],
          ),
        );
      }
      controller.dispose();
      await db.close();
      db = open();
      controller = create(db);
      await controller.load();
      expect(controller.reviewCount, 0);
      expect(controller.progress.totalLearned, 5);
      expect(controller.progress.completedGrades, isEmpty);
      expect(controller.progress.currentGrade, 1);
    } finally {
      controller.dispose();
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
