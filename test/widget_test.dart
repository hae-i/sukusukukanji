import 'dart:ui' show SemanticsAction;

import 'test_repositories.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/app/app.dart';
import 'package:sukusukukanji/data/models/kanji.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/features/kanji/kanji_detail_screen.dart';

class ReadyRepository implements KanjiRepository {
  ReadyRepository(this.catalog);
  final KanjiCatalog catalog;
  @override
  Future<KanjiCatalog> load() async => catalog;
}

class RetryRepository extends ReadyRepository {
  RetryRepository(super.catalog);
  int calls = 0;
  @override
  Future<KanjiCatalog> load() async {
    if (calls++ == 0) throw const FormatException('test failure');
    return catalog;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  late KanjiCatalog catalog;
  setUp(() async {
    catalog = await AssetKanjiRepository().load();
  });

  testWidgets('home, sample list, detail and back navigation work', (
    tester,
  ) async {
    await tester.pumpWidget(
      SukuSukuApp(
        repository: ReadyRepository(catalog),
        progressRepository: MemoryProgressRepository(),
        settingsRepository: MemorySettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('오늘도 한자 5분만!'), findsOneWidget);
    expect(find.text('0 / 80자'), findsOneWidget);
    await tester.tap(find.text('내 한자'));
    await tester.pumpAndSettle();
    expect(find.text('조금씩 익숙해지는 내 한자'), findsOneWidget);
    final cardSemantics = tester.getSemantics(
      find.bySemanticsLabel('一, 하나, 일, 처음 만나요, 상세 보기'),
    );
    expect(
      cardSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    await tester.ensureVisible(find.text('一'));
    await tester.tap(find.text('一'));
    await tester.pumpAndSettle();
    expect(find.text('한자 살펴보기'), findsOneWidget);
    expect(find.text('イチ'), findsOneWidget);
    expect(find.text('단일(單一)'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('조금씩 익숙해지는 내 한자'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grade metadata and settings are reachable', (tester) async {
    await tester.pumpWidget(
      SukuSukuApp(
        repository: ReadyRepository(catalog),
        progressRepository: MemoryProgressRepository(),
        settingsRepository: MemorySettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('학년별 성장 과정'));
    await tester.tap(find.text('학년별 성장 과정'));
    await tester.pumpAndSettle();
    expect(find.text('1학년 · 새싹'), findsOneWidget);
    expect(find.text('잠김 · 앞 학년을 먼저 완료해 주세요.'), findsNWidgets(5));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('앱 안내'));
    await tester.pumpAndSettle();
    expect(find.text('스쿠스쿠칸지 · SukuSuku Kanji'), findsOneWidget);
  });

  testWidgets('320px screen with large text has no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      SukuSukuApp(
        repository: ReadyRepository(catalog),
        progressRepository: MemoryProgressRepository(),
        settingsRepository: MemorySettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('내 한자'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('一'));
    await tester.tap(find.text('一'));
    await tester.pumpAndSettle();
    expect(find.text('한자 살펴보기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading and failure UI can retry into the home screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      SukuSukuApp(
        repository: RetryRepository(catalog),
        progressRepository: MemoryProgressRepository(),
        settingsRepository: MemorySettingsRepository(),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('자료나 학습 기록을 불러오지 못했어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('오늘도 한자 5분만!'), findsOneWidget);
  });

  testWidgets('detail omits absent optional sections', (tester) async {
    final minimal = Kanji.fromJson({
      'id': 'minimal',
      'character': '一',
      'grade': 1,
      'koreanReading': '일',
      'koreanMeanings': ['하나'],
    });
    await tester.pumpWidget(
      MaterialApp(home: KanjiDetailScreen(kanji: minimal)),
    );
    expect(find.text('하나 일'), findsOneWidget);
    expect(find.text('대표 훈독'), findsNothing);
    expect(find.text('한국어랑 연결하기'), findsNothing);
    expect(find.text('일본어 단어'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
