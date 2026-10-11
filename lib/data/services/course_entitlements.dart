import 'package:flutter/foundation.dart';

/// Implement with verified store purchases when billing is added.
/// No preference switch or fake purchase is exposed in the app.
class CourseEntitlements extends ChangeNotifier {
  bool hasUnlimitedAccess(int grade) => false;
  bool removesAds(int grade) => false;
}
