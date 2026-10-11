import 'package:flutter/foundation.dart';

enum RewardedOutcome { earned, dismissed, unavailable }

/// SDK-independent boundary, also used by widget tests and unsupported platforms.
class AdService extends ChangeNotifier {
  bool get enabled => false;
  bool get canRequestAds => false;
  bool get privacyOptionsRequired => false;
  Future<void> initialize() async {}
  Future<RewardedOutcome> showRewarded(
    Future<void> Function(String) onEarned,
  ) async => RewardedOutcome.unavailable;
  Future<bool> showLessonInterstitial() async => false;
  Future<void> showPrivacyOptions() async {}
}
