import 'content_fields.dart';

enum SchoolLevel { elementary, middle }

enum PlantStage {
  sprout,
  youngPlant,
  growingPlant,
  sapling,
  youngTree,
  fullTree,
}

class GradeTheme {
  const GradeTheme({
    required this.grade,
    required this.nameKo,
    required this.plantStage,
    required this.stageNameKo,
    required this.iconKey,
    this.requiredKanjiCount,
    this.contentAsset,
    this.schoolLevel = SchoolLevel.elementary,
    this.schoolYear,
    this.allocationAsset,
  });
  final int grade;
  final String nameKo;
  final PlantStage plantStage;
  final String stageNameKo;
  final String iconKey;

  /// Full course size, never inferred from the sample asset size.
  final int? requiredKanjiCount;
  final String? contentAsset;
  final SchoolLevel schoolLevel;
  final int? schoolYear;
  final String? allocationAsset;
  String get schoolNameKo =>
      schoolLevel == SchoolLevel.middle ? '일본 중학교 한자' : '일본 초등학교 한자';
  factory GradeTheme.fromJson(Map<String, dynamic> json, String path) {
    final f = ContentFields(json, path);
    final stage = f.string('plantStage');
    final matches = PlantStage.values.where((s) => s.name == stage);
    if (matches.isEmpty) throw FormatException('$path has unknown plantStage');
    final level = f.optionalString('schoolLevel') ?? 'elementary';
    final levels = SchoolLevel.values.where((s) => s.name == level);
    if (levels.isEmpty) throw FormatException('$path has unknown schoolLevel');
    final year = f.optionalInteger('schoolYear');
    if (levels.single == SchoolLevel.middle && (year == null || year > 3)) {
      throw FormatException('$path needs a middle-school year from 1 to 3');
    }
    return GradeTheme(
      grade: f.integer('grade'),
      nameKo: f.string('nameKo'),
      plantStage: matches.single,
      stageNameKo: f.string('stageNameKo'),
      iconKey: f.string('iconKey'),
      requiredKanjiCount: f.optionalInteger('requiredKanjiCount'),
      contentAsset: f.optionalString('contentAsset'),
      schoolLevel: levels.single,
      schoolYear: year,
      allocationAsset: f.optionalString('allocationAsset'),
    );
  }
}
