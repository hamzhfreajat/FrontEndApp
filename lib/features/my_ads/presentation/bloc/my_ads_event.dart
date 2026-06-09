import 'package:equatable/equatable.dart';

abstract class MyAdsEvent extends Equatable {
  const MyAdsEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboardData extends MyAdsEvent {}

class FetchAds extends MyAdsEvent {
  final String status;
  final String? search;
  final bool isRefresh;

  const FetchAds({this.status = 'All', this.search, this.isRefresh = false});

  @override
  List<Object?> get props => [status, search, isRefresh];
}

class PerformBulkAction extends MyAdsEvent {
  final List<int> adIds;
  final String action;

  const PerformBulkAction(this.adIds, this.action);

  @override
  List<Object> get props => [adIds, action];
}

class PerformSingleAction extends MyAdsEvent {
  final int adId;
  final String action;

  const PerformSingleAction(this.adId, this.action);

  @override
  List<Object> get props => [adId, action];
}

class ToggleSelectionMode extends MyAdsEvent {
  final bool isSelectionMode;

  const ToggleSelectionMode(this.isSelectionMode);

  @override
  List<Object> get props => [isSelectionMode];
}

class ToggleAdSelection extends MyAdsEvent {
  final int adId;

  const ToggleAdSelection(this.adId);

  @override
  List<Object> get props => [adId];
}

class SelectAllAds extends MyAdsEvent {}

class ClearSelection extends MyAdsEvent {}
