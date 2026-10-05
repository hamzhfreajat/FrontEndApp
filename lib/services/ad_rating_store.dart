import 'package:flutter/foundation.dart';

class AdRating {
  final double? average; // null while the ad has no reviews
  final int count;
  const AdRating(this.average, this.count);
}

/// Latest known rating per ad for this app session.
///
/// Ad lists are cached for a short time on the server, so right after a review
/// is added the list still carries the old rating. Whatever the reviews API
/// returns is recorded here and listing cards prefer it over the list's value,
/// which makes a new review show up everywhere immediately.
class AdRatingStore {
  static final ValueNotifier<Map<int, AdRating>> ratings = ValueNotifier(const {});

  static void set(int adId, double? average, int count) {
    ratings.value = {...ratings.value, adId: AdRating(count > 0 ? average : null, count)};
  }
}
