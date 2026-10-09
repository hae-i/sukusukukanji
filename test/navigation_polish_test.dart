import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/app/app_controller.dart';
import 'package:sukusukukanji/app/app_shell.dart';
import 'package:sukusukukanji/app/theme/app_theme.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/features/study/study_hub_screen.dart';

import 'test_repositories.dart';

class PolishContent implements KanjiRepository {
  PolishContent(this.catalog);
  final KanjiCatalog catalog;
  @override
  Future<KanjiCatalog> load() async => catalog;
}

TextStyle renderedStyle(WidgetTester tester, Finder text) =>
    (tester
                .widget<RichText>(
                  find.descendant(
                    of: text.first,
                    matching: find.byType(RichText),
                  ),
                )
                .text
            as TextSpan)
        .style!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KanjiCatalog catalog;
  setUpAll(() async => catalog = await AssetKanjiRepository().load());

  testWidgets(
    'entering study tab shows the next lesson and returning recenters it',
    (tester) async {
      final app = AppController(
        content: PolishContent(catalog),
        progress: MemoryProgressRepository(
          UserProgress(
            kanji: {
              for (final k in catalog.kanji.take(30))
                k.id: KanjiProgress(
                  kanjiId: k.id,
                  firstStudiedAt: DateTime(2026, 10, 9),
                ),
            },
          ),
        ),
        settings: MemorySettingsRepository(),
      );
      addTearDown(app.dispose);
      await app.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AppShell(controller: app),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('학습').last);
      await tester.pumpAndSettle();
      final next = find.text('Lesson 7');
      expect(next.hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(next).dy, lessThan(200));
      final hub = find.byType(StudyHubScreen);
      final scroller = find
          .descendant(of: hub, matching: find.byType(Scrollable))
          .first;
      tester.state<ScrollableState>(scroller).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(next.hitTestable(), findsNothing);
      await tester.tap(find.text('홈').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('학습').last);
      await tester.pumpAndSettle();
      expect(next.hitTestable(), findsOneWidget);
      final review = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '복습하기').first,
      );
      expect(
        review.style!.backgroundColor!.resolve({}),
        const Color(0xFFE3ECDD),
      );
      final study = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '이어서 배우기'),
      );
      expect(
        study.style?.backgroundColor?.resolve({}),
        isNot(const Color(0xFFE3ECDD)),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fonts and bold app bar titles persist across tabs and pushed routes',
    (tester) async {
      final app = AppController(
        content: PolishContent(catalog),
        progress: MemoryProgressRepository(),
        settings: MemorySettingsRepository(),
      );
      addTearDown(app.dispose);
      await app.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AppShell(controller: app),
        ),
      );
      await tester.pumpAndSettle();
      var style = renderedStyle(tester, find.text('すくすく漢字'));
      expect(style.fontFamily, 'NotoSansJP');
      expect(style.fontWeight, FontWeight.w700);
      await tester.tap(find.text('학습').last);
      await tester.pumpAndSettle();
      style = renderedStyle(tester, find.text('학습').first);
      expect(style.fontFamily, 'Pretendard');
      expect(style.fontWeight, FontWeight.w700);
      expect(
        renderedStyle(tester, find.text('이어서 배우기')).fontFamily,
        'Pretendard',
      );
      expect(
        renderedStyle(tester, find.text('一 二 三 四 五')).fontFamily,
        'NotoSansJP',
      );
      await tester.tap(find.text('내 한자').last);
      await tester.pumpAndSettle();
      expect(
        renderedStyle(tester, find.text('내 한자').first).fontWeight,
        FontWeight.w700,
      );
      await tester.tap(find.text('一'));
      await tester.pumpAndSettle();
      style = renderedStyle(tester, find.text('한자 살펴보기'));
      expect(style.fontFamily, 'Pretendard');
      expect(style.fontWeight, FontWeight.w700);
      expect(renderedStyle(tester, find.text('一')).fontFamily, 'NotoSansJP');
      expect(renderedStyle(tester, find.text('하나 일')).fontFamily, 'Pretendard');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('앱 안내'));
      await tester.pumpAndSettle();
      style = renderedStyle(tester, find.text('앱 안내').first);
      expect(style.fontFamily, 'Pretendard');
      expect(style.fontWeight, FontWeight.w700);
      expect(tester.takeException(), isNull);
    },
  );
}
