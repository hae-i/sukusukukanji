import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/content_fields.dart';
import '../models/course_allocation.dart';
import '../models/grade_theme.dart';
import '../models/kanji.dart';

class KanjiCatalog {
  KanjiCatalog({
    required List<GradeTheme> grades,
    required List<Kanji> kanji,
    Map<int, CourseAllocation> allocations = const {},
  }) : grades = List.unmodifiable(grades),
       kanji = List.unmodifiable(kanji),
       allocations = Map.unmodifiable(allocations);
  final List<GradeTheme> grades;
  final List<Kanji> kanji;
  final Map<int, CourseAllocation> allocations;
  List<GradeTheme> get iconThemes {
    final seen = <String>{};
    return List.unmodifiable(grades.where((g) => seen.add(g.iconKey)));
  }

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
    final iconKeys = <String, GradeTheme>{};
    final allocations = <int, CourseAllocation>{};
    final allocationDocuments = <String, ContentFields>{};
    final allocatedCharacters = <String>{};
    final ids = <String>{};
    final characters = <String>{};
    final positions = <String>{};
    final all = <Kanji>[];
    for (final grade in grades) {
      if (!gradeIds.add(grade.grade)) {
        throw FormatException('Duplicate grade: ${grade.grade}');
      }
      final previousIcon = iconKeys[grade.iconKey];
      if (previousIcon != null &&
          (grade.schoolLevel != SchoolLevel.middle ||
              previousIcon.plantStage != grade.plantStage)) {
        throw FormatException('Duplicate icon: ${grade.iconKey}');
      }
      iconKeys.putIfAbsent(grade.iconKey, () => grade);
      final allocationPath = grade.allocationAsset;
      if (allocationPath != null) {
        if (!allocationPath.startsWith('assets/data/') ||
            allocationPath.contains('..')) {
          throw FormatException('Invalid allocation asset: $allocationPath');
        }
        final document = allocationDocuments[allocationPath] ??= _decode(
          await _bundle.loadString(allocationPath),
          allocationPath,
        );
        final courses = document.list(
          'courses',
          (v, p) => CourseAllocation.fromJson(
            ContentFields.object(v, p),
            document.json,
            p,
          ),
        );
        final matches = courses.where((c) => c.grade == grade.grade).toList();
        if (matches.length != 1 ||
            matches.single.characters.length != grade.requiredKanjiCount ||
            matches.single.schoolYear != grade.schoolYear) {
          throw FormatException(
            '$allocationPath: allocation does not match grade ${grade.grade}',
          );
        }
        final allocation = matches.single;
        for (final character in allocation.characters) {
          if (!allocatedCharacters.add(character)) {
            throw FormatException(
              '$allocationPath: repeated allocation $character',
            );
          }
        }
        allocations[grade.grade] = allocation;
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
    for (final item in all) {
      final allocation = allocations[item.grade];
      if ((allocation != null &&
              !allocation.characters.contains(item.character)) ||
          (allocation == null &&
              allocatedCharacters.contains(item.character))) {
        throw FormatException(
          'Kanji ${item.id} conflicts with course allocation',
        );
      }
    }
    return KanjiCatalog(
      grades: sortedGrades,
      kanji: all,
      allocations: allocations,
    );
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
