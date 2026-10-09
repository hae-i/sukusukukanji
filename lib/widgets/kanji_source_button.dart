import 'package:flutter/material.dart';

import '../data/models/kanji.dart';
import 'mixed_language_text.dart';

/// Keep attribution available without interrupting the learning card.
class KanjiSourceButton extends StatelessWidget {
  const KanjiSourceButton({super.key, required this.kanji});
  final Kanji kanji;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '학습 자료 출처',
    icon: const Icon(Icons.info_outline),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학습 자료 출처'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(child: _SourceContent(kanji: kanji)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    ),
  );
}

class _SourceContent extends StatelessWidget {
  const _SourceContent({required this.kanji});
  final Kanji kanji;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sentences = kanji.grade == 1 ? kanji.sentences : <ExampleSentence>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MixedLanguageText(
          '${kanji.character} · ${kanji.koreanReading}',
          style: text.titleLarge,
        ),
        const SizedBox(height: 16),
        Text('한자 정보', style: text.titleMedium),
        if (kanji.references.isEmpty) const Text('등록된 출처가 없어요.'),
        for (final reference in kanji.references)
          _ReferenceText(reference: reference),
        if (kanji.references.isNotEmpty) ...[
          const SelectableText(
            '한자 데이터 · CC BY-SA 4.0\nhttps://creativecommons.org/licenses/by-sa/4.0/',
          ),
          const SizedBox(height: 8),
          const Text('대표 읽기를 선별하고, 훈독의 구분점을 제거했으며 한국어 설명과 학습 순서를 덧붙였어요.'),
        ],
        if (kanji.verifiedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            '한자 정보 확인일 ${kanji.verifiedAt!.toIso8601String().substring(0, 10)}',
          ),
        ],
        for (final sentence in sentences) ...[
          const SizedBox(height: 24),
          Text('예문', style: text.titleMedium),
          Text(
            sentence.textJa,
            locale: const Locale('ja'),
            style: text.bodyLarge?.copyWith(fontFamily: 'NotoSansJP'),
          ),
          for (final reference in sentence.references)
            _ReferenceText(reference: reference),
          SelectableText('${sentence.license}\n${sentence.licenseUrl}'),
          const SizedBox(height: 8),
          const Text(
            '일본어 원문과 한국어 번역은 그대로 사용했어요. 검토된 읽기가 있는 경우 전사 마크업을 제거해 표시해요.',
          ),
        ],
      ],
    );
  }
}

class _ReferenceText extends StatelessWidget {
  const _ReferenceText({required this.reference});
  final ContentReference reference;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: SelectableText('${reference.label}\n${reference.url}'),
  );
}
