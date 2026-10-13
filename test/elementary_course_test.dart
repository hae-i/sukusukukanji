import 'dart:convert';
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
  test('six elementary grades match the official allocation and selected reading evidence', () async {
    final catalog = await AssetKanjiRepository().load();
    final audit = jsonDecode(
      File('docs/content/elementary-audit.json').readAsStringSync(),
    ) as Map;
    final reviewed = {
      for (final k in audit['kanji'] as List) k['character']: k as Map,
    };
    const counts = [80, 160, 200, 202, 193, 191];
    const lessons = [16, 32, 40, 41, 39, 39];
    for (var grade = 1; grade <= 6; grade++) {
      final items = catalog.forGrade(grade);
      expect(items.length, counts[grade - 1]);
      final official = (audit['officialGrades']['$grade'] as String)
          .split('')
          .toSet();
      expect(items.map((k) => k.character).toSet(), official);
      final course = catalog.lessonsForGrade(grade);
      expect(course.length, lessons[grade - 1]);
      expect(
        course.values.take(course.length - 1).every((k) => k.length == 5),
        isTrue,
      );
      for (final k in items.where((k) => k.grade > 1)) {
        final evidence = reviewed[k.character]!;
        final readings = {
          for (final r in evidence['officialReadings'] as List) r['reading'],
        };
        expect(readings.containsAll([...k.onyomi, ...k.kunyomi]), isTrue);
        expect(k.allOnyomi.toSet().containsAll(k.onyomi), isTrue);
        expect(k.allKunyomi.toSet().containsAll(k.kunyomi), isTrue);
        expect(k.koreanReading, evidence['koreanReading']);
        expect(k.koreanMeanings, evidence['koreanMeanings']);
        expect(k.references.length, greaterThanOrEqualTo(3));
        expect(k.sentences, isEmpty);
        expect(k.examples.every((e) => e.word.contains(k.character)), isTrue);
      }
    }
    for (final pair in {
      '芸': '예',
      '台': '대',
      '予': '예',
      '欠': '결',
      '担': '담',
    }.entries) {
      expect(
        catalog.kanji.singleWhere((k) => k.character == pair.key).koreanReading,
        pair.value,
      );
    }
    expect(catalog.forGrade(7), isEmpty);
  });

  test('207 real lessons graduate all elementary grades, preserve partial lessons and reopen SQLite', () async {
    final directory = await Directory.systemTemp.createTemp(
      'elementary-course-',
    );
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
      var sessions = 0;
      var total = 0;
      for (var grade = 1; grade <= 6; grade++) {
        final lessons = app.catalog!.lessonsForGrade(grade);
        for (final lesson in lessons.entries) {
          final session = app.start()!;
          expect(session.kanji.map((k) => k.id), lesson.value.map((k) => k.id));
          expect(
            session.questions.map((q) => q.kanjiId).toSet(),
            session.kanji.map((k) => k.id).toSet(),
          );
          expect(session.questions.length, lessThanOrEqualTo(8));
          for (final q in session.questions) {
            expect(q.options.toSet().length, q.options.length);
            expect(q.options.where((o) => o == q.answer).length, 1);
          }
          await app.saveSession(
            CompletedSession(
              session: session,
              completedAt: DateTime(2026, 10, 13),
              answers: [
                for (final q in session.questions) q.options.indexOf(q.answer),
              ],
            ),
          );
          sessions++;
          total += lesson.value.length;
          expect(app.progress.totalLearned, total);
          if (lesson.key != lessons.keys.last) {
            expect(app.progress.completedGrades.contains(grade), isFalse);
          }
        }
        expect(app.progress.completedGrades, {
          for (var g = 1; g <= grade; g++) g,
        });
        expect(app.progress.currentGrade, grade + 1);
        expect(
          app.settings.icons.unlockedIcons.length,
          grade < 6 ? grade + 1 : 6,
        );
        // Last lessons have 2, 3, and 1 entries; they must still be assessed and saved.
        if (grade >= 4) {
          expect(lessons.values.last.length, {4: 2, 5: 3, 6: 1}[grade]);
        }
        // Resume the next grade from a reopened database, not in-memory state.
        app.dispose();
        await db.close();
        db = open();
        app = create(db);
        await app.load();
        expect(app.progress.totalLearned, total);
        expect(app.progress.currentGrade, grade + 1);
      }
      expect(sessions, 207);
      expect(total, 1026);
      expect(
        app.start(),
        isNull,
      ); // Middle school remains source/allocation-only.
      expect(app.startLessonReview(6, 39)!.kanji.length, 1);
    } finally {
      app.dispose();
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
