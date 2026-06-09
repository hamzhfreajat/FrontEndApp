import '../entities/my_ad_entities.dart';

abstract class MyAdsRepository {
  Future<DashboardSummary> getDashboardSummary();
  Future<List<MyAd>> getMyAds({String status = 'All', String? search});
  Future<void> performBulkAction(List<int> adIds, String action);
}
