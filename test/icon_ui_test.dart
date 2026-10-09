import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/app/app_controller.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/features/app_icon/icon_selection_screen.dart';
import 'package:sukusukukanji/features/app_icon/icon_unlock_dialog.dart';

import 'test_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'icon selection is accessible at 320px and 2x text; locked rewards cannot be selected',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = AppController(
        content: AssetKanjiRepository(),
        progress: MemoryProgressRepository(UserProgress(completedGrades: {1})),
        settings: MemorySettingsRepository(),
      );
      addTearDown(app.dispose);
      await tester.runAsync(app.load);
      await tester.pumpWidget(
        MaterialApp(home: IconSelectionScreen(controller: app)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final title = find.text('2학년 어린 식물');
      await tester.ensureVisible(title);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(app.settings.icons.selectedIcon, 'grade2');
      expect(
        find.textContaining('이 환경에서는 기기 아이콘 변경을 지원하지 않아요.'),
        findsOneWidget,
      );
      final locked = find.text('3학년 자라는 식물');
      await tester.ensureVisible(locked);
      await tester.pumpAndSettle();
      final tile = tester.widget<ListTile>(
        find.ancestor(of: locked, matching: find.byType(ListTile)),
      );
      expect(tile.onTap, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'large-text unlock dialog can defer and persist acknowledgment without selecting',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = AppController(
        content: AssetKanjiRepository(),
        progress: MemoryProgressRepository(UserProgress(completedGrades: {1})),
        settings: MemorySettingsRepository(),
      );
      addTearDown(app.dispose);
      await tester.runAsync(app.load);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => IconUnlockDialog(
                    controller: app,
                    grade: app.catalog!.grades[1],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(app.pendingIconRewards, isEmpty);
      expect(app.settings.icons.selectedIcon, 'grade1');
      expect(tester.takeException(), isNull);
    },
  );
}
