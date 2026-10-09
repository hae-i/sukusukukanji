import 'package:flutter/material.dart';

import '../data/models/kanji.dart';
import 'content_layout.dart';

class KanjiContent extends StatelessWidget {
  const KanjiContent({super.key, required this.kanji});
  final Kanji kanji;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            children: [
              Text(
                kanji.character,
                locale: const Locale('ja'),
                semanticsLabel: '${kanji.character}, ${kanji.koreanReading}',
                style: const TextStyle(fontSize: 112, height: 1.3),
              ),
              Text(
                '${kanji.koreanMeanings.join(' · ')} ${kanji.koreanReading}',
                style: text.titleLarge,
              ),
              const SizedBox(height: 24),
              if (kanji.onyomi.isNotEmpty)
                _Reading(label: '대표 음독', values: kanji.onyomi),
              if (kanji.kunyomi.isNotEmpty)
                _Reading(label: '대표 훈독', values: kanji.kunyomi),
            ],
          ),
        ),
        if (kanji.koreanConnections.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionCard(
            color: const Color(0xFFEAF0E3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('한국어랑 연결하기', style: text.titleMedium),
                for (final connection in kanji.koreanConnections) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${connection.wordKo}(${connection.hanja})',
                    style: text.titleLarge,
                  ),
                  if (connection.note != null) Text(connection.note!),
                ],
              ],
            ),
          ),
        ],
        if (kanji.examples.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('일본어 단어', style: text.titleLarge),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < kanji.examples.length; i++) ...[
                  if (i > 0) const Divider(height: 32),
                  ExampleWordRow(example: kanji.examples[i]),
                ],
              ],
            ),
          ),
        ],
        if (kanji.tip != null) ...[
          const SizedBox(height: 20),
          Text(kanji.tip!),
        ],
        if (kanji.traditionalCharacter != null ||
            kanji.koreanHanja != null) ...[
          const SizedBox(height: 20),
          if (kanji.traditionalCharacter != null)
            Text('전통 자형: ${kanji.traditionalCharacter}'),
          if (kanji.koreanHanja != null) Text('한국 한자 자형: ${kanji.koreanHanja}'),
        ],
        if (kanji.references.isNotEmpty) ...[
          const SizedBox(height: 24),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('콘텐츠 출처'),
            children: [
              for (final reference in kanji.references)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      '${reference.label}\n${reference.url}',
                    ),
                  ),
                ),
              if (kanji.verifiedAt != null)
                Text(
                  '확인일 ${kanji.verifiedAt!.toIso8601String().substring(0, 10)}',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.label, required this.values});
  final String label;
  final List<String> values;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      children: [
        Text(label),
        Text(
          values.join(' · '),
          locale: const Locale('ja'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    ),
  );
}

class ExampleWordRow extends StatelessWidget {
  const ExampleWordRow({super.key, required this.example});
  final ExampleWord example;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        example.word,
        locale: const Locale('ja'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(
        example.reading,
        locale: const Locale('ja'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      Text(example.meaningKo),
    ],
  );
}
