import 'dart:math';

import '../models/kanji.dart';
import '../models/study_session.dart';

class QuizGenerator {
  QuizGenerator({Random? random}) : _random = random ?? Random();
  final Random _random;

  List<QuizQuestion> generate(List<Kanji> selected, List<Kanji> corpus) {
    final candidates = <String, List<QuizQuestion>>{};
    for (final kanji in selected) {
      candidates[kanji.id] = [
        for (final kind in QuizKind.values)
          if (_question(kanji, kind, corpus) case final QuizQuestion q) q,
      ];
      if (candidates[kanji.id]!.isEmpty) {
        throw StateError('${kanji.id}: not enough verified quiz choices');
      }
    }
    // Each kanji is assessed at least once; remaining questions add variety.
    final result = <QuizQuestion>[];
    for (var i = 0; i < selected.length; i++) {
      final available = candidates[selected[i].id]!;
      result.add(available.removeAt(i % available.length));
    }
    final extra = candidates.values.expand((q) => q).toList()..shuffle(_random);
    result.addAll(extra.take(max(0, 8 - result.length)));
    return List.unmodifiable(result);
  }

  QuizQuestion? _question(Kanji kanji, QuizKind kind, List<Kanji> corpus) {
    late String answer, prompt, instruction, explanation;
    late Set<String> accepted;
    late Iterable<String> pool;
    switch (kind) {
      case QuizKind.meaning:
        answer = kanji.koreanMeanings.first;
        prompt = kanji.character;
        instruction = '이 한자의 뜻은?';
        accepted = kanji.koreanMeanings.toSet();
        pool = corpus
            .where(
              (k) =>
                  k.id != kanji.id &&
                  !k.meaningTags.any(kanji.meaningTags.contains),
            )
            .expand((k) => k.koreanMeanings);
        explanation =
            '${kanji.character}은(는) ${kanji.koreanMeanings.join(' · ')}을(를) 뜻해요.';
      case QuizKind.reading:
        final useKun = kanji.kunyomi.isNotEmpty;
        final readings = useKun ? kanji.kunyomi : kanji.onyomi;
        if (readings.isEmpty) return null;
        answer = readings.first;
        prompt = kanji.character;
        instruction = useKun ? '대표적인 훈독은?' : '대표적인 음독은?';
        accepted = {
          ...readings,
          ...(useKun ? kanji.allKunyomi : kanji.allOnyomi),
        };
        pool = corpus.expand((k) => useKun ? k.kunyomi : k.onyomi);
        explanation =
            '${kanji.character}의 ${useKun ? '훈독' : '음독'}에는 ${readings.join(' · ')}이(가) 있어요.';
      case QuizKind.wordReading:
        if (kanji.examples.isEmpty) return null;
        final example = kanji.examples.last;
        answer = example.reading;
        prompt = example.word;
        instruction = '이 단어를 어떻게 읽을까요?';
        // Exclude all known alternate readings of the same word, including
        // the character's readings when a numeral itself is the example.
        accepted = {
          example.reading,
          ...corpus
              .expand((k) => k.examples)
              .where((w) => w.word == example.word)
              .map((w) => w.reading),
          if (example.word == kanji.character) ...[
            ...kanji.kunyomi,
            ...kanji.allKunyomi,
          ],
          if (example.word == kanji.character)
            ...[...kanji.onyomi, ...kanji.allOnyomi].map(_hiragana),
        };
        pool = corpus.expand((k) => k.examples).map((e) => e.reading);
        explanation =
            '${example.word} → ${example.reading}\n${example.meaningKo}';
    }
    final distractors = pool.toSet().difference(accepted).toList()
      ..shuffle(_random);
    if (distractors.isEmpty) return null;
    final options = [answer, ...distractors.take(3)]..shuffle(_random);
    return QuizQuestion(
      id: '${kanji.id}:${kind.name}',
      kanjiId: kanji.id,
      kind: kind,
      prompt: prompt,
      instruction: instruction,
      answer: answer,
      options: options,
      explanation: explanation,
    );
  }

  String _hiragana(String value) => String.fromCharCodes(
    value.runes.map((r) => r >= 0x30a1 && r <= 0x30f6 ? r - 0x60 : r),
  );
}
