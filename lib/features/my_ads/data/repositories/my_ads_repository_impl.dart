import '../../domain/repositories/my_ads_repository.dart';
import '../../domain/entities/my_ad_entities.dart';
import '../models/my_ad_models.dart';
import '../../../../services/api_service.dart';

class MyAdsRepositoryImpl implements MyAdsRepository {
  final ApiService apiService;

  MyAdsRepositoryImpl(this.apiService);

  @override
  Future<DashboardSummary> getDashboardSummary() async {
    final data = await apiService.fetchMyAdsDashboard();
    return DashboardSummaryModel.fromJson(data);
  }

  @override
  Future<List<MyAd>> getMyAds({String status = 'All', String? search}) async {
    final dataList = await apiService.fetchMyAds(status: status, search: search);
    return dataList.map((data) => MyAdModel.fromJson(data)).toList();
  }

  @override
  Future<void> performBulkAction(List<int> adIds, String action) async {
    return await apiService.performMyAdsBulkAction(adIds, action);
  }
}
