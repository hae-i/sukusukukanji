import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/models/study_session.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/data/services/progress_policy.dart';
import 'package:sukusukukanji/data/services/session_planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KanjiCatalog catalog;
  setUp(() async {
    catalog = await AssetKanjiRepository().load();
  });
  CompletedSession complete({
    bool review = false,
    Set<int> wrong = const {},
    DateTime? date,
    int count = 5,
  }) {
    final session = const SessionPlanner().create(
      catalog.kanji.take(count).toList(),
      catalog,
      isReview: review,
    );
    return CompletedSession(
      session: session,
      completedAt: date ?? DateTime(2026, 10, 8, 12),
      answers: [
        for (var i = 0; i < session.questions.length; i++)
          wrong.contains(i)
              ? (session.questions[i].options.indexOf(
                          session.questions[i].answer,
                        ) +
                        1) %
                    session.questions[i].options.length
              : session.questions[i].options.indexOf(
                  session.questions[i].answer,
                ),
      ],
    );
  }

  const policy = ProgressPolicy();
  test('a completed lesson updates all five records and records every wrong answer', () {
    final result = complete(wrong: {0, 5});
    final progress = policy.apply(UserProgress(), result);
    expect(progress.totalLearned, 5);
    expect(progress.streak, 1);
    expect(progress.kanji.values.fold(0, (sum, p) => sum + p.wrongCount), 2);
    expect(progress.kanji.values.fold(0, (sum, p) => sum + p.correctCount), 6);
    expect(
      progress.kanji.values
          .where((p) => p.needsReview)
          .map((p) => p.kanjiId)
          .toSet(),
      result.wrongKanjiIds,
    );
    expect(
      progress.kanji.values.every(
        (p) => p.firstStudiedAt == result.completedAt,
      ),
      isTrue,
    );
  });
  test('two clean review sessions clear review; a later wrong answer resets the streak', () {
    final first = complete(count: 1, wrong: {0});
    var progress = policy.apply(UserProgress(), first);
    final id = first.session.kanji.single.id;
    progress = policy.apply(progress, complete(count: 1, review: true));
    expect(progress.kanji[id]!.needsReview, isTrue);
    expect(progress.kanji[id]!.consecutiveCorrect, 1);
    progress = policy.apply(
      progress,
      complete(count: 1, review: true, wrong: {2}),
    );
    expect(progress.kanji[id]!.consecutiveCorrect, 0);
    expect(progress.kanji[id]!.needsReview, isTrue);
    progress = policy.apply(progress, complete(count: 1, review: true));
    progress = policy.apply(progress, complete(count: 1, review: true));
    expect(progress.kanji[id]!.needsReview, isFalse);
    expect(progress.kanji[id]!.status, KanjiMasteryStatus.mastered);
    expect(progress.kanji[id]!.firstStudiedAt, first.completedAt);
  });
  test('ordinary study cannot clear a manually queued review', () {
    final id = catalog.kanji.first.id;
    final old = UserProgress(
      kanji: {id: KanjiProgress(kanjiId: id).forReview()},
    );
    final next = policy.apply(old, complete(count: 1));
    expect(next.kanji[id]!.needsReview, isTrue);
    expect(next.kanji[id]!.consecutiveCorrect, 0);
  });
  test('streak uses calendar days, ignores same day and backward clock, resets after gap', () {
    var p = policy.apply(
      UserProgress(),
      complete(date: DateTime(2026, 10, 8, 23, 59)),
    );
    p = policy.apply(p, complete(date: DateTime(2026, 10, 9, 0, 1)));
    expect(p.streak, 2);
    p = policy.apply(p, complete(date: DateTime(2026, 10, 9, 22)));
    expect(p.streak, 2);
    p = policy.apply(p, complete(date: DateTime(2026, 10, 7)));
    expect(p.streak, 2);
    expect(p.lastStudyDate, DateTime(2026, 10, 9));
    expect(ProgressPolicy.visibleStreak(p, DateTime(2026, 10, 11)), 0);
    p = policy.apply(p, complete(date: DateTime(2026, 10, 11)));
    expect(p.streak, 1);
  });
  test('review selection includes manual additions, is deterministic and limited to five', () {
    final p = UserProgress(
      kanji: {
        for (final k in catalog.kanji)
          k.id: KanjiProgress(kanjiId: k.id, needsReview: true),
      },
    );
    final items = const SessionPlanner().review(catalog, p);
    expect(items.length, 5);
    expect(
      items.map((k) => k.id),
      orderedEquals(const SessionPlanner().review(catalog, p).map((k) => k.id)),
    );
  });
  test(
    'reviewing new manually added kanji counts learning only after completion',
    () {
      final k = catalog.kanji.first;
      final p = UserProgress(
        kanji: {k.id: KanjiProgress(kanjiId: k.id).forReview()},
      );
      expect(p.totalLearned, 0);
      expect(policy.apply(p, complete(count: 1, review: true)).totalLearned, 1);
    },
  );
}
