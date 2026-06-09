class UserMetrics {
  final int savedItems;
  final int recentlyViewed;
  final int activeAds;

  UserMetrics({
    required this.savedItems,
    required this.recentlyViewed,
    required this.activeAds,
  });

  factory UserMetrics.fromJson(Map<String, dynamic> json) {
    return UserMetrics(
      savedItems: json['saved_items'] ?? 0,
      recentlyViewed: json['recently_viewed'] ?? 0,
      activeAds: json['active_ads'] ?? 0,
    );
  }
}
