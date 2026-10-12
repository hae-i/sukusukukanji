import 'dart:convert';

import '../models/progress.dart';
import '../repositories/kanji_repository.dart';
import '../storage/progress_mapping.dart';

/// Learning data only. Store purchases, ad credits, and auth tokens never travel
/// through a user-editable progress backup.
abstract final class ProgressSnapshot {
  static Map<String, dynamic> encode(UserProgress p) => {
    'version': 1,
    'currentGrade': p.currentGrade,
    'streak': p.streak,
    'lastStudyDate': p.lastStudyDate?.toIso8601String(),
    'kanji': p.kanji.values.map(ProgressMapping.encode).toList(),
    'favorites': p.favoriteKanjiIds.toList(),
    'completedGrades': p.completedGrades.toList(),
    'seenGradeCelebrations': p.seenGradeCelebrations.toList(),
  };

  static UserProgress decode(Map<String, dynamic> json, KanjiCatalog catalog) {
    try {
      if (json['version'] != 1 ||
          utf8.encode(jsonEncode(json)).length > 2000000) {
        throw const FormatException('Unsupported backup');
      }
      final knownIds = catalog.kanji.map((k) => k.id).toSet();
      final knownGrades = catalog.grades.map((g) => g.grade).toSet();
      final rows = (json['kanji'] as List)
          .map(
            (row) =>
                ProgressMapping.decode(Map<String, Object?>.from(row as Map)),
          )
          .toList();
      final favorites = (json['favorites'] as List).cast<String>().toSet();
      final completed = (json['completedGrades'] as List).cast<int>().toSet();
      final seen = (json['seenGradeCelebrations'] as List).cast<int>().toSet();
      final grade = json['currentGrade'] as int;
      final streak = json['streak'] as int;
      if (rows.length != rows.map((r) => r.kanjiId).toSet().length ||
          !knownIds.containsAll(rows.map((r) => r.kanjiId)) ||
          !knownIds.containsAll(favorites) ||
          !knownGrades.contains(grade) ||
          !knownGrades.containsAll(completed) ||
          !completed.containsAll(seen) ||
          streak < 0) {
        throw const FormatException('Incompatible backup');
      }
      return UserProgress(
        currentGrade: grade,
        streak: streak,
        lastStudyDate: json['lastStudyDate'] == null
            ? null
            : DateTime.parse(json['lastStudyDate'] as String),
        kanji: {for (final row in rows) row.kanjiId: row},
        favoriteKanjiIds: favorites,
        completedGrades: completed,
        seenGradeCelebrations: seen,
      );
    } catch (_) {
      throw const FormatException('Cannot restore this progress backup');
    }
  }
}
