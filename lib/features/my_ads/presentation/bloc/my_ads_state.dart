import 'package:equatable/equatable.dart';
import '../../domain/entities/my_ad_entities.dart';

enum MyAdsStatus { initial, loading, loaded, error }

class MyAdsState extends Equatable {
  final MyAdsStatus status;
  final DashboardSummary? dashboardSummary;
  final List<MyAd> ads;
  final String? errorMessage;
  final String activeFilter;
  final bool isActionLoading;
  final String? actionSuccessMessage;

  final bool isSelectionMode;
  final Set<int> selectedAdIds;

  const MyAdsState({
    this.status = MyAdsStatus.initial,
    this.dashboardSummary,
    this.ads = const [],
    this.errorMessage,
    this.activeFilter = 'All',
    this.isActionLoading = false,
    this.actionSuccessMessage,
    this.isSelectionMode = false,
    this.selectedAdIds = const {},
  });

  MyAdsState copyWith({
    MyAdsStatus? status,
    DashboardSummary? dashboardSummary,
    List<MyAd>? ads,
    String? errorMessage,
    String? activeFilter,
    bool? isActionLoading,
    String? actionSuccessMessage,
    bool? isSelectionMode,
    Set<int>? selectedAdIds,
  }) {
    return MyAdsState(
      status: status ?? this.status,
      dashboardSummary: dashboardSummary ?? this.dashboardSummary,
      ads: ads ?? this.ads,
      errorMessage: errorMessage, // Note: Not using ?? to allow nullification on retry
      activeFilter: activeFilter ?? this.activeFilter,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      actionSuccessMessage: actionSuccessMessage,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedAdIds: selectedAdIds ?? this.selectedAdIds,
    );
  }

  @override
  List<Object?> get props => [
        status,
        dashboardSummary,
        ads,
        errorMessage,
        activeFilter,
      isActionLoading,
      actionSuccessMessage,
      isSelectionMode,
      selectedAdIds,
    ];
}
