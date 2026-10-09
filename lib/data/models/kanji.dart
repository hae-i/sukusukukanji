import 'content_fields.dart';

class ContentReference {
  const ContentReference({required this.label, required this.url});
  final String label;
  final String url;
  factory ContentReference.fromJson(Map<String, dynamic> json, String path) {
    final f = ContentFields(json, path);
    final url = f.string('url');
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw FormatException('$path.url must be an HTTPS reference');
    }
    return ContentReference(label: f.string('label'), url: url);
  }
}

class ExampleWord {
  const ExampleWord({
    required this.word,
    required this.reading,
    required this.meaningKo,
  });
  final String word;
  final String reading;
  final String meaningKo;
  factory ExampleWord.fromJson(Map<String, dynamic> json, String path) {
    final f = ContentFields(json, path);
    return ExampleWord(
      word: f.string('word'),
      reading: f.string('reading'),
      meaningKo: f.string('meaningKo'),
    );
  }
}

/// Sourced sentence pair; reading is omitted when no reviewed transcription exists.
class ExampleSentence {
  const ExampleSentence({
    required this.textJa,
    required this.meaningKo,
    required this.references,
    required this.license,
    required this.licenseUrl,
    this.reading,
  });
  final String textJa;
  final String meaningKo;
  final String? reading;
  final List<ContentReference> references;
  final String license;
  final String licenseUrl;

  factory ExampleSentence.fromJson(Map<String, dynamic> json, String path) {
    final f = ContentFields(json, path);
    final references = f.list(
      'references',
      (v, p) => ContentReference.fromJson(ContentFields.object(v, p), p),
    );
    if (references.length < 2) {
      throw FormatException('$path requires Japanese and Korean attribution');
    }
    final license = ContentReference.fromJson({
      'label': f.string('license'),
      'url': f.string('licenseUrl'),
    }, '$path.license');
    return ExampleSentence(
      textJa: f.string('textJa'),
      meaningKo: f.string('meaningKo'),
      reading: f.optionalString('reading'),
      references: references,
      license: license.label,
      licenseUrl: license.url,
    );
  }
}

class KoreanConnection {
  const KoreanConnection({
    required this.wordKo,
    required this.hanja,
    this.note,
  });
  final String wordKo;
  final String hanja;
  final String? note;
  factory KoreanConnection.fromJson(Map<String, dynamic> json, String path) {
    final f = ContentFields(json, path);
    return KoreanConnection(
      wordKo: f.string('wordKo'),
      hanja: f.string('hanja'),
      note: f.optionalString('note'),
    );
  }
}

class Kanji {
  const Kanji({
    required this.id,
    required this.character,
    required this.grade,
    required this.koreanReading,
    required this.koreanMeanings,
    required this.onyomi,
    required this.kunyomi,
    required this.examples,
    required this.koreanConnections,
    this.sentences = const [],
    this.tip,
    this.lessonId,
    this.lessonOrder,
    this.japaneseCharacter,
    this.traditionalCharacter,
    this.koreanHanja,
    this.references = const [],
    this.allOnyomi = const [],
    this.allKunyomi = const [],
    this.meaningTags = const [],
    this.verifiedAt,
  });
  final String id;
  final String character;
  final int grade;
  final String koreanReading;
  final List<String> koreanMeanings;
  final List<String> onyomi;
  final List<String> kunyomi;
  // Complete sourced readings only exclude valid answers from distractors.
  final List<String> allOnyomi;
  final List<String> allKunyomi;
  // Original dictionary senses exclude synonyms from meaning distractors.
  final List<String> meaningTags;
  final List<ExampleWord> examples;
  final List<ExampleSentence> sentences;
  final List<KoreanConnection> koreanConnections;
  final String? tip;
  final int? lessonId;
  final int? lessonOrder;
  final String? japaneseCharacter;
  final String? traditionalCharacter;
  final String? koreanHanja;
  final List<ContentReference> references;
  final DateTime? verifiedAt;

  factory Kanji.fromJson(Map<String, dynamic> json, {String path = 'kanji'}) {
    final f = ContentFields(json, path);
    final character = f.string('character');
    if (character.runes.length != 1) {
      throw FormatException('$path.character must contain one character');
    }
    final meanings = f.strings('koreanMeanings');
    if (meanings.isEmpty) throw FormatException('$path needs a Korean meaning');
    final lessonId = f.optionalInteger('lessonId');
    final lessonOrder = f.optionalInteger('lessonOrder');
    if ((lessonId == null) != (lessonOrder == null)) {
      throw FormatException('$path requires both lessonId and lessonOrder');
    }
    final date = f.optionalString('verifiedAt');
    final verifiedAt = date == null ? null : DateTime.tryParse(date);
    if (date != null &&
        (verifiedAt == null ||
            verifiedAt.toIso8601String().substring(0, 10) != date)) {
      throw FormatException('$path.verifiedAt must be a valid YYYY-MM-DD');
    }
    final sentences = f.list(
      'sentences',
      (v, p) => ExampleSentence.fromJson(ContentFields.object(v, p), p),
      optional: true,
    );
    if (sentences.any((s) => !s.textJa.contains(character))) {
      throw FormatException('$path sentence must contain the target kanji');
    }
    return Kanji(
      id: f.string('id'),
      character: character,
      grade: f.integer('grade'),
      koreanReading: f.string('koreanReading'),
      koreanMeanings: meanings,
      onyomi: f.strings('onyomi', optional: true),
      kunyomi: f.strings('kunyomi', optional: true),
      allOnyomi: f.strings('allOnyomi', optional: true),
      allKunyomi: f.strings('allKunyomi', optional: true),
      meaningTags: f.strings('meaningTags', optional: true),
      examples: f.list(
        'examples',
        (v, p) => ExampleWord.fromJson(ContentFields.object(v, p), p),
        optional: true,
      ),
      sentences: sentences,
      koreanConnections: f.list(
        'koreanConnections',
        (v, p) => KoreanConnection.fromJson(ContentFields.object(v, p), p),
        optional: true,
      ),
      tip: f.optionalString('tip'),
      lessonId: lessonId,
      lessonOrder: lessonOrder,
      japaneseCharacter: f.optionalString('japaneseCharacter'),
      traditionalCharacter: f.optionalString('traditionalCharacter'),
      koreanHanja: f.optionalString('koreanHanja'),
      references: f.list(
        'references',
        (v, p) => ContentReference.fromJson(ContentFields.object(v, p), p),
        optional: true,
      ),
      verifiedAt: verifiedAt,
    );
  }
}
