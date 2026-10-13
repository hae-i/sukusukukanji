import '../../data/models/kanji.dart';
import '../../data/models/progress.dart';

enum KanjiFilter {
  all('전체'),
  learned('배운 한자'),
  review('헷갈리는 한자'),
  favorites('즐겨찾기');

  const KanjiFilter(this.label);
  final String label;
}

enum KanjiSort {
  lesson('학습 순서'),
  koreanReading('한자음 가나다순'),
  recent('최근 학습순');

  const KanjiSort(this.label);
  final String label;
}

/// All fields come from the reviewed catalog. Search never creates readings.
abstract final class KanjiBrowser {
  static List<Kanji> select(
    Iterable<Kanji> catalog,
    UserProgress progress, {
    String query = '',
    int? grade,
    KanjiFilter filter = KanjiFilter.all,
    KanjiSort sort = KanjiSort.lesson,
  }) {
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map(_normalize)
        .toList();
    final result = catalog.where((k) {
      if (grade != null && grade != k.grade) return false;
      final record = progress.kanji[k.id];
      final matchesStatus = switch (filter) {
        KanjiFilter.all => true,
        KanjiFilter.learned => record?.firstStudiedAt != null,
        KanjiFilter.review => record?.needsReview ?? false,
        KanjiFilter.favorites => progress.favoriteKanjiIds.contains(k.id),
      };
      if (!matchesStatus) return false;
      if (terms.isEmpty) return true;
      final fields = [
        k.character,
        k.koreanReading,
        ...k.koreanMeanings,
        ...k.onyomi,
        ...k.kunyomi,
        if (k.japaneseCharacter != null) k.japaneseCharacter!,
        if (k.traditionalCharacter != null) k.traditionalCharacter!,
        if (k.koreanHanja != null) k.koreanHanja!,
        for (final word in k.examples) ...[
          word.word,
          word.reading,
          word.meaningKo,
        ],
        for (final connection in k.koreanConnections) ...[
          connection.wordKo,
          connection.hanja,
        ],
      ].map(_normalize).toList();
      return terms.every((term) => fields.any((field) => field.contains(term)));
    }).toList();
    result.sort((a, b) {
      if (sort == KanjiSort.koreanReading) {
        final order = a.koreanReading.compareTo(b.koreanReading);
        if (order != 0) return order;
      } else if (sort == KanjiSort.recent) {
        final ap = progress.kanji[a.id], bp = progress.kanji[b.id];
        final ad = ap?.lastStudiedAt ?? ap?.firstStudiedAt;
        final bd = bp?.lastStudiedAt ?? bp?.firstStudiedAt;
        if (ad != null && bd == null) return -1;
        if (ad == null && bd != null) return 1;
        if (ad != null && bd != null) {
          final order = bd.compareTo(ad);
          if (order != 0) return order;
        }
      }
      return _lessonOrder(a, b);
    });
    return result;
  }

  static int _lessonOrder(Kanji a, Kanji b) {
    for (final (left, right) in [
      (a.grade, b.grade),
      (a.lessonId ?? 0x7fffffff, b.lessonId ?? 0x7fffffff),
      (a.lessonOrder ?? 0x7fffffff, b.lessonOrder ?? 0x7fffffff),
    ]) {
      final order = left.compareTo(right);
      if (order != 0) return order;
    }
    return a.id.compareTo(b.id);
  }

  static String _normalize(String text) => String.fromCharCodes(
    text.toLowerCase().runes.map(
      (r) => r >= 0x30a1 && r <= 0x30f6 ? r - 0x60 : r,
    ),
  ).replaceAll(RegExp(r'[\s.·]'), '');
}
