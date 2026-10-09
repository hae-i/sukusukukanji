import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/content_fields.dart';
import '../models/grade_theme.dart';
import '../models/kanji.dart';

class KanjiCatalog {
  KanjiCatalog({required List<GradeTheme> grades, required List<Kanji> kanji})
    : grades = List.unmodifiable(grades),
      kanji = List.unmodifiable(kanji);
  final List<GradeTheme> grades;
  final List<Kanji> kanji;
  List<Kanji> forGrade(int grade) =>
      List.unmodifiable(kanji.where((k) => k.grade == grade));

  /// Stable, authored lesson order. This is not a daily-session scheduler.
  Map<int, List<Kanji>> lessonsForGrade(int grade) {
    final groups = <int, List<Kanji>>{};
    for (final item in forGrade(grade)) {
      if (item.lessonId != null) {
        groups.putIfAbsent(item.lessonId!, () => []).add(item);
      }
    }
    final keys = groups.keys.toList()..sort();
    return Map.unmodifiable({
      for (final key in keys)
        key: List<Kanji>.unmodifiable(
          groups[key]!
            ..sort((a, b) => a.lessonOrder!.compareTo(b.lessonOrder!)),
        ),
    });
  }
}

abstract interface class KanjiRepository {
  Future<KanjiCatalog> load();
}

class AssetKanjiRepository implements KanjiRepository {
  AssetKanjiRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;

  @override
  Future<KanjiCatalog> load() async {
    final metadata = _decode(
      await _bundle.loadString('assets/data/grades.json'),
      'grades',
    );
    final grades = metadata.list(
      'grades',
      (v, p) => GradeTheme.fromJson(ContentFields.object(v, p), p),
    );
    if (grades.isEmpty) throw const FormatException('No grade metadata');
    final gradeIds = <int>{};
    final iconKeys = <String>{};
    final ids = <String>{};
    final characters = <String>{};
    final positions = <String>{};
    final all = <Kanji>[];
    for (final grade in grades) {
      if (!gradeIds.add(grade.grade) || !iconKeys.add(grade.iconKey)) {
        throw FormatException('Duplicate grade or icon: ${grade.grade}');
      }
      final path = grade.contentAsset;
      if (path == null) continue;
      if (!path.startsWith('assets/data/kanji/') || path.contains('..')) {
        throw FormatException('Invalid content asset: $path');
      }
      final content = _decode(await _bundle.loadString(path), path);
      if (content.integer('grade') != grade.grade) {
        throw FormatException('$path grade does not match metadata');
      }
      final items = content.list(
        'kanji',
        (v, p) => Kanji.fromJson(ContentFields.object(v, p), path: p),
      );
      if (grade.requiredKanjiCount == null ||
          items.length > grade.requiredKanjiCount!) {
        throw FormatException('$path requires a valid full-course count');
      }
      for (final item in items) {
        if (item.grade != grade.grade) {
          throw FormatException('$path: wrong grade for ${item.id}');
        }
        if (!ids.add(item.id) || !characters.add(item.character)) {
          throw FormatException('$path: duplicate kanji ${item.id}');
        }
        if (item.lessonId != null &&
            !positions.add(
              '${item.grade}:${item.lessonId}:${item.lessonOrder}',
            )) {
          throw FormatException('$path: duplicate lesson position ${item.id}');
        }
      }
      all.addAll(items);
    }
    final sortedGrades = grades.toList()
      ..sort((a, b) => a.grade.compareTo(b.grade));
    return KanjiCatalog(grades: sortedGrades, kanji: all);
  }

  ContentFields _decode(String text, String path) {
    final fields = ContentFields(
      ContentFields.object(jsonDecode(text), path),
      path,
    );
    if (fields.integer('schemaVersion') != 1) {
      throw FormatException('$path: unsupported schemaVersion');
    }
    return fields;
  }
}
