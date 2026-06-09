import sys, re, os

translations = {
  "الأكثر مشاهدة": ("most_viewed", "Most Viewed"),
  "مساحات تجارية\\nرائدة": ("commercial_spaces", "Leading\\nCommercial Spaces"),
  "الآن": ("now", "Now"),
  "للبيع": ("for_sale", "For Sale"),
  "جديد": ("new", "New"),
  "إعلاناتي": ("my_ads", "My Ads"),
  "ستوديوهات للإيجار": ("studios_rent", "Studios for Rent"),
  "تحصل على تفاعل": ("getting_engagement", "Getting Engagement"),
  "الأقسام": ("categories", "Categories"),
  "أراضي": ("lands", "Lands"),
  "بيوت مستقلة للبيع": ("houses_sale", "Independent Houses for Sale"),
  "مزارع": ("farms", "Farms"),
  "أضف إعلان مجاناً": ("add_ad_free", "Add Ad for Free"),
  "شقق للإيجار": ("apartments_rent", "Apartments for Rent"),
  "لا توجد إعلانات حالياً": ("no_ads", "No ads currently available"),
  "عرض الكل": ("view_all", "View All"),
  "شقق عصرية\\nللإيجار": ("modern_apartments", "Modern Apartments\\nfor Rent"),
  "للايجار": ("for_rent", "For Rent"),
  "أراضي ومزارع وشاليهات": ("lands_farms", "Lands, Farms & Chalets"),
  "عمليات الحفظ": ("saves", "Saves"),
  "مباشر الآن": ("live_now", "Live Now"),
  "مستخدم": ("user", "User"),
  "مكتشف حديثاً": ("recently_discovered", "Recently Discovered"),
  "مرحباً بك مجدداً 👋": ("welcome_back", "Welcome back 👋"),
  "الحساب الشخصي": ("personal_account", "Personal Account"),
  "عقارات للإيجار": ("real_estate_rent", "Real Estate for Rent"),
  "عقارات فاخرة\\nومميزة": ("luxury_real_estate", "Luxury & Premium\\nReal Estate"),
  "سكن مشترك": ("shared_housing", "Shared Housing"),
  "الرئيسية": ("home", "Home"),
  "إعلاناتي النشطة": ("active_ads", "Active Ads"),
  "تصفح الآن": ("browse_now", "Browse Now"),
  "ستوديوهات للبيع": ("studios_sale", "Studios for Sale"),
  "الأقرب اليك": ("nearest_to_you", "Nearest to You"),
  "تصفح أفضل العقارات": ("browse_best", "Browse Best Real Estate"),
  "مزارع وشاليهات": ("farms_chalets", "Farms & Chalets"),
  "شاليهات / منتجعات": ("chalets_resorts", "Chalets / Resorts"),
  "بيوت ريفية": ("country_houses", "Country Houses"),
  "شقق للبيع": ("apartments_sale", "Apartments for Sale"),
  "سكن موظفين": ("employee_housing", "Employee Housing"),
  "أضف إعلانك الآن": ("add_ad_now", "Add Your Ad Now"),
  "اوصل لآلاف المشترين بخطوات بسيطة": ("reach_thousands", "Reach thousands of buyers in simple steps"),
  "غرفة برايف للإيجار": ("private_room", "Private Room for Rent"),
  "📍 بالقرب منك": ("near_you", "📍 Near You"),
  "إيجار": ("rent", "Rent"),
  "شراء": ("buy", "Buy"),
  "اكتب": ("write", "Write"),
  "سكن طلاب (ذكور)": ("student_housing_male", "Student Housing (Male)"),
  "سكني": ("residential", "Residential"),
  "أضف إعلانك": ("add_ad", "Add Ad"),
  "آخر 24 ساعة": ("last_24_hours", "Last 24 Hours"),
  "كل العروض": ("all_offers", "All Offers"),
  "شاليهات ومصايف": ("chalets_summer", "Chalets & Summer Houses"),
  "حسابي": ("my_account", "My Account"),
  "لا توجد تحديثات حالية": ("no_updates", "No current updates"),
  "تجاري": ("commercial", "Commercial"),
  "شوهد مؤخراً": ("recently_viewed", "Recently Viewed"),
  "استكشف": ("explore", "Explore"),
  "أضف قصتك": ("add_story", "Add Your Story"),
  "مميز": ("featured", "Featured"),
  "سكن طالبات (إناث)": ("student_housing_female", "Student Housing (Female)"),
  "فلل وقصور": ("villas_palaces", "Villas & Palaces"),
  "عرض التفاصيل": ("view_details", "View Details"),
  "بيوت للبيع": ("houses_sale", "Houses for Sale"),
  "بيوت مستقلة": ("independent_houses", "Independent Houses"),
  "💸 ضمن ميزانيتك (≤ 800 دينار)": ("within_budget", "💸 Within your budget (≤ 800 JOD)"),
  "صوّر": ("shoot", "Shoot"),
  "عقارات للبيع": ("real_estate_sale", "Real Estate for Sale"),
  "🕒 شاهدتها مؤخراً": ("seen_recently", "🕒 Seen Recently"),
  "إليك نظرة سريعة على اهتماماتك": ("quick_look", "Here is a quick look at your interests"),
  "تعذر تحميل البيانات": ("failed_to_load", "Failed to load data"),
  "سكن موظفات": ("female_employee_housing", "Female Employee Housing"),
  "انشر": ("publish", "Publish"),
  "مزرعة للإيجار": ("farm_rent", "Farm for Rent"),
  "عرض المزيد": ("show_more", "Show More"),
  "سوقكم": ("sooqcom", "Sooqcom"),
  "بيوت مستقلة للإيجار": ("independent_houses_rent", "Independent Houses for Rent")
}

def escape(s):
    return s.replace("'", "\\'")

# 1. Generate app_localizations.dart
loc_file = r'd:\open\classifieds-app\frontend\lib\l10n\app_localizations.dart'
with open(loc_file, 'r', encoding='utf-8') as f:
    content = f.read()

en_dict = "    'en': {\n"
ar_dict = "    'ar': {\n"
for ar_str, (key, en_str) in translations.items():
    en_dict += f"      '{key}': '{escape(en_str)}',\n"
    ar_dict += f"      '{key}': '{escape(ar_str)}',\n"
en_dict += "    },"
ar_dict += "    },"

# Replace the maps in app_localizations.dart using regex
content = re.sub(r"'en': \{[^}]+\},", en_dict, content)
content = re.sub(r"'ar': \{[^}]+\},", ar_dict, content)

with open(loc_file, 'w', encoding='utf-8') as f:
    f.write(content)

# 2. Inject context.tr() into dart files
files_to_process = [
    r'd:\open\classifieds-app\frontend\lib\screens\home_page.dart',
    r'd:\open\classifieds-app\frontend\lib\screens\root_screen.dart'
]

for fp in files_to_process:
    with open(fp, 'r', encoding='utf-8') as f:
        code = f.read()
        
    # ensure import is present
    if "import '../l10n/app_localizations.dart';" not in code and "import 'package:classifieds_frontend/l10n/app_localizations.dart';" not in code:
        code = "import '../l10n/app_localizations.dart';\n" + code
        
    for ar_str, (key, _) in translations.items():
        # Replace occurrences of exactly 'ar_str' or "ar_str"
        # We use regex to match exactly
        pattern = r"(['\"])" + re.escape(ar_str) + r"\1"
        replacement = r"context.tr('" + key + r"')"
        code = re.sub(pattern, replacement, code)
        
    with open(fp, 'w', encoding='utf-8') as f:
        f.write(code)

print("Translation injection complete!")
