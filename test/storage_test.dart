import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/storage/sqlite_progress_repository.dart';
import 'package:sukusukukanji/data/storage/preferences_settings_repository.dart';
import 'package:sukusukukanji/data/storage/progress_mapping.dart';

class TestPreferences implements SharedPreferencesAsync {
  final values = <String, String>{};
  bool get failWrites => values['test.fail'] == 'true';
  set failWrites(bool value) => values['test.fail'] = value.toString();
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('disk full');
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late SqliteProgressRepository repository;
  SqliteProgressRepository open() => SqliteProgressRepository(
    factory: databaseFactoryFfi,
    path: '${directory.path}/learning.db',
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sukusuku-db-');
    repository = open();
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test('real SQLite file restores all progress fields and grade acknowledgment after close/reopen', () async {
    final date = DateTime(2026, 10, 8, 12);
    final record = KanjiProgress(
      kanjiId: 'g1-4e00',
      status: KanjiMasteryStatus.learning,
      correctCount: 4,
      wrongCount: 2,
      consecutiveCorrect: 1,
      needsReview: true,
      firstStudiedAt: date,
      lastStudiedAt: date.add(const Duration(days: 1)),
    );
    await repository.update(
      (_) => UserProgress(
        currentGrade: 2,
        streak: 3,
        lastStudyDate: DateTime(2026, 10, 9),
        kanji: {record.kanjiId: record},
        completedGrades: {1},
        seenGradeCelebrations: {1},
      ),
    );
    await repository.close();
    repository = open();
    final read = await repository.load();
    expect(read.currentGrade, 2);
    expect(read.streak, 3);
    expect(read.totalLearned, 1);
    expect(read.completedGrades, {1});
    expect(read.seenGradeCelebrations, {1});
    expect(read.lastStudyDate, DateTime(2026, 10, 9));
    expect(
      ProgressMapping.encode(read.kanji[record.kanjiId]!),
      ProgressMapping.encode(record),
    );
  });
  test('session IDs survive reopen; retry is a no-op even after uncertain acknowledgment', () async {
    await repository.update(
      (p) => p.copyWith(streak: p.streak + 1),
      sessionId: 'same-session',
    );
    await repository.close();
    repository = open();
    final next = await repository.update(
      (p) => p.copyWith(streak: p.streak + 1),
      sessionId: 'same-session',
    );
    expect(next.streak, 1);
  });
  test('a mid-transaction SQLite constraint failure rolls back user, records and session ID', () async {
    await expectLater(
      repository.update(
        (p) => p.copyWith(
          streak: 7,
          kanji: {
            'invalid': const KanjiProgress(
              kanjiId: 'invalid',
              correctCount: -1,
            ),
          },
        ),
        sessionId: 'retryable',
      ),
      throwsA(isA<DatabaseException>()),
    );
    final read = await repository.load();
    expect(read.streak, 0);
    expect(read.kanji, isEmpty);
    final retry = await repository.update(
      (p) => p.copyWith(streak: 1),
      sessionId: 'retryable',
    );
    expect(retry.streak, 1);
  });
  test('concurrent transactions do not lose updates', () async {
    await Future.wait(
      List.generate(
        10,
        (i) => repository.update(
          (p) => p.copyWith(streak: p.streak + 1),
          sessionId: 's-$i',
        ),
      ),
    );
    expect((await repository.load()).streak, 10);
  });
  test(
    'settings adapter restores onboarding and existing icon fields',
    () async {
      final preferences = TestPreferences();
      final first = PreferencesSettingsRepository(preferences: preferences);
      expect((await first.load()).onboardingCompleted, isFalse);
      await first.save(
        AppSettings(onboardingCompleted: true, icons: AppIconPreferences()),
      );
      final second = PreferencesSettingsRepository(preferences: preferences);
      final read = await second.load();
      expect(read.onboardingCompleted, isTrue);
      expect(read.icons.unlockedIcons, {'grade1'});
      expect(read.icons.selectedIcon, 'grade1');
    },
  );
  test('settings read corruption is surfaced and failed writes leave prior state intact', () async {
    final preferences = TestPreferences();
    final repo = PreferencesSettingsRepository(preferences: preferences);
    await repo.save(AppSettings());
    preferences.failWrites = true;
    await expectLater(
      repo.save(AppSettings(onboardingCompleted: true)),
      throwsStateError,
    );
    expect((await repo.load()).onboardingCompleted, isFalse);
    preferences.values[PreferencesSettingsRepository.key] = 'broken';
    await expectLater(repo.load(), throwsFormatException);
  });
}
