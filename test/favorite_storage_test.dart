import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/storage/progress_mapping.dart';
import 'package:sukusukukanji/data/storage/sqlite_progress_repository.dart';

void main() {
  sqfliteFfiInit();
  test('version-one database upgrades without losing progress, graduation or committed sessions; favorites restore after reopen', () async {
    final dir = await Directory.systemTemp.createTemp('favorite-migration-');
    final path = '${dir.path}/old.db';
    final record = KanjiProgress(
      kanjiId: 'g1-4e00',
      correctCount: 3,
      wrongCount: 1,
      needsReview: true,
      firstStudiedAt: DateTime(2026, 10, 9),
    );
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE user_progress (id INTEGER PRIMARY KEY, current_grade INTEGER NOT NULL, streak INTEGER NOT NULL, last_study_date TEXT)',
          );
          await db.execute(
            'CREATE TABLE kanji_progress (kanji_id TEXT PRIMARY KEY, status TEXT NOT NULL, correct_count INTEGER NOT NULL, wrong_count INTEGER NOT NULL, consecutive_correct INTEGER NOT NULL, needs_review INTEGER NOT NULL, first_studied_at TEXT, last_studied_at TEXT)',
          );
          await db.execute(
            'CREATE TABLE grade_completion (grade INTEGER PRIMARY KEY, seen INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE committed_session (id TEXT PRIMARY KEY)',
          );
          await db.insert('user_progress', {
            'id': 1,
            'current_grade': 2,
            'streak': 4,
            'last_study_date': '2026-10-09',
          });
          await db.insert('kanji_progress', ProgressMapping.encode(record));
          await db.insert('grade_completion', {'grade': 1, 'seen': 1});
          await db.insert('committed_session', {'id': 'already-saved'});
        },
      ),
    );
    await legacy.close();
    var repository = SqliteProgressRepository(
      factory: databaseFactoryFfi,
      path: path,
    );
    try {
      final upgraded = await repository.load();
      expect(upgraded.currentGrade, 2);
      expect(upgraded.streak, 4);
      expect(upgraded.kanji[record.kanjiId]!.needsReview, isTrue);
      expect(upgraded.completedGrades, {1});
      expect(upgraded.seenGradeCelebrations, {1});
      expect(upgraded.favoriteKanjiIds, isEmpty);
      await repository.update(
        (old) => old.copyWith(favoriteKanjiIds: {record.kanjiId}),
      );
      await repository.close();
      repository = SqliteProgressRepository(
        factory: databaseFactoryFfi,
        path: path,
      );
      final restored = await repository.load();
      expect(restored.favoriteKanjiIds, {record.kanjiId});
      expect(restored.kanji[record.kanjiId]!.correctCount, 3);
      var called = false;
      await repository.update((old) {
        called = true;
        return old;
      }, sessionId: 'already-saved');
      expect(called, isFalse);
      await repository.update((old) => old.copyWith(favoriteKanjiIds: {}));
      expect((await repository.load()).favoriteKanjiIds, isEmpty);
    } finally {
      await repository.close();
      await dir.delete(recursive: true);
    }
  });
}
