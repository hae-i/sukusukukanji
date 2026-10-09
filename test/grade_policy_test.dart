import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/data/models/grade_theme.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/data/services/grade_policy.dart';

/// Uses the real ten entries with a deliberately shorter test-only curriculum.
/// Production metadata remains 80; no invented learning facts are bundled.
KanjiCatalog shortCourse(KanjiCatalog real) => KanjiCatalog(
  grades: [
    const GradeTheme(
      grade: 1,
      nameKo: '1학년',
      plantStage: PlantStage.sprout,
      stageNameKo: '새싹',
      iconKey: 'grade1',
      requiredKanjiCount: 10,
      contentAsset: 'assets/data/kanji/grade1.json',
    ),
    ...real.grades.skip(1),
  ],
  kanji: real.kanji.take(10).toList(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KanjiCatalog real;
  setUp(() async {
    real = await AssetKanjiRepository().load();
  });
  UserProgress learned(int count) => UserProgress(
    kanji: {
      for (final k in real.kanji.take(count))
        k.id: KanjiProgress(
          kanjiId: k.id,
          firstStudiedAt: DateTime(2026, 10, 8),
        ),
    },
  );
  const policy = GradePolicy();
  test('ten sample entries never graduate the real eighty-character grade', () {
    final p = policy.reconcile(real, learned(10));
    expect(p.currentGrade, 1);
    expect(p.completedGrades, isEmpty);
    expect(policy.learnedCount(real.grades.first, real, p), 10);
    expect(policy.isUnlocked(real.grades[1], real, p), isFalse);
  });
  test('every required entry must be learned, even if others have repeated successes', () {
    final fixture = shortCourse(real);
    expect(
      policy.canComplete(fixture.grades.first, fixture, learned(9)),
      isFalse,
    );
    final complete = policy.reconcile(fixture, learned(10));
    expect(complete.completedGrades, {1});
    expect(complete.currentGrade, 2);
    expect(policy.isUnlocked(fixture.grades[1], fixture, complete), isTrue);
    expect(policy.isUnlocked(fixture.grades[2], fixture, complete), isFalse);
    expect(fixture.grades[1].contentAsset, isNull);
    expect(complete.seenGradeCelebrations, isEmpty);
  });
  test(
    'completion is idempotent and preserves celebration acknowledgments',
    () {
      final fixture = shortCourse(real);
      final first = policy
          .reconcile(fixture, learned(10))
          .copyWith(seenGradeCelebrations: {1});
      final next = policy.reconcile(fixture, first);
      expect(next.completedGrades, {1});
      expect(next.currentGrade, 2);
      expect(next.seenGradeCelebrations, {1});
    },
  );
}
