import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../../../models/ad.dart';

class MockProfileRepositoryImpl implements ProfileRepository {
  @override
  Future<UserProfile> getPublicProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _mockProfiles[userId] ?? _defaultMockProfile(userId);
  }

  @override
  Future<UserProfile> getPrivateProfile() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _myAccountProfile;
  }

  @override
  Future<List<Ad>> getUserAds(String userId, {int limit = 10, int offset = 0}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [
      Ad(
        id: 1,
        title: 'Toyota Camry 2021 SE',
        description: 'Clean title, minimal scratches.',
        price: 21500,
        location: 'Amman - Abdoun',
        imageUrl: 'https://images.unsplash.com/photo-1590362891991-f776e747a588',
        views: 145,
        categoryId: 2,
      ),
      Ad(
        id: 2,
        title: 'iPhone 13 Pro Max 256GB',
        description: 'Battery health 89%, with box.',
        price: 520,
        location: 'Amman - Sweifieh',
        imageUrl: 'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5',
        views: 320,
        categoryId: 3,
      ),
      Ad(
        id: 3,
        title: 'Luxury Villa with Pool',
        description: '450sqm built up, amazing views.',
        price: 320000,
        location: 'Amman - Dabouq',
        imageUrl: 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9',
        views: 1205,
        categoryId: 1,
      ),
    ];
  }

  @override
  Future<List<Review>> getUserReviews(String userId, {int limit = 10, int offset = 0}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Review(
        id: 'r1',
        reviewerName: 'Omar Khaled',
        reviewerAvatar: 'https://i.pravatar.cc/150?u=omar',
        rating: 5.0,
        text: 'The best seller I have dealt with. Very honest and responsive.',
        date: DateTime.now().subtract(const Duration(days: 2)),
        tags: ['Fast responder', 'Honest condition'],
      ),
      Review(
        id: 'r2',
        reviewerName: 'Sara Ali',
        reviewerAvatar: 'https://i.pravatar.cc/150?u=sara',
        rating: 4.5,
        text: 'Item was exactly as described. Highly recommended.',
        date: DateTime.now().subtract(const Duration(days: 14)),
        tags: ['Item exactly as described', 'Fair pricing'],
      ),
      Review(
        id: 'r3',
        reviewerName: 'Ahmad Y.',
        reviewerAvatar: 'https://i.pravatar.cc/150?u=ahmad',
        rating: 4.0,
        text: 'Good communication, but delivery took a bit long.',
        date: DateTime.now().subtract(const Duration(days: 30)),
        tags: ['Good communication'],
      ),
    ];
  }

  @override
  Future<void> followUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> unfollowUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> reportUser(String userId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> blockUser(String userId) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // --- Mocks ---

  UserProfile _defaultMockProfile(String userId) => UserProfile(
    id: userId,
    name: 'Auto Prestige Motors',
    username: '@autoprestige',
    avatar: 'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=256&h=256',
    coverImage: 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7',
    isEmailVerified: true,
    isPhoneVerified: true,
    isIdentityVerified: true,
    connectedAccounts: ['google', 'facebook', 'apple'],
    memberSince: DateTime(2021, 3, 15),
    location: 'Amman - Mecca Street',
    userType: 'dealer',
    lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
    replyTimeLabel: 'Typically replies within 15 minutes',
    overallRating: 4.8,
    reviewCount: 142,
    responseRate: 98,
    averageResponseTime: '12 mins',
    trustScore: 99,
    followersCount: 12400,
    followingCount: 35,
    activeAdsCount: 45,
    soldAdsCount: 320,
    totalAdsPosted: 400,
    reviewTags: [
      'Trusted dealer',
    reviewTags: ['سريع الاستجابة', 'متعاون', 'دقيق في المواعيد', 'أسعار مناسبة'],
    shopName: 'معرض السيارات الذهبية',
    businessPolicy: 'سياسة الاسترجاع خلال ٣ أيام في حال وجود عيب مصنعي',
    shopLocation: 'شارع الملك فهد، الرياض',
    shopHours: '٨ صباحاً - ١٠ مساءً',
    deliveryAvailable: true,
    bio: 'عاشق للسيارات القديمة، أحب التفاوض بشفافية',
    preferredContact: 'phone',
    languagesSpoken: ['العربية', 'English'],
    dealsCompleted: 15,
    cancellationRate: 2,
    buyerSatisfaction: 98,
  );

  final UserProfile _myAccountProfile = UserProfile(
    id: 'me',
    name: 'Tareq Naser',
    username: '@tareqn',
    avatar: 'https://i.pravatar.cc/256?u=tareq',
    coverImage: 'https://images.unsplash.com/photo-1506744626753-dba7d4154414',
    isEmailVerified: true,
    isPhoneVerified: true,
    isIdentityVerified: false,
    connectedAccounts: ['google'],
    memberSince: DateTime(2023, 1, 10),
    location: 'Amman - Khalda',
    userType: 'private',
    lastSeen: DateTime.now(),
    replyTimeLabel: 'Typically replies within 1 hour',
    overallRating: 4.9,
    reviewCount: 12,
    responseRate: 100,
    averageResponseTime: '45 mins',
    trustScore: 85,
    followersCount: 54,
    followingCount: 120,
    activeAdsCount: 3,
    soldAdsCount: 8,
    totalAdsPosted: 11,
    reviewTags: [
      'Friendly seller',
      'Accurate pricing',
      'Great photos vs reality'
    ],
    bio: 'مهتم بالتقنية والأجهزة المستعملة بحالة ممتازة.',
    preferredContact: 'whatsapp',
    languagesSpoken: ['العربية', 'English'],
    dealsCompleted: 11,
    cancellationRate: 0,
    buyerSatisfaction: 100,
  );

  final Map<String, UserProfile> _mockProfiles = {};
}
