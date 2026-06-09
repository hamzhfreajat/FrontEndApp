import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/my_ads_repository.dart';
import 'my_ads_event.dart';
import 'my_ads_state.dart';

class MyAdsBloc extends Bloc<MyAdsEvent, MyAdsState> {
  final MyAdsRepository repository;

  MyAdsBloc({required this.repository}) : super(const MyAdsState()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<FetchAds>(_onFetchAds);
    on<PerformBulkAction>(_onPerformBulkAction);
    on<PerformSingleAction>(_onPerformSingleAction);
    on<ToggleSelectionMode>(_onToggleSelectionMode);
    on<ToggleAdSelection>(_onToggleAdSelection);
    on<SelectAllAds>(_onSelectAllAds);
    on<ClearSelection>(_onClearSelection);
  }

  Future<void> _onLoadDashboardData(LoadDashboardData event, Emitter<MyAdsState> emit) async {
    try {
      emit(state.copyWith(status: MyAdsStatus.loading));
      final dashboardSummary = await repository.getDashboardSummary();
      final ads = await repository.getMyAds(status: state.activeFilter);
      emit(state.copyWith(
        status: MyAdsStatus.loaded,
        dashboardSummary: dashboardSummary,
        ads: ads,
      ));
    } catch (e) {
      emit(state.copyWith(status: MyAdsStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onFetchAds(FetchAds event, Emitter<MyAdsState> emit) async {
    try {
      emit(state.copyWith(
        status: MyAdsStatus.loading,
        activeFilter: event.status,
      ));
      final ads = await repository.getMyAds(status: event.status, search: event.search);
      emit(state.copyWith(
        status: MyAdsStatus.loaded,
        ads: ads,
        isSelectionMode: false,
        selectedAdIds: {},
      ));
    } catch (e) {
      emit(state.copyWith(status: MyAdsStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onPerformBulkAction(PerformBulkAction event, Emitter<MyAdsState> emit) async {
    try {
      emit(state.copyWith(isActionLoading: true));
      await repository.performBulkAction(event.adIds, event.action);
      emit(state.copyWith(
        isActionLoading: false,
        actionSuccessMessage: 'Successfully performed ${event.action} on ${event.adIds.length} ads',
        isSelectionMode: false,
        selectedAdIds: {},
      ));
      // Refresh the list after action
      add(FetchAds(status: state.activeFilter));
      add(LoadDashboardData());
    } catch (e) {
      emit(state.copyWith(
        isActionLoading: false,
        errorMessage: 'Bulk action failed: ${e.toString()}',
      ));
    }
  }

  Future<void> _onPerformSingleAction(PerformSingleAction event, Emitter<MyAdsState> emit) async {
    try {
      emit(state.copyWith(isActionLoading: true));
      await repository.performBulkAction([event.adId], event.action);
      emit(state.copyWith(
        isActionLoading: false,
        actionSuccessMessage: 'Successfully marked ad as ${event.action}',
      ));
      // Refresh data dynamically
      add(FetchAds(status: state.activeFilter));
      add(LoadDashboardData());
    } catch (e) {
      emit(state.copyWith(
        isActionLoading: false,
        errorMessage: 'Failed to perform action: ${e.toString()}',
      ));
    }
  }

  void _onToggleSelectionMode(ToggleSelectionMode event, Emitter<MyAdsState> emit) {
    emit(state.copyWith(
      isSelectionMode: event.isSelectionMode,
      selectedAdIds: event.isSelectionMode ? state.selectedAdIds : {},
    ));
  }

  void _onToggleAdSelection(ToggleAdSelection event, Emitter<MyAdsState> emit) {
    final currentSelection = Set<int>.from(state.selectedAdIds);
    if (currentSelection.contains(event.adId)) {
      currentSelection.remove(event.adId);
    } else {
      currentSelection.add(event.adId);
    }
    
    // Auto-exit selection if empty
    if (currentSelection.isEmpty && state.isSelectionMode) {
      emit(state.copyWith(selectedAdIds: {}, isSelectionMode: false));
    } else {
      emit(state.copyWith(selectedAdIds: currentSelection, isSelectionMode: true));
    }
  }

  void _onSelectAllAds(SelectAllAds event, Emitter<MyAdsState> emit) {
    final allIds = state.ads.map((ad) => ad.baseAd.id).toSet();
    emit(state.copyWith(selectedAdIds: allIds, isSelectionMode: true));
  }

  void _onClearSelection(ClearSelection event, Emitter<MyAdsState> emit) {
    emit(state.copyWith(selectedAdIds: {}, isSelectionMode: false));
  }
}
