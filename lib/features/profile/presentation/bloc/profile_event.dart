// profile_event.dart
import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadProfile extends ProfileEvent {}

class ToggleFollow extends ProfileEvent {}

class UpdateProfile extends ProfileEvent {
  final Map<String, dynamic> updates;
  const UpdateProfile(this.updates);

  @override
  List<Object?> get props => [updates];
}

class ReportProfile extends ProfileEvent {
  final String reason;
  const ReportProfile(this.reason);

  @override
  List<Object?> get props => [reason];
}
