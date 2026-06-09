import '../../../../models/ad.dart';

class MyAd {
  final Ad baseAd;
  final String status;
  final int performanceScore;
  final String? suggestedAction;
  final int chatsCount;
  final int favoritesCount;
  final bool isBoosted;
  final DateTime? expiresAt;

  MyAd({
    required this.baseAd,
    required this.status,
    required this.performanceScore,
    this.suggestedAction,
    this.chatsCount = 0,
    this.favoritesCount = 0,
    this.isBoosted = false,
    this.expiresAt,
  });
}

class DashboardSummary {
  final int totalAds;
  final int activeAds;
  final int expiredAds;
  final int pendingAds;
  final int soldAds;
  final int pausedAds;
  final int boostedAds;
  final int totalViews;
  final int totalChats;
  final int totalFavorites;

  DashboardSummary({
    required this.totalAds,
    required this.activeAds,
    required this.expiredAds,
    required this.pendingAds,
    required this.soldAds,
    required this.pausedAds,
    required this.boostedAds,
    required this.totalViews,
    required this.totalChats,
    required this.totalFavorites,
  });
}
