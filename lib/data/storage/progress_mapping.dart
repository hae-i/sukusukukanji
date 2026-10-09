import '../models/progress.dart';

abstract final class ProgressMapping {
  static Map<String, Object?> encode(KanjiProgress progress) => {
    'kanji_id': progress.kanjiId,
    'status': progress.status.name,
    'correct_count': progress.correctCount,
    'wrong_count': progress.wrongCount,
    'consecutive_correct': progress.consecutiveCorrect,
    'needs_review': progress.needsReview ? 1 : 0,
    'first_studied_at': progress.firstStudiedAt?.toIso8601String(),
    'last_studied_at': progress.lastStudiedAt?.toIso8601String(),
  };
  static KanjiProgress decode(Map<String, Object?> row) {
    final status = KanjiMasteryStatus.values.where(
      (s) => s.name == row['status'],
    );
    if (status.isEmpty) {
      throw FormatException('Invalid mastery status: ${row['status']}');
    }
    final correct = row['correct_count'] as int;
    final wrong = row['wrong_count'] as int;
    final consecutive = row['consecutive_correct'] as int;
    if (correct < 0 ||
        wrong < 0 ||
        consecutive < 0 ||
        ![0, 1].contains(row['needs_review'])) {
      throw const FormatException('Invalid progress counters');
    }
    return KanjiProgress(
      kanjiId: row['kanji_id'] as String,
      status: status.single,
      correctCount: correct,
      wrongCount: wrong,
      consecutiveCorrect: consecutive,
      needsReview: row['needs_review'] == 1,
      firstStudiedAt: _date(row['first_studied_at']),
      lastStudiedAt: _date(row['last_studied_at']),
    );
  }

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
