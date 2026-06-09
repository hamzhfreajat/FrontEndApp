import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ?? AppLocalizations(const Locale('ar'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
        'en': {
      'most_viewed': 'Most Viewed',
      'commercial_spaces': 'Leading\\nCommercial Spaces',
      'now': 'Now',
      'for_sale': 'For Sale',
      'new': 'New',
      'my_ads': 'My Ads',
      'studios_rent': 'Studios for Rent',
      'getting_engagement': 'Getting Engagement',
      'categories': 'Categories',
      'lands': 'Lands',
      'houses_sale': 'Independent Houses for Sale',
      'farms': 'Farms',
      'add_ad_free': 'Add Ad for Free',
      'apartments_rent': 'Apartments for Rent',
      'no_ads': 'No ads currently available',
      'view_all': 'View All',
      'modern_apartments': 'Modern Apartments\\nfor Rent',
      'for_rent': 'For Rent',
      'lands_farms': 'Lands, Farms & Chalets',
      'saves': 'Saves',
      'live_now': 'Live Now',
      'user': 'User',
      'recently_discovered': 'Recently Discovered',
      'welcome_back': 'Welcome back 👋',
      'personal_account': 'Personal Account',
      'real_estate_rent': 'Real Estate for Rent',
      'luxury_real_estate': 'Luxury & Premium\\nReal Estate',
      'shared_housing': 'Shared Housing',
      'home': 'Home',
      'active_ads': 'Active Ads',
      'browse_now': 'Browse Now',
      'studios_sale': 'Studios for Sale',
      'nearest_to_you': 'Nearest to You',
      'browse_best': 'Browse Best Real Estate',
      'farms_chalets': 'Farms & Chalets',
      'chalets_resorts': 'Chalets / Resorts',
      'country_houses': 'Country Houses',
      'apartments_sale': 'Apartments for Sale',
      'employee_housing': 'Employee Housing',
      'add_ad_now': 'Add Your Ad Now',
      'reach_thousands': 'Reach thousands of buyers in simple steps',
      'private_room': 'Private Room for Rent',
      'near_you': '📍 Near You',
      'rent': 'Rent',
      'buy': 'Buy',
      'write': 'Write',
      'student_housing_male': 'Student Housing (Male)',
      'residential': 'Residential',
      'add_ad': 'Add Ad',
      'last_24_hours': 'Last 24 Hours',
      'all_offers': 'All Offers',
      'chalets_summer': 'Chalets & Summer Houses',
      'my_account': 'My Account',
      'no_updates': 'No current updates',
      'commercial': 'Commercial',
      'recently_viewed': 'Recently Viewed',
      'explore': 'Explore',
      'add_story': 'Add Your Story',
      'featured': 'Featured',
      'student_housing_female': 'Student Housing (Female)',
      'villas_palaces': 'Villas & Palaces',
      'view_details': 'View Details',
      'houses_sale': 'Houses for Sale',
      'independent_houses': 'Independent Houses',
      'within_budget': '💸 Within your budget (≤ 800 JOD)',
      'shoot': 'Shoot',
      'real_estate_sale': 'Real Estate for Sale',
      'seen_recently': '🕒 Seen Recently',
      'quick_look': 'Here is a quick look at your interests',
      'failed_to_load': 'Failed to load data',
      'female_employee_housing': 'Female Employee Housing',
      'publish': 'Publish',
      'farm_rent': 'Farm for Rent',
      'show_more': 'Show More',
      'sooqcom': 'Sooqcom',
      'independent_houses_rent': 'Independent Houses for Rent',
    },
        'ar': {
      'most_viewed': 'الأكثر مشاهدة',
      'commercial_spaces': 'مساحات تجارية\\nرائدة',
      'now': 'الآن',
      'for_sale': 'للبيع',
      'new': 'جديد',
      'my_ads': 'إعلاناتي',
      'studios_rent': 'ستوديوهات للإيجار',
      'getting_engagement': 'تحصل على تفاعل',
      'categories': 'الأقسام',
      'lands': 'أراضي',
      'houses_sale': 'بيوت مستقلة للبيع',
      'farms': 'مزارع',
      'add_ad_free': 'أضف إعلان مجاناً',
      'apartments_rent': 'شقق للإيجار',
      'no_ads': 'لا توجد إعلانات حالياً',
      'view_all': 'عرض الكل',
      'modern_apartments': 'شقق عصرية\\nللإيجار',
      'for_rent': 'للايجار',
      'lands_farms': 'أراضي ومزارع وشاليهات',
      'saves': 'عمليات الحفظ',
      'live_now': 'مباشر الآن',
      'user': 'مستخدم',
      'recently_discovered': 'مكتشف حديثاً',
      'welcome_back': 'مرحباً بك مجدداً 👋',
      'personal_account': 'الحساب الشخصي',
      'real_estate_rent': 'عقارات للإيجار',
      'luxury_real_estate': 'عقارات فاخرة\\nومميزة',
      'shared_housing': 'سكن مشترك',
      'home': 'الرئيسية',
      'active_ads': 'إعلاناتي النشطة',
      'browse_now': 'تصفح الآن',
      'studios_sale': 'ستوديوهات للبيع',
      'nearest_to_you': 'الأقرب اليك',
      'browse_best': 'تصفح أفضل العقارات',
      'farms_chalets': 'مزارع وشاليهات',
      'chalets_resorts': 'شاليهات / منتجعات',
      'country_houses': 'بيوت ريفية',
      'apartments_sale': 'شقق للبيع',
      'employee_housing': 'سكن موظفين',
      'add_ad_now': 'أضف إعلانك الآن',
      'reach_thousands': 'اوصل لآلاف المشترين بخطوات بسيطة',
      'private_room': 'غرفة برايف للإيجار',
      'near_you': '📍 بالقرب منك',
      'rent': 'عقارات للايجار',
      'buy': 'عقارات للبيع',
      'write': 'اكتب',
      'student_housing_male': 'سكن طلاب (ذكور)',
      'residential': 'سكني',
      'add_ad': 'أضف إعلانك',
      'last_24_hours': 'آخر 24 ساعة',
      'all_offers': 'كل العروض',
      'chalets_summer': 'شاليهات ومصايف',
      'my_account': 'حسابي',
      'no_updates': 'لا توجد تحديثات حالية',
      'commercial': 'تجاري',
      'recently_viewed': 'شوهد مؤخراً',
      'explore': 'استكشف',
      'add_story': 'أضف قصتك',
      'featured': 'مميز',
      'student_housing_female': 'سكن طالبات (إناث)',
      'villas_palaces': 'فلل وقصور',
      'view_details': 'عرض التفاصيل',
      'houses_sale': 'بيوت للبيع',
      'independent_houses': 'بيوت مستقلة',
      'within_budget': '💸 ضمن ميزانيتك (≤ 800 دينار)',
      'shoot': 'صوّر',
      'real_estate_sale': 'عقارات للبيع',
      'seen_recently': '🕒 شاهدتها مؤخراً',
      'quick_look': 'إليك نظرة سريعة على اهتماماتك',
      'failed_to_load': 'تعذر تحميل البيانات',
      'female_employee_housing': 'سكن موظفات',
      'publish': 'انشر',
      'farm_rent': 'مزرعة للإيجار',
      'show_more': 'عرض المزيد',
      'sooqcom': 'سوقكم',
      'independent_houses_rent': 'بيوت مستقلة للإيجار',
      'settings': 'الإعدادات',
      'privacy_security': 'الخصوصية والأمان',
      'privacy_subtitle': 'إدارة الحساب، كلمات المرور',
      'banned_users': 'المستخدمون المحظورون',
      'banned_subtitle': 'إدارة قائمة الحظر',
      'help_support': 'المساعدة والدعم',
      'help_subtitle': 'الأسئلة الشائعة، تواصل معنا',
      'logout': 'تسجيل الخروج',
    },
  };

  String tr(String key) {
    final languageCode = 'ar';
    if (_localizedValues.containsKey(languageCode) && _localizedValues[languageCode]!.containsKey(key)) {
      return _localizedValues[languageCode]![key]!;
    }
    
    // Fallback to arabic or just return the key if not found
    if (_localizedValues['ar']!.containsKey(key)) {
      return _localizedValues['ar']![key]!;
    }
    
    return key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// Extension to make translating easier: context.tr('key')
extension AppLocalizationsExtension on BuildContext {
  String tr(String key) {
    return AppLocalizations.of(this).tr(key);
  }
}
