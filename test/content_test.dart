import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/data/models/kanji.dart';
import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/repositories/kanji_repository.dart';

Map<String, dynamic> sampleJson() =>
    (jsonDecode(File('assets/data/kanji/grade1.json').readAsStringSync())
        as Map<String, dynamic>);

class JsonBundle extends CachingAssetBundle {
  JsonBundle(this.documents);
  final Map<String, Object> documents;
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      jsonEncode(documents[key]);
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> metadata;
  late Map<String, dynamic> content;
  late AssetKanjiRepository repository;
  setUp(() {
    metadata = jsonDecode(
      File('assets/data/grades.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    content = sampleJson();
    repository = AssetKanjiRepository(
      bundle: JsonBundle({
        'assets/data/grades.json': metadata,
        'assets/data/kanji/grade1.json': content,
      }),
    );
  });

  test(
    'real bundled assets load offline with eighty sourced entries',
    () async {
      final catalog = await AssetKanjiRepository().load();
      expect(
        catalog.kanji.take(10).map((k) => k.character).join(),
        '一二三四五六七八九十',
      );
      expect(catalog.kanji.length, 80);
      expect(catalog.grades.length, 6);
      expect(catalog.grades.first.requiredKanjiCount, 80);
      expect(
        catalog.kanji.every(
          (k) => k.references.isNotEmpty && k.verifiedAt != null,
        ),
        isTrue,
      );
      expect(
        catalog.grades.skip(1).every((g) => g.contentAsset == null),
        isTrue,
      );
    },
  );

  test('lessons preserve authored order even if JSON is shuffled', () async {
    content['kanji'] = (content['kanji'] as List).reversed.toList();
    final catalog = await repository.load();
    final lessons = catalog.lessonsForGrade(1);
    expect(lessons.keys, List.generate(16, (i) => i + 1));
    expect(lessons.values.every((v) => v.length == 5), isTrue);
    expect(lessons[1]!.map((k) => k.character).join(), '一二三四五');
    expect(lessons[2]!.map((k) => k.character).join(), '六七八九十');
    expect(() => lessons[1]!.clear(), throwsUnsupportedError);
    expect(catalog.lessonsForGrade(2), isEmpty);
  });

  test('full grade exactly matches the required course size', () async {
    final catalog = await repository.load();
    expect(
      catalog.forGrade(1).length,
      catalog.grades.first.requiredKanjiCount!,
    );
  });

  test('missing optional content is safe and immutable', () {
    final data = Map<String, dynamic>.from(
      (content['kanji'] as List).first as Map,
    );
    for (final key in [
      'kunyomi',
      'onyomi',
      'examples',
      'koreanConnections',
      'tip',
      'references',
      'verifiedAt',
      'lessonId',
      'lessonOrder',
    ]) {
      data.remove(key);
    }
    final kanji = Kanji.fromJson(data);
    expect(kanji.kunyomi, isEmpty);
    expect(kanji.examples, isEmpty);
    expect(kanji.koreanConnections, isEmpty);
    expect(kanji.tip, isNull);
    expect(() => kanji.koreanMeanings.add('wrong'), throwsUnsupportedError);
  });

  for (final change in <String, Object?>{
    'koreanReading': '',
    'character': '一二',
    'koreanMeanings': [],
    'kunyomi': 'ひとつ',
    'examples': [
      {'word': '一'},
    ],
    'lessonOrder': 0,
    'verifiedAt': '2026-02-30',
    'references': [
      {'label': 'invalid', 'url': 'http://example.com'},
    ],
  }.entries) {
    test('reject malformed ${change.key} with field context', () {
      final data = Map<String, dynamic>.from(
        (content['kanji'] as List).first as Map,
      );
      data[change.key] = change.value;
      expect(() => Kanji.fromJson(data), throwsFormatException);
    });
  }

  test('reject unsupported content schema', () async {
    content['schemaVersion'] = 99;
    await expectLater(repository.load(), throwsFormatException);
  });
  test('reject duplicate kanji', () async {
    (content['kanji'] as List).add((content['kanji'] as List).first);
    await expectLater(repository.load(), throwsFormatException);
  });
  test('reject duplicate lesson positions', () async {
    (content['kanji'] as List)[1]['lessonOrder'] = 1;
    await expectLater(repository.load(), throwsFormatException);
  });
  test('reject inconsistent grade', () async {
    (content['kanji'] as List)[0]['grade'] = 2;
    await expectLater(repository.load(), throwsFormatException);
  });
  test('reject duplicate grade metadata', () async {
    (metadata['grades'] as List).add((metadata['grades'] as List).first);
    await expectLater(repository.load(), throwsFormatException);
  });
  test('default progress is empty, selected icon must be unlocked', () {
    expect(UserProgress().totalLearned, 0);
    expect(AppSettings().onboardingCompleted, isFalse);
    expect(AppSettings().icons.selectedIcon, 'grade1');
    expect(
      () => AppIconPreferences(selectedIcon: 'grade2'),
      throwsArgumentError,
    );
    expect(
      () => AppIconPreferences(seenUnlockModals: {'grade2'}),
      throwsArgumentError,
    );
  });
}
