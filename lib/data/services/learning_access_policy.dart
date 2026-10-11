import '../models/learning_access.dart';

class LearningAccessPolicy {
  const LearningAccessPolicy();
  static const dailyFreeLessons = 2;
  static String lessonKey(int grade, int lesson) => '$grade:$lesson';
  String dayKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  // A backward clock change must not grant another free allowance.
  String _effectiveDay(LearningAccess state, DateTime now) {
    final day = dayKey(now);
    return day.compareTo(state.day) > 0 ? day : state.day;
  }

  int freeRemaining(LearningAccess state, DateTime now) =>
      _effectiveDay(state, now) != state.day
      ? dailyFreeLessons
      : dailyFreeLessons - state.freeUsed;

  bool canOpen(LearningAccess state, String lesson, DateTime now) =>
      state.openedLessons.contains(lesson) ||
      freeRemaining(state, now) > 0 ||
      state.rewardCredits > 0;

  LearningAccess open(LearningAccess state, String lesson, DateTime now) {
    if (state.openedLessons.contains(lesson)) return state;
    if (!canOpen(state, lesson, now)) {
      throw StateError('A rewarded lesson is required');
    }
    final useFree = freeRemaining(state, now) > 0;
    final day = _effectiveDay(state, now);
    return LearningAccess(
      day: day,
      freeUsed: (day == state.day ? state.freeUsed : 0) + (useFree ? 1 : 0),
      rewardCredits: state.rewardCredits - (useFree ? 0 : 1),
      openedLessons: {...state.openedLessons, lesson},
      rewardedLessons: {...state.rewardedLessons, if (!useFree) lesson},
      grantedRewards: state.grantedRewards,
    );
  }

  LearningAccess grant(LearningAccess state, String receipt) {
    if (receipt.isEmpty) throw ArgumentError('Missing reward receipt');
    if (state.grantedRewards.contains(receipt)) return state;
    return LearningAccess(
      day: state.day,
      freeUsed: state.freeUsed,
      rewardCredits: state.rewardCredits + 1,
      openedLessons: state.openedLessons,
      rewardedLessons: state.rewardedLessons,
      grantedRewards: {...state.grantedRewards, receipt},
    );
  }
}
