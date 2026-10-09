import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/app/app_controller.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/data/services/app_icon_service.dart';
import 'package:sukusukukanji/data/services/icon_policy.dart';

import 'test_repositories.dart';

class FakeIconService implements AppIconService {
  String selected = 'grade1';
  bool fail = false;
  final List<String> changes = [];
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<String> current() async => selected;
  @override
  Future<void> apply(String key) async {
    if (fail) throw StateError('native failure');
    selected = key;
    changes.add(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'completion unlocks the next reward without forcing selection',
    () async {
      final catalog = await AssetKanjiRepository().load();
      final icons = const IconPolicy().reconcile(
        catalog,
        UserProgress(completedGrades: {1}),
        AppIconPreferences(),
      );
      expect(icons.unlockedIcons, {'grade1', 'grade2'});
      expect(icons.selectedIcon, 'grade1');
      expect(icons.seenUnlockModals, isEmpty);
    },
  );
  test('selection, acknowledgment and rewards survive recreation; locked icons fail', () async {
    final settings = MemorySettingsRepository();
    final progress = MemoryProgressRepository(
      UserProgress(completedGrades: {1}),
    );
    final native = FakeIconService();
    AppController create() => AppController(
      content: AssetKanjiRepository(),
      progress: progress,
      settings: settings,
      iconService: native,
    );
    final app = create();
    addTearDown(app.dispose);
    await app.load();
    expect(app.pendingIconRewards.single.iconKey, 'grade2');
    await expectLater(app.selectIcon('grade3'), throwsStateError);
    expect(native.changes, isEmpty);
    expect(await app.selectIcon('grade2'), isTrue);
    await app.acknowledgeIcon('grade2');
    final restored = create();
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.settings.icons.selectedIcon, 'grade2');
    expect(restored.pendingIconRewards, isEmpty);
  });
  test(
    'native failure and preference failure preserve the previous selection',
    () async {
      final settings = MemorySettingsRepository();
      final native = FakeIconService();
      final app = AppController(
        content: AssetKanjiRepository(),
        progress: MemoryProgressRepository(UserProgress(completedGrades: {1})),
        settings: settings,
        iconService: native,
      );
      addTearDown(app.dispose);
      await app.load();
      native.fail = true;
      await expectLater(app.selectIcon('grade2'), throwsStateError);
      expect(app.settings.icons.selectedIcon, 'grade1');
      native.fail = false;
      settings.failWrites = true;
      await expectLater(app.selectIcon('grade2'), throwsStateError);
      expect(native.changes, ['grade2', 'grade1']);
      expect(native.selected, 'grade1');
      expect(app.settings.icons.selectedIcon, 'grade1');
      expect(app.changingIcon, isFalse);
    },
  );
}
