import '../models/progress.dart';
import '../models/study_session.dart';

class ProgressPolicy {
  const ProgressPolicy();
  static const reviewSuccessesRequired = 2;

  UserProgress apply(UserProgress previous, CompletedSession completed) {
    final records = Map<String, KanjiProgress>.from(previous.kanji);
    for (final kanji in completed.session.kanji) {
      final old = records[kanji.id] ?? KanjiProgress(kanjiId: kanji.id);
      var correct = 0, wrong = 0;
      for (var i = 0; i < completed.answers.length; i++) {
        if (completed.session.questions[i].kanjiId != kanji.id) continue;
        if (completed.isCorrect(i)) {
          correct++;
        } else {
          wrong++;
        }
      }
      // One success per complete, error-free review of a kanji, not per option.
      final consecutive = wrong > 0
          ? 0
          : completed.session.isReview
          ? old.consecutiveCorrect + 1
          : old.consecutiveCorrect;
      final needsReview =
          wrong > 0 ||
          (old.needsReview &&
              !(completed.session.isReview &&
                  consecutive >= reviewSuccessesRequired));
      final status = needsReview
          ? KanjiMasteryStatus.learning
          : consecutive >= reviewSuccessesRequired
          ? KanjiMasteryStatus.mastered
          : KanjiMasteryStatus.familiar;
      records[kanji.id] = KanjiProgress(
        kanjiId: kanji.id,
        status: status,
        correctCount: old.correctCount + correct,
        wrongCount: old.wrongCount + wrong,
        consecutiveCorrect: consecutive,
        needsReview: needsReview,
        firstStudiedAt: old.firstStudiedAt ?? completed.completedAt,
        lastStudiedAt: completed.completedAt,
      );
    }
    final today = calendarDay(completed.completedAt);
    final last = previous.lastStudyDate == null
        ? null
        : calendarDay(previous.lastStudyDate!);
    final delta = last == null ? null : today.difference(last).inDays;
    // A clock moving backwards must not erase a streak or move the date back.
    final streak = delta == null
        ? 1
        : delta <= 0
        ? previous.streak
        : delta == 1
        ? previous.streak + 1
        : 1;
    return previous.copyWith(
      kanji: records,
      streak: streak,
      lastStudyDate: last != null && today.isBefore(last)
          ? previous.lastStudyDate
          : DateTime(today.year, today.month, today.day),
    );
  }

  static DateTime calendarDay(DateTime value) {
    final local = value.toLocal();
    // UTC arithmetic on local calendar components avoids 23/25-hour DST days.
    return DateTime.utc(local.year, local.month, local.day);
  }

  static int visibleStreak(UserProgress progress, DateTime now) {
    if (progress.lastStudyDate == null) return 0;
    return calendarDay(now)
                .difference(calendarDay(progress.lastStudyDate!))
                .inDays >
            1
        ? 0
        : progress.streak;
  }
}
