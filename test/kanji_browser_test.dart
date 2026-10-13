import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/app/app.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/features/kanji/kanji_browser.dart';
import 'package:sukusukukanji/features/kanji/kanji_list_screen.dart';

import 'test_repositories.dart';

class BrowserContent implements KanjiRepository {
  BrowserContent(this.catalog);
  final KanjiCatalog catalog;
  @override
  Future<KanjiCatalog> load() async => catalog;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KanjiCatalog catalog;
  setUpAll(() async {
    catalog = await AssetKanjiRepository().load();
  });

  test('search matches sourced characters, meanings, readings, words and traditional forms', () {
    for (final query in ['学', '學', '학교', 'がっこう', 'ガッコウ', '  배우다  학  ']) {
      expect(
        KanjiBrowser.select(
          catalog.kanji,
          UserProgress(),
          query: query,
        ).map((k) => k.character),
        contains('学'),
        reason: query,
      );
    }
    expect(
      KanjiBrowser.select(
        catalog.kanji,
        UserProgress(),
        query: 'やま',
      ).map((k) => k.character),
      contains('山'),
    );
    expect(
      KanjiBrowser.select(catalog.kanji, UserProgress(), query: 'やま'),
      KanjiBrowser.select(catalog.kanji, UserProgress(), query: 'ヤマ'),
    );
    expect(
      KanjiBrowser.select(catalog.kanji, UserProgress(), query: '없는검색어'),
      isEmpty,
    );
    expect(
      KanjiBrowser.select(catalog.kanji, UserProgress(), query: '  ').length,
      1026,
    );
  });
  test('status, search and grade filters intersect without including allocation-only entries', () {
    final k = catalog.kanji.firstWhere((k) => k.character == '山');
    final progress = UserProgress(
      kanji: {k.id: KanjiProgress(kanjiId: k.id, needsReview: true)},
      favoriteKanjiIds: {k.id},
    );
    expect(
      KanjiBrowser.select(
        catalog.kanji,
        progress,
        query: 'ヤマ',
        grade: 1,
        filter: KanjiFilter.favorites,
      ),
      [k],
    );
    expect(
      KanjiBrowser.select(
        catalog.kanji,
        progress,
        query: 'ヤマ',
        grade: 1,
        filter: KanjiFilter.review,
      ),
      [k],
    );
    expect(
      KanjiBrowser.select(catalog.kanji, progress, filter: KanjiFilter.learned),
      isEmpty,
    );
    expect(KanjiBrowser.select(catalog.kanji, progress, grade: 7), isEmpty);
  });
  test('sorting is stable, puts unlearned items last in recent order and leaves the catalog intact', () {
    final original = catalog.kanji.map((k) => k.id).toList();
    final a = catalog.kanji[1], b = catalog.kanji[2];
    final progress = UserProgress(
      kanji: {
        a.id: KanjiProgress(
          kanjiId: a.id,
          firstStudiedAt: DateTime(2026, 10, 11),
          lastStudiedAt: DateTime(2026, 10, 13),
        ),
        b.id: KanjiProgress(
          kanjiId: b.id,
          firstStudiedAt: DateTime(2026, 10, 12),
        ),
      },
    );
    final recent = KanjiBrowser.select(
      catalog.kanji.reversed,
      progress,
      sort: KanjiSort.recent,
    );
    expect(recent.take(2), [a, b]);
    expect(recent[2], catalog.kanji.first);
    final reading = KanjiBrowser.select(
      catalog.kanji,
      progress,
      sort: KanjiSort.koreanReading,
    );
    final expected = catalog.kanji.map((k) => k.koreanReading).toList()..sort();
    expect(reading.map((k) => k.koreanReading), expected);
    expect(
      KanjiBrowser.select(catalog.kanji.reversed, progress).map((k) => k.id),
      original,
    );
    expect(catalog.kanji.map((k) => k.id), original);
  });

  testWidgets(
    'search, empty results, grade preparation, sort, reset and tab state work together',
    (tester) async {
      await tester.pumpWidget(
        SukuSukuApp(
          repository: BrowserContent(catalog),
          progressRepository: MemoryProgressRepository(),
          settingsRepository: MemorySettingsRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('내 한자'));
      await tester.pumpAndSettle();
      // A thousand-character catalog must not eagerly build a thousand cards.
      expect(find.byType(Card).evaluate().length, lessThan(50));
      final search = find.byKey(const ValueKey('kanji-search'));
      await tester.enterText(search, '學 まなぶ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('学'), findsOneWidget);
      expect(find.text('1자'), findsOneWidget);
      await tester.tap(find.text('홈'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('내 한자').last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, '學 まなぶ');
      await tester.enterText(search, '없는검색어');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('검색 조건에 맞는 한자가 없어요.'), findsOneWidget);
      await tester.tap(find.byTooltip('검색어 지우기'));
      await tester.pumpAndSettle();
      expect(find.text('1026자'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kanji-grade')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('중학교 1학년').last);
      await tester.pumpAndSettle();
      expect(find.text('이 학년의 학습 콘텐츠는 준비 중이에요.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kanji-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('최근 학습순').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('필터 초기화'));
      await tester.tap(find.text('필터 초기화'));
      await tester.pumpAndSettle();
      expect(find.text('1026자'), findsOneWidget);
      expect(find.text('학습 순서'), findsOneWidget);
      expect(find.byType(KanjiListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'favorites can be changed inside search results and update the count',
    (tester) async {
      final progress = MemoryProgressRepository(
        UserProgress(favoriteKanjiIds: {catalog.kanji.first.id}),
      );
      await tester.pumpWidget(
        SukuSukuApp(
          repository: BrowserContent(catalog),
          progressRepository: progress,
          settingsRepository: MemorySettingsRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('내 한자'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('kanji-search')), 'ひとつ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('一 즐겨찾기 해제'));
      await tester.tap(find.byTooltip('一 즐겨찾기 해제'));
      await tester.pumpAndSettle();
      expect(find.text('0자'), findsOneWidget);
      expect(progress.value.favoriteKanjiIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
