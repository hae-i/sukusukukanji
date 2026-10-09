enum KanjiMasteryStatus { newKanji, learning, familiar, mastered }

/// Immutable learning records; review rules live in ProgressPolicy.
class KanjiProgress {
  const KanjiProgress({
    required this.kanjiId,
    this.status = KanjiMasteryStatus.newKanji,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.consecutiveCorrect = 0,
    this.needsReview = false,
    this.firstStudiedAt,
    this.lastStudiedAt,
  });
  final String kanjiId;
  final KanjiMasteryStatus status;
  final int correctCount;
  final int wrongCount;
  final int consecutiveCorrect;
  final bool needsReview;
  final DateTime? firstStudiedAt;
  final DateTime? lastStudiedAt;

  KanjiProgress forReview() => KanjiProgress(
    kanjiId: kanjiId,
    status: status,
    correctCount: correctCount,
    wrongCount: wrongCount,
    consecutiveCorrect: 0,
    needsReview: true,
    firstStudiedAt: firstStudiedAt,
    lastStudiedAt: lastStudiedAt,
  );
}

class UserProgress {
  UserProgress({
    this.currentGrade = 1,
    this.streak = 0,
    this.lastStudyDate,
    Map<String, KanjiProgress> kanji = const {},
    Set<int> completedGrades = const {},
    Set<int> seenGradeCelebrations = const {},
  }) : kanji = Map.unmodifiable(kanji),
       completedGrades = Set.unmodifiable(completedGrades),
       seenGradeCelebrations = Set.unmodifiable(seenGradeCelebrations);
  final int currentGrade;
  final int streak;
  final DateTime? lastStudyDate;
  final Map<String, KanjiProgress> kanji;
  final Set<int> completedGrades;
  final Set<int> seenGradeCelebrations;

  UserProgress copyWith({
    int? currentGrade,
    int? streak,
    DateTime? lastStudyDate,
    Map<String, KanjiProgress>? kanji,
    Set<int>? completedGrades,
    Set<int>? seenGradeCelebrations,
  }) => UserProgress(
    currentGrade: currentGrade ?? this.currentGrade,
    streak: streak ?? this.streak,
    lastStudyDate: lastStudyDate ?? this.lastStudyDate,
    kanji: kanji ?? this.kanji,
    completedGrades: completedGrades ?? this.completedGrades,
    seenGradeCelebrations: seenGradeCelebrations ?? this.seenGradeCelebrations,
  );
  int get totalLearned =>
      kanji.values.where((p) => p.firstStudiedAt != null).length;
}

class AppIconPreferences {
  AppIconPreferences({
    Set<String> unlockedIcons = const {'grade1'},
    this.selectedIcon = 'grade1',
    Set<String> seenUnlockModals = const {},
  }) : unlockedIcons = Set.unmodifiable(unlockedIcons),
       seenUnlockModals = Set.unmodifiable(seenUnlockModals) {
    if (!this.unlockedIcons.contains(selectedIcon)) {
      throw ArgumentError('The selected icon must be unlocked');
    }
    if (!this.unlockedIcons.containsAll(this.seenUnlockModals)) {
      throw ArgumentError('Seen rewards must be unlocked');
    }
  }
  final Set<String> unlockedIcons;
  final String selectedIcon;
  final Set<String> seenUnlockModals;
}

class AppSettings {
  AppSettings({this.onboardingCompleted = false, AppIconPreferences? icons})
    : icons = icons ?? AppIconPreferences();
  final bool onboardingCompleted;
  final AppIconPreferences icons;
}
