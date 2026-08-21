import 'package:flutter_bloc/flutter_bloc.dart';
import 'profile_event.dart';
import 'profile_state.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/entities/user_profile.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository repository;
  final String? targetUserId; // if null, load private profile

  ProfileBloc({required this.repository, this.targetUserId}) : super(const ProfileState()) {
    on<LoadProfile>(_onLoadProfile);
    on<ToggleFollow>(_onToggleFollow);
    on<UpdateProfile>(_onUpdateProfile);
  }

  Future<void> _onLoadProfile(LoadProfile event, Emitter<ProfileState> emit) async {
    try {
      emit(const ProfileState(status: ProfileStatus.loading));
      
      final profile = targetUserId == null 
          ? await repository.getPrivateProfile()
          : await repository.getPublicProfile(targetUserId!);
          
      final ads = await repository.getUserAds(profile.id);
      final reviews = await repository.getUserReviews(profile.id);

      emit(state.copyWith(
        status: ProfileStatus.loaded,
        profile: profile,
        ads: ads,
        reviews: reviews,
        isFollowing: false, // Initially assume false, or fetch from repo
      ));
    } catch (e) {
      emit(state.copyWith(status: ProfileStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onToggleFollow(ToggleFollow event, Emitter<ProfileState> emit) async {
    if (state.profile == null) return;
    try {
      final isNowFollowing = !state.isFollowing;
      emit(state.copyWith(isFollowing: isNowFollowing));
      
      if (isNowFollowing) {
        await repository.followUser(state.profile!.id);
      } else {
        await repository.unfollowUser(state.profile!.id);
      }
    } catch (e) {
      // Revert upon failure
      emit(state.copyWith(isFollowing: !state.isFollowing, errorMessage: 'Failed to toggle follow status.'));
    }
  }

  Future<void> _onUpdateProfile(UpdateProfile event, Emitter<ProfileState> emit) async {
    if (state.profile == null) return;
    try {
      await repository.updateProfile(event.updates);
      // Create new profile object locally to update UI immediately
      final updatedProfile = UserProfile(
        id: state.profile!.id,
        name: event.updates.containsKey('username') ? event.updates['username'] : state.profile!.name,
        username: state.profile!.username,
        avatar: event.updates.containsKey('avatar_url') ? event.updates['avatar_url'] : state.profile!.avatar,
        coverImage: event.updates.containsKey('cover_image_url') ? event.updates['cover_image_url'] : state.profile!.coverImage,
        isEmailVerified: state.profile!.isEmailVerified,
        isPhoneVerified: state.profile!.isPhoneVerified,
        isIdentityVerified: state.profile!.isIdentityVerified,
        connectedAccounts: state.profile!.connectedAccounts,
        memberSince: state.profile!.memberSince,
        location: state.profile!.location,
        userType: event.updates.containsKey('user_type') ? event.updates['user_type'] : state.profile!.userType,
        lastSeen: state.profile!.lastSeen,
        replyTimeLabel: state.profile!.replyTimeLabel,
        overallRating: state.profile!.overallRating,
        reviewCount: state.profile!.reviewCount,
        responseRate: state.profile!.responseRate,
        averageResponseTime: state.profile!.averageResponseTime,
        trustScore: state.profile!.trustScore,
        followersCount: state.profile!.followersCount,
        followingCount: state.profile!.followingCount,
        activeAdsCount: state.profile!.activeAdsCount,
        soldAdsCount: state.profile!.soldAdsCount,
        totalAdsPosted: state.profile!.totalAdsPosted,
        reviewTags: state.profile!.reviewTags,
        shopName: state.profile!.shopName,
        businessPolicy: state.profile!.businessPolicy,
        shopLocation: state.profile!.shopLocation,
        shopHours: state.profile!.shopHours,
        deliveryAvailable: state.profile!.deliveryAvailable,
        phoneNumber: state.profile!.phoneNumber,
        preferredContact: event.updates.containsKey('preferred_contact') ? event.updates['preferred_contact'] : state.profile!.preferredContact,
        bio: event.updates.containsKey('bio') ? event.updates['bio'] : state.profile!.bio,
        languagesSpoken: event.updates.containsKey('languages_spoken') ? (event.updates['languages_spoken'] as List).cast<String>() : state.profile!.languagesSpoken,
        dealsCompleted: state.profile!.dealsCompleted,
        cancellationRate: state.profile!.cancellationRate,
        buyerSatisfaction: state.profile!.buyerSatisfaction,
        walletBalance: state.profile!.walletBalance,
      );
      emit(state.copyWith(profile: updatedProfile));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'فشل التحديث: $e'));
    }
  }
}
