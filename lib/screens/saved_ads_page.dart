import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ad.dart';
import '../models/saved_search.dart';
import '../services/api_service.dart';
import '../widgets/premium_real_estate_card.dart';
import 'ad_details_page.dart';
import 'category_details_page.dart';
import '../providers/saved_search_provider.dart';
import '../providers/app_provider.dart';
import '../models/category.dart';

class SavedAdsPage extends StatefulWidget {
  final int initialIndex;
  const SavedAdsPage({super.key, this.initialIndex = 0});

  @override
  State<SavedAdsPage> createState() => _SavedAdsPageState();
}

class _SavedAdsPageState extends State<SavedAdsPage> {
  final ApiService _apiService = ApiService();
  
  List<Ad> _ads = [];
  bool _isLoadingAds = true;

  @override
  void initState() {
    super.initState();
    _fetchAds();
  }

  Future<void> _fetchAds() async {
    setState(() => _isLoadingAds = true);
    try {
      final results = await _apiService.fetchSavedAds();
      if (mounted) {
        setState(() {
          _ads = results;
          _isLoadingAds = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAds = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text('المفضلة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.black),
          bottom: const TabBar(
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
            tabs: [
              Tab(text: 'الإعلانات المحفوظة'),
              Tab(text: 'عمليات البحث'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAdsTab(),
            _buildSearchesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdsTab() {
    return _isLoadingAds
        ? const Center(child: CircularProgressIndicator())
        : _ads.isEmpty
            ? _buildEmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'لا توجد إعلانات محفوظة',
                subtitle: 'قم بحفظ الإعلانات التي تهمك للرجوع إليها لاحقاً',
              )
            : RefreshIndicator(
                onRefresh: _fetchAds,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _ads.length,
                  itemBuilder: (context, index) {
                    final ad = _ads[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PremiumRealEstateCard(
                        ad: ad,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdDetailsPage(ad: ad),
                            ),
                          ).then((_) => _fetchAds());
                        },
                      ),
                    );
                  },
                ),
              );
  }

  void _openSearch(BuildContext context, SavedSearch search) {
    Category fakeCat = Category(
      id: search.categoryId,
      name: search.categoryName,
      parentId: 0,
      iconName: '',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryDetailsPage(
          category: fakeCat,
          initialSearchQuery: search.searchQuery,
          initialMinPrice: search.minPrice,
          initialMaxPrice: search.maxPrice,
          initialLocations: search.locations.isNotEmpty ? search.locations : null,
          initialTags: search.tags.isNotEmpty ? search.tags : null,
        ),
      ),
    );
  }

  Future<void> _handleTagDeletion(BuildContext context, VoidCallback? onDeleted) async {
    if (onDeleted == null) return;

    final prefs = await SharedPreferences.getInstance();
    final bool dontShowAgain = prefs.getBool('dont_show_delete_tag_popup') ?? false;

    if (dontShowAgain) {
      onDeleted();
      return;
    }

    bool checkboxValue = false;
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('هل أنت متأكد من حذف هذا الفلتر من البحث المحفوظ؟', style: TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: checkboxValue,
                        activeColor: const Color(0xFF1A73E8),
                        onChanged: (val) {
                          setState(() {
                            checkboxValue = val ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text('لا تظهر هذه الرسالة مرة أخرى', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.grey)),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (checkboxValue) {
                      await prefs.setBool('dont_show_delete_tag_popup', true);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    onDeleted();
                  },
                  child: const Text('حذف', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearchChip(BuildContext context, String label, IconData icon, Color color, {VoidCallback? onDeleted}) {
    return GestureDetector(
      onTap: () => _handleTagDeletion(context, onDeleted),
      child: Container(
        padding: EdgeInsets.only(left: onDeleted != null ? 4 : 8, right: 8, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            if (onDeleted != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, size: 10, color: color.withOpacity(0.8)),
              ),
            ]
          ],
        ),
      ),
    );
  }

  String _translateTag(String rawTag) {
    if (!rawTag.contains(':')) return rawTag;
    
    final parts = rawTag.split(':');
    final key = parts[0];
    final value = parts.skip(1).join(':');
    
    final map = {
      'bedrooms': 'غرف النوم',
      'bathrooms': 'الحمامات',
      'furnished': 'الفرش',
      'rent_duration': 'مدة الإيجار',
      'floor': 'الطابق',
      'age': 'عمر البناء',
      'geometric_shape': 'الشكل الهندسي',
      'facade': 'الواجهة',
      'land_type': 'نوع الأرض',
      'ownership_type': 'نوع الملكية',
      'is_mortgaged': 'مرهونة؟',
      'zoning_classification': 'تصنيف التنظيم',
      'topography': 'تضاريس',
      'installment_possible': 'متاح أقساط',
      'available_services': 'الخدمات',
      'main_features': 'مزايا',
      'extra_features': 'مرافق',
      'nearby': 'قريب من',
      'min_area': 'مساحة من',
      'max_area': 'مساحة إلى',
    };
    
    final translatedKey = map[key] ?? key;
    return '$translatedKey: $value';
  }

  Widget _buildSearchesTab() {
    return Consumer<SavedSearchProvider>(
      builder: (context, provider, child) {
        final searches = provider.savedSearches;
        if (searches.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search_off_rounded,
            title: 'لا توجد عمليات بحث محفوظة',
            subtitle: 'قم بحفظ بحثك لتلقي تنبيهات عند إضافة إعلانات جديدة',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: searches.length,
          itemBuilder: (context, index) {
            final search = searches[index];
            final isDaily = search.alertType == 'daily';
            
            String professionalTitle = search.categoryName;
            if (search.searchQuery != null && search.searchQuery!.isNotEmpty) {
              professionalTitle = 'بحث: ${search.searchQuery} في ${search.categoryName}';
            } else if (search.locations.isNotEmpty) {
              professionalTitle = '${search.categoryName} في ${search.locations.first}${search.locations.length > 1 ? ' ومناطق أخرى' : ''}';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              child: InkWell(
                onTap: () => _openSearch(context, search),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TOP ROW: Category & Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                professionalTitle,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87),
                              ),
                              if (search.locations.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        search.locations.join('، '),
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ]
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDaily ? Colors.blue.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDaily ? Icons.calendar_today_rounded : Icons.flash_on_rounded,
                                color: isDaily ? Colors.blue : Colors.orange,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isDaily ? 'يومي' : 'فوري',
                                style: TextStyle(
                                  color: isDaily ? Colors.blue : Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                            if (search.locations.isNotEmpty)
                              ...search.locations.map((loc) => _buildSearchChip(
                                context,
                                loc, 
                                Icons.location_on_rounded, 
                                Colors.teal,
                                onDeleted: () {
                                  final newLocs = List<String>.from(search.locations)..remove(loc);
                                  provider.updateSearch(search.copyWith(locations: newLocs));
                                }
                              )),
                            
                            if (search.minPrice != null || search.maxPrice != null)
                              _buildSearchChip(
                                context,
                                '${search.minPrice?.toInt() ?? 0} - ${search.maxPrice?.toInt() ?? "∞"} دينار',
                                Icons.payments_rounded,
                                Colors.green.shade600,
                                onDeleted: () {
                                  provider.updateSearch(search.copyWith(clearMinPrice: true, clearMaxPrice: true));
                                }
                              ),
                            
                            if (search.tags.isNotEmpty)
                              ...search.tags.map((tag) => _buildSearchChip(
                                context,
                                _translateTag(tag), 
                                Icons.local_offer_rounded, 
                                Colors.purple.shade400,
                                onDeleted: () {
                                  final newTags = List<String>.from(search.tags)..remove(tag);
                                  provider.updateSearch(search.copyWith(tags: newTags));
                                }
                              )),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                provider.deleteSearch(search.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم حذف البحث', style: TextStyle(fontFamily: 'Tajawal'))),
                                );
                              },
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              label: const Text('حذف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A73E8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _openSearch(context, search),
                                child: const Text('عرض الإعلانات المطابقة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}
