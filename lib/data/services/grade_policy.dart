import '../models/grade_theme.dart';
import '../models/progress.dart';
import '../repositories/kanji_repository.dart';

class GradePolicy {
  const GradePolicy();
  int learnedCount(
    GradeTheme grade,
    KanjiCatalog catalog,
    UserProgress progress,
  ) => catalog
      .forGrade(grade.grade)
      .where((k) => progress.kanji[k.id]?.firstStudiedAt != null)
      .length;
  bool isUnlocked(
    GradeTheme grade,
    KanjiCatalog catalog,
    UserProgress progress,
  ) {
    final index = catalog.grades.indexOf(grade);
    return index == 0 ||
        (index > 0 &&
            progress.completedGrades.contains(catalog.grades[index - 1].grade));
  }

  bool canComplete(
    GradeTheme grade,
    KanjiCatalog catalog,
    UserProgress progress,
  ) {
    final required = grade.requiredKanjiCount;
    final items = catalog.forGrade(grade.grade);
    return required != null &&
        required > 0 &&
        items.length == required &&
        items.map((k) => k.id).toSet().length == required &&
        items.every((k) => progress.kanji[k.id]?.firstStudiedAt != null);
  }

  UserProgress reconcile(KanjiCatalog catalog, UserProgress progress) {
    final completed = {...progress.completedGrades};
    var current = progress.currentGrade;
    for (var i = 0; i < catalog.grades.length; i++) {
      final grade = catalog.grades[i];
      if (i > 0 && !completed.contains(catalog.grades[i - 1].grade)) break;
      if (canComplete(grade, catalog, progress)) completed.add(grade.grade);
      if (completed.contains(grade.grade) && i + 1 < catalog.grades.length) {
        if (catalog.grades[i + 1].grade > current) {
          current = catalog.grades[i + 1].grade;
        }
      }
    }
    return progress.copyWith(currentGrade: current, completedGrades: completed);
  }
}
