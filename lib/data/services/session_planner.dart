import 'dart:math';

import '../models/kanji.dart';
import '../models/progress.dart';
import '../models/study_session.dart';
import '../repositories/kanji_repository.dart';
import 'quiz_generator.dart';

class SessionPlanner {
  const SessionPlanner();
  List<Kanji> nextLesson(
    KanjiCatalog catalog,
    UserProgress progress,
    int grade,
  ) {
    for (final lesson in catalog.lessonsForGrade(grade).values) {
      final remaining = lesson
          .where((k) => progress.kanji[k.id]?.firstStudiedAt == null)
          .take(5)
          .toList();
      if (remaining.isNotEmpty) return remaining;
    }
    return [];
  }

  List<Kanji> review(KanjiCatalog catalog, UserProgress progress) {
    final items = catalog.kanji
        .where((k) => progress.kanji[k.id]?.needsReview ?? false)
        .toList();
    items.sort((a, b) {
      final x = progress.kanji[a.id]!.lastStudiedAt;
      final y = progress.kanji[b.id]!.lastStudiedAt;
      final order = (x ?? DateTime(1970)).compareTo(y ?? DateTime(1970));
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    return items.take(5).toList();
  }

  StudySession create(
    List<Kanji> kanji,
    KanjiCatalog catalog, {
    bool isReview = false,
  }) {
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return StudySession(
      id: id,
      kanji: kanji,
      isReview: isReview,
      questions: QuizGenerator().generate(kanji, catalog.kanji),
    );
  }
}
