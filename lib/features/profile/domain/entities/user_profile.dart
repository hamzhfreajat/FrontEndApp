class UserProfile {
  final String id;
  final String name;
  final String username;
  final String avatar;
  final String coverImage;
  
  // Verification
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isIdentityVerified;
  final List<String> connectedAccounts; // e.g., 'google', 'facebook', 'apple'
  
  // Member Context
  final DateTime memberSince;
  final String location;
  final String userType; // 'private', 'dealer', 'company'
  final DateTime lastSeen;
  final String replyTimeLabel; // e.g., 'Typically replies within 15 minutes'
  
  // Trust & Reputation
  final double overallRating;
  final int reviewCount;
  final int responseRate; // Percentage e.g. 98
  final String averageResponseTime; // e.g., '20 mins'
  final int trustScore; // e.g., 95
  
  // Statistics
  final int followersCount;
  final int followingCount;
  final int activeAdsCount;
  final int soldAdsCount;
  final int totalAdsPosted;
  
  // Qualitative Reviews
  final List<String> reviewTags; 
  
  // Business Specifics
  final String? shopName;
  final String? businessPolicy;
  final String? shopLocation;
  final String? shopHours;
  final bool? deliveryAvailable;
  
  // Contacts
  final String? phoneNumber;
  final String? preferredContact;
  
  // Advanced Profile Extensions
  final String? bio;
  final List<String> languagesSpoken;
  final int dealsCompleted;
  final int cancellationRate;
  final int buyerSatisfaction;

  UserProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.avatar,
    required this.coverImage,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.isIdentityVerified = false,
    this.connectedAccounts = const [],
    required this.memberSince,
    required this.location,
    required this.userType,
    required this.lastSeen,
    required this.replyTimeLabel,
    this.overallRating = 0.0,
    this.reviewCount = 0,
    this.responseRate = 0,
    required this.averageResponseTime,
    this.trustScore = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.activeAdsCount = 0,
    this.soldAdsCount = 0,
    this.totalAdsPosted = 0,
    this.reviewTags = const [],
    this.shopName,
    this.businessPolicy,
    this.shopLocation,
    this.shopHours,
    this.deliveryAvailable,
    this.phoneNumber,
    this.preferredContact,
    this.bio,
    this.languagesSpoken = const [],
    this.dealsCompleted = 0,
    this.cancellationRate = 0,
    this.buyerSatisfaction = 0,
  });

  bool get isBusiness => userType == 'dealer' || userType == 'company';
  
  // Dynamic Calculation for profile completeness based on filled data
  double get completionPercentage {
    int totalCriteria = 8;
    int fulfilled = 0;
    
    if (avatar.isNotEmpty && !avatar.contains('ui-avatars.com')) fulfilled++; // meaning custom avatar
    if (name.isNotEmpty && !name.startsWith('User -')) fulfilled++;
    if (bio != null && bio!.isNotEmpty) fulfilled++;
    if (languagesSpoken.isNotEmpty) fulfilled++;
    if (location.isNotEmpty) fulfilled++;
    if (isPhoneVerified) fulfilled++;
    if (isEmailVerified) fulfilled++;
    if (isIdentityVerified) fulfilled++;
    
    return fulfilled / totalCriteria;
  }

  // Returns human readable list of missing points
  List<String> get missingCompletionPoints {
    List<String> missing = [];
    if (avatar.isEmpty || avatar.contains('ui-avatars.com')) missing.add('إضافة صورة شخصية');
    if (name.isEmpty || name.startsWith('User -')) missing.add('تحديث الاسم الشخصي');
    if (bio == null || bio!.isEmpty) missing.add('كتابة نبذة عنك');
    if (languagesSpoken.isEmpty) missing.add('إضافة اللغات المتحدثة');
    if (location.isEmpty) missing.add('تحديد المنطقة الجغرافية');
    if (!isPhoneVerified) missing.add('توثيق رقم الهاتف');
    if (!isEmailVerified) missing.add('توثيق البريد الإلكتروني');
    if (!isIdentityVerified) missing.add('تأكيد الهوية الوطنية');
    return missing;
  }
  
  bool get isFullyVerified => isEmailVerified && isPhoneVerified && isIdentityVerified;

  bool get isBotOrScraper {
    final uname = username.toLowerCase();
    return uname.contains('scraper') || uname.startsWith('user-');
  }
}

class Review {
  final String id;
  final String reviewerName;
  final String reviewerAvatar;
  final double rating;
  final String text;
  final DateTime date;
  final List<String> tags;

  Review({
    required this.id,
    required this.reviewerName,
    required this.reviewerAvatar,
    required this.rating,
    required this.text,
    required this.date,
    this.tags = const [],
  });
}
