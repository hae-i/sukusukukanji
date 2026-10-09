import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/app/theme/app_theme.dart';
import 'package:sukusukukanji/data/models/kanji.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';
import 'package:sukusukukanji/widgets/kanji_content.dart';
import 'package:sukusukukanji/widgets/kanji_source_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KanjiCatalog catalog;
  setUpAll(() async => catalog = await AssetKanjiRepository().load());

  test('sentence assets match reviewed provenance and contain the target kanji', () {
    final audit = jsonDecode(
      File('docs/content/grade1-sentences-audit.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final entries = audit['entries'] as List;
    final withSentences = catalog.kanji
        .where((k) => k.sentences.isNotEmpty)
        .toList();
    expect(withSentences.length, entries.length);
    expect(withSentences.length, 77);
    for (final kanji in withSentences) {
      expect(kanji.grade, 1);
      final provenance = entries.singleWhere((e) => e['kanjiId'] == kanji.id);
      for (final sentence in kanji.sentences) {
        expect(sentence.textJa, contains(kanji.character));
        expect(sentence.meaningKo, matches(RegExp('[가-힣]')));
        expect(
          sentence.references.map((r) => r.url),
          containsAll([
            'https://tatoeba.org/en/sentences/show/${provenance['japaneseSentenceId']}',
            'https://tatoeba.org/en/sentences/show/${provenance['koreanSentenceId']}',
          ]),
        );
        expect(sentence.license, 'CC BY 2.0 FR');
        expect(
          sentence.licenseUrl,
          'https://creativecommons.org/licenses/by/2.0/fr/',
        );
        expect(provenance['readingIncluded'], sentence.reading != null);
        if (sentence.reading != null) {
          expect(sentence.reading, isNot(matches(RegExp(r'[\[\]|]'))));
        }
      }
    }
    expect(
      catalog.kanji.where((k) => k.sentences.isEmpty).map((k) => k.character),
      audit['remainingCharacters'],
    );
  });

  test('sentences are optional; missing attribution or invalid license fails parsing', () {
    final data =
        (jsonDecode(
                      File('assets/data/kanji/grade1.json').readAsStringSync(),
                    )['kanji']
                    as List)
                .first
            as Map<String, dynamic>;
    final without = Map<String, dynamic>.from(data)..remove('sentences');
    expect(Kanji.fromJson(without).sentences, isEmpty);
    final sentence = Map<String, dynamic>.from(
      (data['sentences'] as List).first as Map,
    );
    sentence['references'] = [];
    expect(
      () => Kanji.fromJson({
        ...data,
        'sentences': [sentence],
      }),
      throwsFormatException,
    );
    sentence.addAll((data['sentences'] as List).first as Map<String, dynamic>);
    sentence['licenseUrl'] = 'http://invalid.test';
    expect(
      () => Kanji.fromJson({
        ...data,
        'sentences': [sentence],
      }),
      throwsFormatException,
    );
  });

  testWidgets(
    'sourced grade one sentence, optional reading and attribution render at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final kanji = catalog.kanji.firstWhere((k) => k.character == '竹');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            appBar: AppBar(actions: [KanjiSourceButton(kanji: kanji)]),
            body: SingleChildScrollView(child: KanjiContent(kanji: kanji)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('문장으로 연결하기'), findsOneWidget);
      expect(find.text(kanji.sentences.single.textJa), findsOneWidget);
      expect(find.text(kanji.sentences.single.meaningKo), findsOneWidget);
      expect(find.text('예문 출처'), findsNothing);
      expect(find.text('콘텐츠 출처'), findsNothing);
      await tester.tap(find.byTooltip('학습 자료 출처'));
      await tester.pumpAndSettle();
      expect(find.textContaining('CC BY 2.0 FR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
