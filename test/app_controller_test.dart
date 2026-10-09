import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/app/app_controller.dart';

import 'test_repositories.dart';

import 'package:sukusukukanji/data/repositories/kanji_repository.dart';

class ControlledRepository implements KanjiRepository {
  Completer<KanjiCatalog> request = Completer();
  int calls = 0;
  @override
  Future<KanjiCatalog> load() {
    calls++;
    return request.future;
  }
}

void main() {
  test(
    'loading failure is retryable, concurrent loads are coalesced',
    () async {
      final repository = ControlledRepository();
      final controller = AppController(
        content: repository,
        progress: MemoryProgressRepository(),
        settings: MemorySettingsRepository(),
      );
      addTearDown(controller.dispose);
      final first = controller.load();
      await controller.load();
      expect(repository.calls, 1);
      repository.request.completeError(const FormatException('broken content'));
      await first;
      expect(controller.status, AppStatus.error);
      expect(controller.error, isA<FormatException>());
      repository.request = Completer();
      final retry = controller.load();
      expect(controller.status, AppStatus.loading);
      expect(controller.error, isNull);
      repository.request.complete(KanjiCatalog(grades: [], kanji: []));
      await retry;
      expect(controller.status, AppStatus.ready);
      expect(repository.calls, 2);
    },
  );

  test('finishing a load after disposal never notifies listeners', () async {
    final repository = ControlledRepository();
    final controller = AppController(
      content: repository,
      progress: MemoryProgressRepository(),
      settings: MemorySettingsRepository(),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);
    final loading = controller.load();
    controller.dispose();
    repository.request.complete(KanjiCatalog(grades: [], kanji: []));
    await loading;
    expect(notifications, 1);
  });
}
