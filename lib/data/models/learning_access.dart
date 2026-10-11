import 'content_fields.dart';

/// Local access ledger. Opened lessons stay available, even after interruption.
class LearningAccess {
  LearningAccess({
    this.day = '',
    this.freeUsed = 0,
    this.rewardCredits = 0,
    Set<String> openedLessons = const {},
    Set<String> rewardedLessons = const {},
    Set<String> grantedRewards = const {},
  }) : openedLessons = Set.unmodifiable(openedLessons),
       rewardedLessons = Set.unmodifiable(rewardedLessons),
       grantedRewards = Set.unmodifiable(grantedRewards) {
    if (freeUsed < 0 ||
        freeUsed > 2 ||
        rewardCredits < 0 ||
        !this.openedLessons.containsAll(this.rewardedLessons)) {
      throw ArgumentError('Invalid learning access ledger');
    }
  }
  final String day;
  final int freeUsed;
  final int rewardCredits;
  final Set<String> openedLessons, rewardedLessons, grantedRewards;

  factory LearningAccess.fromJson(Map<String, dynamic> json) {
    final f = ContentFields(json, 'learningAccess');
    if (f.integer('version') != 1) {
      throw const FormatException('Unknown access version');
    }
    final day = json['day'];
    if (day is! String ||
        (day.isNotEmpty &&
            (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) ||
                DateTime.tryParse(day)?.toIso8601String().substring(0, 10) !=
                    day))) {
      throw const FormatException('Invalid access day');
    }
    return LearningAccess(
      day: day,
      freeUsed: f.integer('freeUsed', min: 0),
      rewardCredits: f.integer('rewardCredits', min: 0),
      openedLessons: f.strings('openedLessons').toSet(),
      rewardedLessons: f.strings('rewardedLessons').toSet(),
      grantedRewards: f.strings('grantedRewards').toSet(),
    );
  }
  Map<String, Object> toJson() => {
    'version': 1,
    'day': day,
    'freeUsed': freeUsed,
    'rewardCredits': rewardCredits,
    'openedLessons': openedLessons.toList(),
    'rewardedLessons': rewardedLessons.toList(),
    'grantedRewards': grantedRewards.toList(),
  };
}
