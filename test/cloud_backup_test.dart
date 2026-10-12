import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/app/app_controller.dart';
import 'package:sukusukukanji/data/models/study_session.dart';
import 'package:sukusukukanji/data/cloud/backup_preferences.dart';
import 'package:sukusukukanji/data/cloud/backup_service.dart';
import 'package:sukusukukanji/data/cloud/progress_snapshot.dart';
import 'package:sukusukukanji/data/models/learning_access.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/features/account/account_screen.dart';
import 'package:sukusukukanji/features/account/backup_controller.dart';

import 'test_repositories.dart';

class MemoryBinding implements BackupPreferences {
  BackupBinding? value;
  bool fail = false;
  @override
  Future<BackupBinding?> load() async => value;
  @override
  Future<void> save(BackupBinding binding) async {
    if (fail) throw StateError('preferences unavailable');
    value = binding;
  }
}

class FakeCloud extends BackupService {
  String? account = 'alice';
  final rows = <String, CloudBackup>{};
  final writes = <String>[];
  bool offline = false;
  Completer<void>? pauseRead;
  Completer<void>? pauseWrite;
  @override
  bool get configured => true;
  @override
  String? get userId => account;
  @override
  String? get email => account == null ? null : '$account@example.com';
  void switchTo(String? id) {
    account = id;
    notifyListeners();
  }

  @override
  Future<void> signIn() async => switchTo('alice');
  @override
  Future<void> signOut() async => switchTo(null);
  @override
  Future<void> deleteAccount() async {
    rows.remove(account);
    switchTo(null);
  }

  @override
  Future<CloudBackup?> read(String userId) async {
    if (offline) throw StateError('offline');
    final result = rows[userId];
    await pauseRead?.future;
    return result;
  }

