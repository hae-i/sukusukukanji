import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/data/models/grade_theme.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/data/services/grade_policy.dart';
import 'package:sukusukukanji/data/services/icon_policy.dart';
import 'package:sukusukukanji/features/grades/course_allocation_screen.dart';

import 'content_test.dart' show JsonBundle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KanjiCatalog catalog;
  late Map<String, dynamic> allocation;
  late Map<String, dynamic> metadata;
  setUp(() async {
    catalog = await AssetKanjiRepository().load();
    allocation = jsonDecode(
      File('assets/data/middle-school-allocation.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    metadata = jsonDecode(
      File('assets/data/grades.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });
  AssetKanjiRepository changedRepository() => AssetKanjiRepository(
    bundle: JsonBundle({
      'assets/data/grades.json': metadata,
      'assets/data/middle-school-allocation.json': allocation,
      'assets/data/kanji/grade1.json': jsonDecode(
        File('assets/data/kanji/grade1.json').readAsStringSync(),
      ),
    }),
  );

  test('1,110 allocations cover exactly the remaining Joyo without elementary overlap', () {
    final source = jsonDecode(
      File('docs/content/education-kanji-source-catalog.json')
          .readAsStringSync(),
    ) as Map;
    final elementary = {
      for (final g in source['grades'] as List)
        for (final k in g['kanji'] as List) k['character'] as String,
    };
    final audit = jsonDecode(
      File('docs/content/middle-school-source-catalog.json').readAsStringSync(),
    ) as Map;
    final all = catalog.allocations.values.expand((c) => c.characters).toList();
    expect(all.length, 1110);
    expect(all.toSet().length, 1110);
    expect(all.toSet().intersection(elementary), isEmpty);
    expect({...all, ...elementary}.length, 2136);
    expect(all.toSet(), {
      for (final k in audit['kanji'] as List) k['character'] as String,
    });
    expect(catalog.allocations.values.map((c) => c.characters.length), [
      350,
      400,
      360,
    ]);
    final middle = catalog.grades
        .where((g) => g.schoolLevel == SchoolLevel.middle)
        .toList();
    expect(middle.map((g) => g.grade), [7, 8, 9]);
    expect(middle.map((g) => g.schoolYear), [1, 2, 3]);
    expect(
      catalog.kanji.length,
      80,
    ); // Source facts never silently become learning cards.
    expect(
      () => catalog.allocations[7]!.characters.clear(),
      throwsUnsupportedError,
    );
    expect(() => catalog.allocations.clear(), throwsUnsupportedError);
  });

  test('source lesson allocation is stable and every character is covered exactly once', () {
    final audit = jsonDecode(
      File('docs/content/middle-school-source-catalog.json').readAsStringSync(),
    ) as Map;
    for (final course in catalog.allocations.values) {
      final records = (audit['kanji'] as List)
          .where((k) => k['courseGrade'] == course.grade)
          .toList();
      expect(records.map((k) => k['character']), course.characters);
      for (var i = 0; i < records.length; i++) {
        expect(records[i]['lessonId'], i ~/ 5 + 1);
        expect(records[i]['lessonOrder'], i % 5 + 1);
        expect(records[i]['dictionaryGrade'], 8);
      }
    }
  });

  test('primary graduation opens middle year one; previews cannot graduate courses or add icons', () {
    const policy = GradePolicy();
    final graduated = policy.reconcile(
      catalog,
      UserProgress(currentGrade: 6, completedGrades: {1, 2, 3, 4, 5, 6}),
    );
    expect(graduated.currentGrade, 7);
    expect(policy.isUnlocked(catalog.grades[6], catalog, graduated), isTrue);
    expect(policy.isUnlocked(catalog.grades[7], catalog, graduated), isFalse);
    expect(policy.isUnlocked(catalog.grades[8], catalog, graduated), isFalse);
    expect(policy.canComplete(catalog.grades[6], catalog, graduated), isFalse);
    expect(catalog.forGrade(7), isEmpty);
    expect(catalog.iconThemes.length, 6);
    final icons = const IconPolicy().reconcile(
      catalog,
      graduated,
      AppIconPreferences(),
    );
    expect(icons.unlockedIcons, {
      'grade1',
      'grade2',
      'grade3',
      'grade4',
      'grade5',
      'grade6',
    });
    expect(icons.selectedIcon, 'grade1');
    final second = UserProgress(
      currentGrade: 8,
      completedGrades: {1, 2, 3, 4, 5, 6, 7},
    );
    expect(policy.isUnlocked(catalog.grades[7], catalog, second), isTrue);
    expect(policy.isUnlocked(catalog.grades[8], catalog, second), isFalse);
  });

  test('duplicate assignments, course size and malformed sources fail at load time', () async {
    allocation['courses'][1]['characters'][0] =
        allocation['courses'][0]['characters'][0];
    await expectLater(changedRepository().load(), throwsFormatException);
  });
  test('allocation count must match grade metadata', () async {
    metadata['grades'][6]['requiredKanjiCount'] = 351;
    await expectLater(changedRepository().load(), throwsFormatException);
  });
  test(
    'elementary learning facts cannot appear in a middle allocation',
    () async {
      allocation['courses'][0]['characters'][0] = '一';
      await expectLater(changedRepository().load(), throwsFormatException);
    },
  );
  test('invalid middle school year is rejected', () async {
    metadata['grades'][6]['schoolYear'] = 4;
    await expectLater(changedRepository().load(), throwsFormatException);
  });
  test('invalid allocation source is rejected', () async {
    allocation['references'][0]['url'] = 'http://example.com';
    await expectLater(changedRepository().load(), throwsFormatException);
  });

  testWidgets(
    'allocation preview and attribution work offline at 320px with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: CourseAllocationScreen(
            grade: catalog.grades[6],
            allocation: catalog.allocations[7]!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('중학교 1학년'), findsOneWidget);
      expect(find.text('350자 · 70개 레슨'), findsOneWidget);
      expect(find.textContaining('한국어 뜻과 대표 읽기 검수 후'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('배정 기준과 출처'));
      await tester.pumpAndSettle();
      expect(find.text('중학교 과정 배정 기준'), findsOneWidget);
      expect(find.textContaining('공식 학년별 한자 배당표가 아닙니다.'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
