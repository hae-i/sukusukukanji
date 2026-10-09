import 'content_fields.dart';

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
  });
  final int grade;
  final String nameKo;
  final PlantStage plantStage;
  final String stageNameKo;
  final String iconKey;

  /// Full course size, never inferred from the sample asset size.
  final int? requiredKanjiCount;
  final String? contentAsset;
  factory GradeTheme.fromJson(Map<String, dynamic> json, String path) {
    final f = ContentFields(json, path);
    final stage = f.string('plantStage');
    final matches = PlantStage.values.where((s) => s.name == stage);
    if (matches.isEmpty) throw FormatException('$path has unknown plantStage');
    return GradeTheme(
      grade: f.integer('grade'),
      nameKo: f.string('nameKo'),
      plantStage: matches.single,
      stageNameKo: f.string('stageNameKo'),
      iconKey: f.string('iconKey'),
      requiredKanjiCount: f.optionalInteger('requiredKanjiCount'),
      contentAsset: f.optionalString('contentAsset'),
    );
  }
}
