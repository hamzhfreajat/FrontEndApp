// profile_state.dart
import 'package:equatable/equatable.dart';
import '../../domain/entities/user_profile.dart';
import '../../../../../models/ad.dart';

enum ProfileStatus { initial, loading, loaded, error }

class ProfileState extends Equatable {
  final ProfileStatus status;
  final UserProfile? profile;
  final List<Ad> ads;
  final List<Review> reviews;
  final String? errorMessage;
  final bool isFollowing;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.ads = const [],
    this.reviews = const [],
    this.errorMessage,
    this.isFollowing = false,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    UserProfile? profile,
    List<Ad>? ads,
    List<Review>? reviews,
    String? errorMessage,
    bool? isFollowing,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      ads: ads ?? this.ads,
      reviews: reviews ?? this.reviews,
      errorMessage: errorMessage, // Overridable with null
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  @override
  List<Object?> get props => [status, profile, ads, reviews, errorMessage, isFollowing];
}
