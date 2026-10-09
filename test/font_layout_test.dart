import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/app/app.dart';
import 'package:sukusukukanji/app/app_controller.dart';
import 'package:sukusukukanji/app/theme/app_theme.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/features/kanji/kanji_list_screen.dart';
import 'package:sukusukukanji/widgets/kanji_content.dart';
import 'package:sukusukukanji/widgets/mixed_language_text.dart';

import 'test_repositories.dart';

class FontContent implements KanjiRepository {
  FontContent(this.catalog);
  final KanjiCatalog catalog;
  @override
  Future<KanjiCatalog> load() async => catalog;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KanjiCatalog catalog;
  setUpAll(() async {
    catalog = await AssetKanjiRepository().load();
    // Use real bundled glyphs rather than the test runner's Ahem font.
    await (FontLoader('NotoSansJP')
          ..addFont(rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf')))
        .load();
    await (FontLoader(
      'Pretendard',
    )..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'))).load();
  });
  testWidgets('mixed Korean and Japanese preserve the global font for Hangul', (
    tester,
  ) async {
    const data = '山은 やま, 뜻은 산 · ガク · 𠮟';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: MixedLanguageText(data)),
      ),
    );
    final rich = tester.widget<RichText>(
      find.descendant(of: find.text(data), matching: find.byType(RichText)),
    );
    final root = rich.text as TextSpan;
    expect(root.style!.fontFamily, 'Pretendard');
    var koreanSeen = false;
    var japaneseSeen = false;
    void inspect(TextSpan span, TextStyle inherited) {
      final effective = inherited.merge(span.style);
      final value = span.text ?? '';
      if (RegExp('[가-힣]').hasMatch(value)) {
        koreanSeen = true;
        expect(effective.fontFamily, 'Pretendard');
      }
      if (value.contains('山') ||
          value.contains('やま') ||
          value.contains('ガク') ||
          value.contains('𠮟')) {
        japaneseSeen = true;
        expect(effective.fontFamily, 'NotoSansJP');
      }
      for (final child in span.children ?? <InlineSpan>[]) {
        inspect(child as TextSpan, effective);
      }
    }

    inspect(root, const TextStyle());
    expect(koreanSeen && japaneseSeen, isTrue);
    expect(root.toPlainText(), data);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'real fonts render readings side by side without overflow at 320px and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: KanjiContent(kanji: catalog.kanji[3]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final on = tester.getCenter(find.text('대표 음독'));
      final kun = tester.getCenter(find.text('대표 훈독'));
      expect(on.dy, closeTo(kun.dy, 1));
      expect(kun.dx - on.dx, greaterThan(32));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'square grid fills both edges at phone widths and signals learned/review states',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final progress = MemoryProgressRepository(
        UserProgress(
          kanji: {
            catalog.kanji[0].id: KanjiProgress(
              kanjiId: catalog.kanji[0].id,
              firstStudiedAt: DateTime(2026, 10, 9),
            ),
            catalog.kanji[1].id: KanjiProgress(
              kanjiId: catalog.kanji[1].id,
              firstStudiedAt: DateTime(2026, 10, 9),
              needsReview: true,
            ),
          },
        ),
      );
      final app = AppController(
        content: FontContent(catalog),
        progress: progress,
        settings: MemorySettingsRepository(),
      );
      addTearDown(app.dispose);
      await app.load();
      for (final (width, scale) in [
        (320.0, 1.0),
        (390.0, 1.0),
        (430.0, 1.0),
        (600.0, 1.0),
        (320.0, 2.0),
      ]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: KanjiListScreen(controller: app, onSelect: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final grid = tester.widget<GridView>(find.byType(GridView));
        final count =
            (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
                .crossAxisCount;
        expect(count, scale > 1.5 ? 2 : 3);
        final first = tester.getRect(find.byType(Card).at(0));
        final last = tester.getRect(find.byType(Card).at(count - 1));
        final bounds = tester.getRect(find.byType(GridView));
        expect(first.width, closeTo(first.height, .01));
        expect(first.left, closeTo(bounds.left, .01));
        expect(last.right, closeTo(bounds.right, .01));
        expect(find.text('처음 만나요'), findsNothing);
        expect(find.text('조금씩 익숙해지는 내 한자'), findsNothing);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.close_rounded)).color,
          Colors.red,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'home removes subtitles and places streak above greeting with bundled Korean font',
    (tester) async {
      await tester.pumpWidget(
        SukuSukuApp(
          repository: FontContent(catalog),
          progressRepository: MemoryProgressRepository(),
          settingsRepository: MemorySettingsRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('작은 시작, 매일의 성장'), findsNothing);
      expect(find.textContaining('이미 아는 한국어'), findsNothing);
      expect(
        tester.getCenter(find.text('연속 0일')).dy,
        lessThan(tester.getCenter(find.text('오늘도 한자 5분만!')).dy),
      );
      expect(
        Theme.of(tester.element(find.text('연속 0일')))
            .textTheme
            .bodyMedium!
            .fontFamily,
        'Pretendard',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
