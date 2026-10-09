import 'package:sqflite/sqflite.dart';

import '../models/progress.dart';
import '../repositories/user_repositories.dart';
import 'progress_mapping.dart';

class SqliteProgressRepository implements ProgressRepository {
  SqliteProgressRepository({DatabaseFactory? factory, this.path})
    : _factory = factory ?? databaseFactory;
  final DatabaseFactory _factory;
  final String? path;
  Future<Database>? _opening;

  Future<Database> _database() async {
    // Failed opens can be retried, including after insufficient disk space.
    try {
      return await (_opening ??= _open());
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final dbPath =
        path ?? '${await _factory.getDatabasesPath()}/sukusukukanji.db';
    return _factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE user_progress (id INTEGER PRIMARY KEY CHECK(id = 1), current_grade INTEGER NOT NULL, streak INTEGER NOT NULL, last_study_date TEXT)',
          );
          await db.insert('user_progress', {
            'id': 1,
            'current_grade': 1,
            'streak': 0,
          });
          await db.execute(
            'CREATE TABLE kanji_progress (kanji_id TEXT PRIMARY KEY, status TEXT NOT NULL, correct_count INTEGER NOT NULL CHECK(correct_count >= 0), wrong_count INTEGER NOT NULL CHECK(wrong_count >= 0), consecutive_correct INTEGER NOT NULL CHECK(consecutive_correct >= 0), needs_review INTEGER NOT NULL CHECK(needs_review IN (0,1)), first_studied_at TEXT, last_studied_at TEXT)',
          );
          await db.execute(
            'CREATE TABLE grade_completion (grade INTEGER PRIMARY KEY, seen INTEGER NOT NULL CHECK(seen IN (0,1)))',
          );
          await db.execute(
            'CREATE TABLE kanji_favorite (kanji_id TEXT PRIMARY KEY)',
          );
          await db.execute(
            'CREATE TABLE committed_session (id TEXT PRIMARY KEY)',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'CREATE TABLE kanji_favorite (kanji_id TEXT PRIMARY KEY)',
            );
          }
        },
        // Never silently delete user progress on a downgrade.
        onDowngrade: (db, oldVersion, newVersion) async {
          throw StateError('This learning database needs a newer app');
        },
      ),
    );
  }

  Future<UserProgress> _read(DatabaseExecutor db) async {
    final userRows = await db.query('user_progress', where: 'id = 1');
    if (userRows.length != 1) {
      throw const FormatException('Missing user progress');
    }
    final user = userRows.single;
    final rows = await db.query('kanji_progress');
    final grades = await db.query('grade_completion');
    final favorites = await db.query('kanji_favorite');
    final date = user['last_study_date'] as String?;
    return UserProgress(
      favoriteKanjiIds: favorites.map((r) => r['kanji_id'] as String).toSet(),
      currentGrade: user['current_grade'] as int,
      streak: user['streak'] as int,
      lastStudyDate: date == null ? null : DateTime.parse(date),
      kanji: {
        for (final row in rows)
          row['kanji_id'] as String: ProgressMapping.decode(row),
      },
      completedGrades: grades.map((g) => g['grade'] as int).toSet(),
      seenGradeCelebrations: grades
          .where((g) => g['seen'] == 1)
          .map((g) => g['grade'] as int)
          .toSet(),
    );
  }

  @override
  Future<UserProgress> load() async => (await _database()).transaction(_read);

  @override
  Future<UserProgress> update(
    UserProgress Function(UserProgress) change, {
    String? sessionId,
  }) async {
    final db = await _database();
    return db.transaction((txn) async {
      final old = await _read(txn);
      if (sessionId != null &&
          (await txn.query(
            'committed_session',
            where: 'id = ?',
            whereArgs: [sessionId],
          )).isNotEmpty) {
        return old;
      }
      final next = change(old);
      if (next.currentGrade < 1 ||
          next.streak < 0 ||
          !next.completedGrades.containsAll(next.seenGradeCelebrations)) {
        throw ArgumentError('Invalid user progress');
      }
      await txn.update('user_progress', {
        'current_grade': next.currentGrade,
        'streak': next.streak,
        'last_study_date': next.lastStudyDate?.toIso8601String(),
      }, where: 'id = 1');
      // Small MVP snapshot in one transaction. No partial session can survive.
      await txn.delete('kanji_progress');
      for (final record in next.kanji.values) {
        await txn.insert('kanji_progress', ProgressMapping.encode(record));
      }
      await txn.delete('kanji_favorite');
      for (final id in next.favoriteKanjiIds) {
        await txn.insert('kanji_favorite', {'kanji_id': id});
      }
      await txn.delete('grade_completion');
      for (final grade in next.completedGrades) {
        await txn.insert('grade_completion', {
          'grade': grade,
          'seen': next.seenGradeCelebrations.contains(grade) ? 1 : 0,
        });
      }
      if (sessionId != null) {
        await txn.insert('committed_session', {'id': sessionId});
      }
      return next;
    });
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) await (await opening).close();
    _opening = null;
  }
}
