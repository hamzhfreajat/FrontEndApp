import 'package:flutter/material.dart';
import '../services/analytics_engine.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'add_ad_city.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/emoji_category_icon.dart';

class AddAdSubcategoriesPage extends StatefulWidget {
  final List<Category> allCategories;
  final Category parentCategory;
  final String transactionType;
  final List<int>? categoryPath;
  final List<XFile>? images;
  final XFile? reelVideo;

  const AddAdSubcategoriesPage({
    super.key,
    required this.allCategories,
    required this.parentCategory,
    required this.transactionType,
    this.categoryPath,
    this.images,
    this.reelVideo,
  });

  @override
  State<AddAdSubcategoriesPage> createState() => _AddAdSubcategoriesPageState();
}

class _AddAdSubcategoriesPageState extends State<AddAdSubcategoriesPage> {
  late List<int> _currentCategoryPath;
  bool _isLoadingSubcategories = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: 'add_ad_subcategories');
    _currentCategoryPath = widget.categoryPath ?? [];
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingSubcategories = true;
      _hasError = false;
    });

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    bool success = await appProvider.loadSubCategories(widget.parentCategory.id);
    
    if (!mounted) return;
    
    if (!success) {
      if (mounted) {
        setState(() {
          _isLoadingSubcategories = false;
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل في تحميل الأقسام، يرجى المحاولة مرة أخرى.')),
        );
      }
      return;
    }
    
    final currentCategories = appProvider.categories ?? widget.allCategories;
    final hasChildren = currentCategories.any((c) => c.parentId == widget.parentCategory.id);
    
    if (!hasChildren) {
      AnalyticsEngine().logButtonTapped(buttonName: 'select_category', location: 'add_ad_subcategories');
                              Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AddAdCityPage(
            selectedLeafCategory: widget.parentCategory,
            transactionType: widget.transactionType,
            images: widget.images,
            reelVideo: widget.reelVideo,
          ),
        ),
      );
    } else {
      if (mounted) {
        setState(() {
          _isLoadingSubcategories = false;
        });
      }
    }
  }
  // Removed _getIconData as we use EmojiCategoryIcon


  Color _getColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFF0075FF);
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF0075FF);
    }
  }

  Widget _buildCompactCategoryItem(
      String title, String? iconName, Color color, String subtitle,
      {bool isSelected = false, bool hasChildren = false, String? tag, String? imageUrl}) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.08) : color.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? color : color.withOpacity(0.15), width: isSelected ? 2.0 : 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: imageUrl != null
              ? ClipOval(
                  child: ApiService.buildIconImage(
                    imageUrl,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    fallback: EmojiCategoryIcon(iconName: iconName, color: color, size: 24),
                  ),
                )
              : EmojiCategoryIcon(iconName: iconName, color: color, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(tag,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ]
          ],
        ),
        subtitle: subtitle.isNotEmpty ? Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ) : null,
        trailing: isSelected 
          ? Icon(Icons.check_circle, color: color)
          : hasChildren 
            ? Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        if (_isLoadingSubcategories) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text('إضافة إعلان جديد', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
            ),
            body: ShimmerList(itemCount: 8),
          );
        }

        final currentCategories = provider.categories ?? widget.allCategories;
        final displayCategories = currentCategories
            .where((c) => c.parentId == widget.parentCategory.id)
            .where((c) => _searchQuery.isEmpty || c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

        if (widget.parentCategory.id == 3) {
           displayCategories.sort((a, b) {
             final order = {310: 0, 311: 1, 306: 2, 316: 3, 314: 4, 315: 5, 313: 6};
             final aOrder = order[a.id] ?? 99;
             final bOrder = order[b.id] ?? 99;
             return aOrder.compareTo(bOrder);
           });
        } else if (widget.parentCategory.id == 310 || widget.parentCategory.name.contains('سكني')) {
           displayCategories.sort((a, b) {
             final order = {
               'شقق': 0,
               'بيوت مستقلة': 1,
               'ستوديو': 2,
               'طابق كامل': 3,
               'روف': 4,
             };
             int aOrder = order.entries.firstWhere((e) => a.name.contains(e.key), orElse: () => const MapEntry('', 99)).value;
             int bOrder = order.entries.firstWhere((e) => b.name.contains(e.key), orElse: () => const MapEntry('', 99)).value;
             
             if (a.name.contains('أخرى') || a.name.contains('اخرى')) aOrder = 999;
             if (b.name.contains('أخرى') || b.name.contains('اخرى')) bOrder = 999;
             
             if (aOrder == bOrder) {
               return a.name.compareTo(b.name);
             }
             return aOrder.compareTo(bOrder);
           });
        } else if (widget.parentCategory.id == 311 || widget.parentCategory.name.contains('تجاري')) {
           displayCategories.sort((a, b) {
             final order = {
               'محلات': 0,
               'مكاتب': 1,
               'معارض تجارية': 2,
               'صالونات': 3,
               'مطاعم': 4,
               'مخازن': 5,
               'عيادات': 6,
               'مراكز': 7,
               'صالات': 8,
               'فنادق': 9,
               'أراضي': 10,
               'مباني': 11,
             };
             int aOrder = order.entries.firstWhere((e) => a.name.contains(e.key), orElse: () => const MapEntry('', 99)).value;
             int bOrder = order.entries.firstWhere((e) => b.name.contains(e.key), orElse: () => const MapEntry('', 99)).value;
             
             if (a.name.contains('أخرى') || a.name.contains('اخرى')) aOrder = 999;
             if (b.name.contains('أخرى') || b.name.contains('اخرى')) bOrder = 999;
             
             if (aOrder == bOrder) {
               return a.name.compareTo(b.name);
             }
             return aOrder.compareTo(bOrder);
           });
        }

        return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إضافة إعلان جديد', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Hero Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: 24, 
                right: 24, 
                bottom: 32, 
                top: MediaQuery.of(context).padding.top + 80
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0075FF).withValues(alpha: 0.05), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentCategoryPath.isEmpty ? 'حدد التصنيف لـ "${widget.transactionType}"' : 'اختر التصنيف الفرعي',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'اختر القسم الأنسب لضمان وصول إعلانك للجمهور الصحيح وتسهيل عملية البحث.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('التصنيفات المتاحة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),
                  
                  // Modern Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن تصنيف...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                        prefixIcon: Icon(Icons.search, color: const Color(0xFF0075FF).withOpacity(0.7)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = "");
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  if (_hasError)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('تعذر تحميل الأقسام', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0075FF),
                              foregroundColor: Colors.white,
                            ),
                          )
                        ],
                      ),
                    )
                  else if (displayCategories.isEmpty && !_isLoadingSubcategories)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('لا توجد تصنيفات فرعية هنا', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('تحديث البيانات'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.grey.shade800,
                              elevation: 0,
                            ),
                          )
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final cat = displayCategories[index];
                        final catColor = _getColor(cat.colorHex);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                              final newPath = List<int>.from(_currentCategoryPath)..add(widget.parentCategory.id);
                              AnalyticsEngine().logButtonTapped(buttonName: 'select_category', location: 'add_ad_subcategories');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddAdSubcategoriesPage(
                                    allCategories: widget.allCategories,
                                    parentCategory: cat,
                                    transactionType: widget.transactionType,
                                    categoryPath: newPath,
                                    images: widget.images,
                                    reelVideo: widget.reelVideo,
                                  ),
                                ),
                              );
                          },
                          child: Stack(
                            children: [
                              _buildCompactCategoryItem(
                                cat.name,
                                cat.iconName,
                                catColor,
                                cat.description ?? '',
                                hasChildren: true,
                                imageUrl: ApiService.resolveIconUrl(cat.iconName),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
    });
  }
}
