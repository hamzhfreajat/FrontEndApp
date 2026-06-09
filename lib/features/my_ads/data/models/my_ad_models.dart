import '../../domain/entities/my_ad_entities.dart';
import '../../../../models/ad.dart';

class MyAdModel extends MyAd {
  MyAdModel({
    required Ad baseAd,
    required String status,
    required int performanceScore,
    String? suggestedAction,
    int chatsCount = 0,
    int favoritesCount = 0,
    bool isBoosted = false,
    DateTime? expiresAt,
  }) : super(
          baseAd: baseAd,
          status: status,
          performanceScore: performanceScore,
          suggestedAction: suggestedAction,
          chatsCount: chatsCount,
          favoritesCount: favoritesCount,
          isBoosted: isBoosted,
          expiresAt: expiresAt,
        );

  factory MyAdModel.fromJson(Map<String, dynamic> json) {
    return MyAdModel(
      baseAd: Ad.fromJson(json), // Reuses the existing robust Ad parsing
      status: json['status'] ?? 'Active',
      performanceScore: json['performance_score'] ?? 0,
      suggestedAction: (json['suggested_action'] != null && json['suggested_action'].toString().toLowerCase().contains('boost')) 
          ? null 
          : json['suggested_action'],
      chatsCount: json['chats_count'] ?? 0,
      favoritesCount: json['favorites_count'] ?? 0,
      isBoosted: json['is_boosted'] ?? false,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at']) : null,
    );
  }
}

class DashboardSummaryModel extends DashboardSummary {
  DashboardSummaryModel({
    required int totalAds,
    required int activeAds,
    required int expiredAds,
    required int pendingAds,
    required int soldAds,
    required int pausedAds,
    required int boostedAds,
    required int totalViews,
    required int totalChats,
    required int totalFavorites,
  }) : super(
          totalAds: totalAds,
          activeAds: activeAds,
          expiredAds: expiredAds,
          pendingAds: pendingAds,
          soldAds: soldAds,
          pausedAds: pausedAds,
          boostedAds: boostedAds,
          totalViews: totalViews,
          totalChats: totalChats,
          totalFavorites: totalFavorites,
        );

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryModel(
      totalAds: json['totalAds'] ?? 0,
      activeAds: json['activeAds'] ?? 0,
      expiredAds: json['expiredAds'] ?? 0,
      pendingAds: json['pendingAds'] ?? 0,
      soldAds: json['soldAds'] ?? 0,
      pausedAds: json['pausedAds'] ?? 0,
      boostedAds: json['boostedAds'] ?? 0,
      totalViews: json['totalViews'] ?? 0,
      totalChats: json['totalChats'] ?? 0,
      totalFavorites: json['totalFavorites'] ?? 0,
    );
  }
}
