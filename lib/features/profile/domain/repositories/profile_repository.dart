import '../entities/user_profile.dart';
import '../../../../models/ad.dart';

abstract class ProfileRepository {
  Future<UserProfile> getPublicProfile(String userId);
  Future<UserProfile> getPrivateProfile();
  
  Future<List<Ad>> getUserAds(String userId, {int limit = 10, int offset = 0});
  Future<List<Review>> getUserReviews(String userId, {int limit = 10, int offset = 0});
  
  Future<void> followUser(String userId);
  Future<void> unfollowUser(String userId);
  Future<void> reportUser(String userId, String reason);
  Future<void> blockUser(String userId);
  
  Future<void> updateProfile(Map<String, dynamic> updates);
}
