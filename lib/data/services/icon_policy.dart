import '../models/progress.dart';
import '../repositories/kanji_repository.dart';

class IconPolicy {
  const IconPolicy();
  AppIconPreferences reconcile(
    KanjiCatalog catalog,
    UserProgress progress,
    AppIconPreferences previous,
  ) {
    final grades = catalog.grades;
    if (grades.isEmpty) return previous;
    final unlocked = <String>{if (grades.isNotEmpty) grades.first.iconKey};
    for (var i = 0; i < grades.length - 1; i++) {
      if (progress.completedGrades.contains(grades[i].grade)) {
        unlocked.add(grades[i + 1].iconKey);
      }
    }
    return AppIconPreferences(
      unlockedIcons: unlocked,
      selectedIcon: unlocked.contains(previous.selectedIcon)
          ? previous.selectedIcon
          : grades.first.iconKey,
      seenUnlockModals: previous.seenUnlockModals.intersection(unlocked),
    );
  }
}
