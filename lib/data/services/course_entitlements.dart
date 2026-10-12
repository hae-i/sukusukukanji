import 'package:flutter/foundation.dart';

enum CourseProduct {
  elementary('elementary_unlimited', 5500),
  middle('middle_unlimited', 6600),
  allAdFree('all_courses_ad_free', 12100);

  const CourseProduct(this.id, this.plannedPriceKrw);
  final String id;
  // Planning only. Purchase UI must use the price returned by Google Play.
  final int plannedPriceKrw;
}

/// Feed only server-verified store purchases into this boundary.
/// There is no local purchase switch and no purchase data in cloud backups.
class CourseEntitlements extends ChangeNotifier {
  CourseEntitlements({Set<CourseProduct> verifiedProducts = const {}})
    : _products = Set.unmodifiable(verifiedProducts);
  final Set<CourseProduct> _products;
  bool hasUnlimitedAccess(int grade) =>
      grade >= 1 &&
      grade <= 9 &&
      (_products.contains(CourseProduct.allAdFree) ||
          (grade <= 6 && _products.contains(CourseProduct.elementary)) ||
          (grade >= 7 && _products.contains(CourseProduct.middle)));
  bool removesAds(int grade) => _products.contains(CourseProduct.allAdFree);
}
