import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sukusukukanji/app/app_controller.dart';
import 'package:sukusukukanji/data/models/study_session.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/data/services/quiz_generator.dart';
import 'package:sukusukukanji/data/storage/sqlite_progress_repository.dart';

import 'test_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('sixteen real lessons graduate grade one, keep reviews and restore rewards after SQLite reopen', () async {
    final directory = await Directory.systemTemp.createTemp('full-course-');
    final settings = MemorySettingsRepository();
    SqliteProgressRepository open() => SqliteProgressRepository(
      factory: databaseFactoryFfi,
      path: '${directory.path}/progress.db',
    );
    AppController create(SqliteProgressRepository db) => AppController(
      content: AssetKanjiRepository(),
      progress: db,
      settings: settings,
    );
    var db = open();
    var app = create(db);
    try {
      await app.load();
      for (var lesson = 0; lesson < 16; lesson++) {
        final session = app.start()!;
        expect(session.kanji.length, 5);
        expect(session.questions.length, inInclusiveRange(5, 8));
        await app.saveSession(
          CompletedSession(
            session: session,
            completedAt: DateTime(2026, 10, 9),
            answers: [
              for (var i = 0; i < session.questions.length; i++)
                lesson == 0 && i == 0
                    ? (session.questions[i].options.indexOf(
                                session.questions[i].answer,
                              ) +
                              1) %
                          session.questions[i].options.length
                    : session.questions[i].options.indexOf(
                        session.questions[i].answer,
                      ),
            ],
          ),
        );
        if (lesson < 15) expect(app.progress.completedGrades, isEmpty);
      }
      expect(app.progress.totalLearned, 80);
      expect(app.progress.completedGrades, {1});
      expect(app.progress.currentGrade, 2);
      expect(app.start(), isNull);
      expect(app.reviewCount, 1);
      expect(app.settings.icons.unlockedIcons, {'grade1', 'grade2'});
      expect(app.settings.icons.selectedIcon, 'grade1');
      await app.acknowledgeGraduation(1);
      expect(await app.selectIcon('grade2'), isFalse);
      await app.acknowledgeIcon('grade2');
      app.dispose();
      await db.close();
      db = open();
      app = create(db);
      await app.load();
      expect(app.progress.totalLearned, 80);
      expect(app.settings.icons.selectedIcon, 'grade2');
      expect(app.pendingGraduations, isEmpty);
      expect(app.pendingIconRewards, isEmpty);
      expect(app.start(review: true), isNotNull);
    } finally {
      app.dispose();
      await db.close();
      await directory.delete(recursive: true);
    }
  });
  test('the bundled eighty-character set matches the MEXT grade-one list', () async {
    final catalog = await AssetKanjiRepository().load();
    // MEXT, https://www.mext.go.jp/a_menu/shotou/cs/1319951.htm
    const official =
        '一右雨円王音下火花貝学気九休玉金空月犬見口校左三山子四糸字耳七車手十出女小上森人水正生青夕石赤千川先早草足村大男竹中虫町天田土二日入年白八百文木本名目立力林六五';
    expect(
      catalog.forGrade(1).map((k) => k.character).toSet(),
      official.split('').toSet(),
    );
  });
  test(
    'alternate sourced readings never become incorrect quiz choices',
    () async {
      final catalog = await AssetKanjiRepository().load();
      for (var seed = 0; seed < 10; seed++) {
        for (final kanji in catalog.kanji) {
          final questions = QuizGenerator(random: Random(seed))
              .generate([kanji], catalog.kanji);
          for (final q in questions.where((q) => q.kind == QuizKind.meaning)) {
            final synonyms = catalog.kanji
                .where((k) => k.meaningTags.any(kanji.meaningTags.contains))
                .expand((k) => k.koreanMeanings)
                .toSet();
            expect(
              q.options.where((v) => v != q.answer && synonyms.contains(v)),
              isEmpty,
              reason: kanji.character,
            );
          }
          for (final q in questions.where((q) => q.kind == QuizKind.reading)) {
            final accepted = kanji.kunyomi.isNotEmpty
                ? {...kanji.kunyomi, ...kanji.allKunyomi}
                : {...kanji.onyomi, ...kanji.allOnyomi};
            expect(q.options.where(accepted.contains), [
              q.answer,
            ], reason: kanji.character);
          }
        }
      }
    },
  );
}
