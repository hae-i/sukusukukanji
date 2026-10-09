import 'content_fields.dart';
import 'kanji.dart';

/// An authored character list, kept separate from reviewed learning cards.
class CourseAllocation {
  CourseAllocation({
    required this.grade,
    required this.schoolYear,
    required List<String> characters,
    required this.noteKo,
    required this.orderingKo,
    required List<ContentReference> references,
  }) : characters = List.unmodifiable(characters),
       references = List.unmodifiable(references);

  final int grade;
  final int schoolYear;
  final List<String> characters;
  final String noteKo;
  final String orderingKo;
  final List<ContentReference> references;

  factory CourseAllocation.fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> document,
    String path,
  ) {
    final f = ContentFields(json, path);
    final source = ContentFields(document, path);
    final characters = f.strings('characters');
    final year = f.integer('schoolYear');
    if (year > 3) throw FormatException('$path has an invalid school year');
    if (characters.length != f.integer('count') ||
        characters.any((c) => c.runes.length != 1) ||
        characters.toSet().length != characters.length) {
      throw FormatException(
        '$path needs a unique character list matching count',
      );
    }
    final references = source.list(
      'references',
      (v, p) => ContentReference.fromJson(ContentFields.object(v, p), p),
    );
    if (references.isEmpty) throw FormatException('$path needs sources');
    return CourseAllocation(
      grade: f.integer('grade'),
      schoolYear: year,
      characters: characters,
      noteKo: source.string('noteKo'),
      orderingKo: source.string('orderingKo'),
      references: references,
    );
  }
}