  @override
  Future<CloudBackup> write(
    String userId,
    Map<String, dynamic> payload,
    int expectedRevision,
  ) async {
    await pauseWrite?.future;
    if (offline) throw StateError('offline');
    if (userId != account) throw StateError('account changed');
    if ((rows[userId]?.revision ?? 0) != expectedRevision) {
      throw BackupConflict();
    }
    writes.add(userId);
    return rows[userId] = CloudBackup(
      revision: expectedRevision + 1,
      updatedAt: DateTime(2026, 10, 12),
      payload: payload,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KanjiCatalog catalog;
  late MemoryProgressRepository local;
  late FakeCloud service;
  late MemoryBinding prefs;
  late BackupController controller;
  int restored = 0;
  setUpAll(() async {
    catalog = await AssetKanjiRepository().load();
  });
  UserProgress learned([int count = 1]) => UserProgress(
    kanji: {
      for (final k in catalog.kanji.take(count))
        k.id: KanjiProgress(
          kanjiId: k.id,
          status: KanjiMasteryStatus.learning,
          firstStudiedAt: DateTime(2026, 10, 10),
          needsReview: true,
          correctCount: 2,
          wrongCount: 1,
        ),
    },
    favoriteKanjiIds: {catalog.kanji.first.id},
    streak: 2,
    lastStudyDate: DateTime(2026, 10, 11),
    learningAccess: LearningAccess(rewardCredits: 3),
  );
  setUp(() {
    local = MemoryProgressRepository(learned());
    service = FakeCloud();
    prefs = MemoryBinding();
    restored = 0;
    controller = BackupController(
      service: service,
      preferences: prefs,
      progress: local,
      catalog: catalog,
      onRestored: () async {
        restored++;
      },
    );
  });
  tearDown(() {
    controller.dispose();
  });

  test('backup round trips learning data, never ad credits or purchases', () {
    final json = ProgressSnapshot.encode(learned(5));
    expect(json.containsKey('learningAccess'), isFalse);
    json['learningAccess'] = {'rewardCredits': 10000};
    json['purchased'] = true;
    final restored = ProgressSnapshot.decode(json, catalog);
    expect(restored.totalLearned, 5);
    expect(restored.favoriteKanjiIds, {catalog.kanji.first.id});
    expect(restored.kanji.values.first.needsReview, isTrue);
    expect(restored.learningAccess.rewardCredits, 0);
    expect(restored.streak, 2);
  });
  test(
    'unknown versions, IDs, duplicate records and bad counters fail closed',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (j) => j['version'] = 2,
        (j) => j['favorites'] = ['unknown'],
        (j) => (j['kanji'] as List).add((j['kanji'] as List).first),
        (j) => (j['kanji'] as List).first['correct_count'] = -1,
      ]) {
        final json = ProgressSnapshot.encode(learned());
        mutate(json);
        expect(
          () => ProgressSnapshot.decode(json, catalog),
          throwsFormatException,
        );
      }
    },
  );
  test('first sign-in requires a choice and explicit upload starts automatic backup', () async {
    await controller.initialize();
    expect(service.writes, isEmpty);
    expect(controller.automatic, isFalse);
    await controller.backupNow();
    expect(service.writes, ['alice']);
    expect(controller.automatic, isTrue);
    expect(prefs.value!.userId, 'alice');
    expect(
      service.rows['alice']!.payload.containsKey('learningAccess'),
      isFalse,
    );
  });
  test(
    'offline backup failure preserves local progress and retries safely',
    () async {
      await controller.initialize();
      await controller.backupNow();
      service.offline = true;
      await local.update((p) => learned(5));
      controller.localChanged();
      await controller.backupNow();
      expect(local.value.totalLearned, 5);
      expect(service.rows['alice']!.revision, 1);
      expect(controller.message, contains('다시 시도'));
      service.offline = false;
      await controller.refresh();
      expect(service.rows['alice']!.revision, 2);
      expect(
        ProgressSnapshot.decode(
          service.rows['alice']!.payload,
          catalog,
        ).totalLearned,
        5,
      );
    },
  );
  test('a newer remote revision cannot be silently overwritten', () async {
    await controller.initialize();
    await controller.backupNow();
    service.rows['alice'] = CloudBackup(
      revision: 2,
      updatedAt: DateTime.now(),
      payload: ProgressSnapshot.encode(learned(5)),
    );
    await controller.backupNow();
    expect(controller.automatic, isFalse);
    expect(controller.checked, isFalse);
    expect(service.rows['alice']!.revision, 2);
    expect(service.writes, ['alice']);
    await controller.refresh();
    expect(controller.remoteLearned, 5);
    expect(controller.automatic, isFalse);
    await controller.restore();
    expect(local.value.totalLearned, 5);
    expect(local.value.learningAccess.rewardCredits, 3);
    expect(restored, 1);
    expect(controller.automatic, isTrue);
  });
  test(
    'account switch never automatically uploads the previous account data',
    () async {
      await controller.initialize();
      await controller.backupNow();
      service.switchTo('bob');
      await Future<void>.delayed(Duration.zero);
      expect(controller.automatic, isFalse);
      expect(service.writes, ['alice']);
      expect(service.rows['bob'], isNull);
      expect(local.value.totalLearned, 1);
      expect(controller.canChoose, isTrue);
    },
  );
  test('account switch while an upload is pending is rejected', () async {
    await controller.initialize();
    service.pauseWrite = Completer<void>();
    final pending = controller.backupNow();
    await Future<void>.delayed(Duration.zero);
    service.switchTo('bob');
    service.pauseWrite!.complete();
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(service.writes, isEmpty);
    expect(prefs.value, isNull);
    expect(controller.automatic, isFalse);
  });
  test(
    'restore refuses to replace a local change made during cloud fetch',
    () async {
      service.rows['alice'] = CloudBackup(
        revision: 1,
        updatedAt: DateTime.now(),
        payload: ProgressSnapshot.encode(learned(5)),
      );
      await controller.initialize();
      service.pauseRead = Completer<void>();
      final pending = controller.restore();
      await Future<void>.delayed(Duration.zero);
      await local.update((p) => learned(2));
      controller.localChanged();
      service.pauseRead!.complete();
      await pending;
      expect(local.value.totalLearned, 2);
      expect(controller.automatic, isFalse);
      expect(restored, 0);
    },
  );
  test(
    'restore write failure preserves both snapshots and does not bind',
    () async {
      service.rows['alice'] = CloudBackup(
        revision: 1,
        updatedAt: DateTime.now(),
        payload: ProgressSnapshot.encode(learned(5)),
      );
      await controller.initialize();
      local.failWrites = true;
      await controller.restore();
      expect(local.value.totalLearned, 1);
      expect(controller.remoteLearned, 5);
      expect(prefs.value, isNull);
      expect(restored, 0);
    },
  );
  test(
    'restart with an old binding asks before overwriting cloud progress',
    () async {
      prefs.value = const BackupBinding('alice', 1);
      service.rows['alice'] = CloudBackup(
        revision: 2,
        updatedAt: DateTime.now(),
        payload: ProgressSnapshot.encode(learned(5)),
      );
      await controller.initialize();
      expect(controller.automatic, isFalse);
      expect(service.writes, isEmpty);
      expect(local.value.totalLearned, 1);
    },
  );
  test('failed binding persistence leaves cloud data safe for retry', () async {
    await controller.initialize();
    prefs.fail = true;
    await controller.backupNow();
    expect(controller.automatic, isFalse);
    expect(service.rows['alice']!.revision, 1);
    prefs.fail = false;
    await controller.refresh();
    await controller.backupNow();
    expect(prefs.value!.revision, 1);
    expect(service.writes, ['alice']);
  });
  test(
    'delete removes the signed-in cloud account but keeps local learning',
    () async {
      await controller.initialize();
      await controller.backupNow();
      await controller.deleteAccount();
      expect(service.rows, isEmpty);
      expect(service.userId, isNull);
      expect(local.value.totalLearned, 1);
      expect(controller.automatic, isFalse);
    },
  );
  test(
    'a real study completion automatically backs up the committed progress',
    () async {
      final cloud = FakeCloud();
      final app = AppController(
        content: AssetKanjiRepository(),
        progress: MemoryProgressRepository(),
        settings: MemorySettingsRepository(),
        backupService: cloud,
        backupPreferences: MemoryBinding(),
      );
      addTearDown(app.dispose);
      await app.load();
      await Future<void>.delayed(Duration.zero);
      await app.backup!.backupNow();
      expect(app.backup!.automatic, isTrue);
      final session = app.start()!;
      await app.saveSession(
        CompletedSession(
          session: session,
          answers: [
            for (final q in session.questions) q.options.indexOf(q.answer),
          ],
          completedAt: DateTime(2026, 10, 12),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(
        ProgressSnapshot.decode(
          cloud.rows['alice']!.payload,
          catalog,
        ).totalLearned,
        5,
      );
      expect(cloud.rows['alice']!.revision, 2);
    },
  );
  testWidgets(
    'restore requires confirmation and account screen fits large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      service.rows['alice'] = CloudBackup(
        revision: 1,
        updatedAt: DateTime.now(),
        payload: ProgressSnapshot.encode(learned(5)),
      );
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: AccountScreen(controller: controller)),
      );
      await tester.ensureVisible(find.text('클라우드 기록 복원'));
      await tester.tap(find.text('클라우드 기록 복원'));
      await tester.pumpAndSettle();
      expect(find.text('클라우드 진도를 복원할까요?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(local.value.totalLearned, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
