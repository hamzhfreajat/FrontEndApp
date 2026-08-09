import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/shimmer_loading.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import 'category_details_page.dart';
import '../widgets/emoji_category_icon.dart';
import '../widgets/native_ad_widget.dart';

import '../services/analytics_engine.dart';

class CategoriesPage extends StatefulWidget {
  final int? parentId;
  final List<Category>? allCategories;
  final String title;
  final Category? category;
  
  final String? initialSearchQuery;
  final String? originalSearchQuery;
  final List<String>? initialTags;
  final List<String>? initialLocations;

  const CategoriesPage({
    super.key, 
    this.parentId, 
    this.allCategories, 
    this.title = 'الأقسام',
    this.category,
    this.initialSearchQuery,
    this.originalSearchQuery,
    this.initialTags,
    this.initialLocations,
  });

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  bool _isLoadingSubcategories = true;

  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: widget.category?.name ?? widget.title);
    if (widget.parentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Provider.of<AppProvider>(context, listen: false)
            .loadSubCategories(widget.parentId!).then((success) {
              if (mounted) {
                setState(() => _isLoadingSubcategories = false);
              }
            });
      });
    } else {
      _isLoadingSubcategories = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final provider = Provider.of<AppProvider>(context, listen: false);
        provider.loadSubCategories(3);
        provider.loadSubCategories(2);
        provider.loadSubCategories(10313);
      });
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

  @override
  Widget build(BuildContext context) {
    Widget grid = Container(
      color: const Color(0xFFF8FAFC),
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          
          final srcCategories = provider.categories;
          
          if (provider.isLoading && srcCategories == null) {
            // Instant load fallback (empty while booting)
            return const SizedBox.shrink();
          }
          if (srcCategories == null || srcCategories.isEmpty) {
            return const Center(
                child: Text('لا توجد أقسام حالياً',
                    style: TextStyle(fontSize: 16, color: Colors.grey)));
          }

          final allCategories = srcCategories;
          
          if (widget.parentId != null) {
            return const SizedBox.shrink();
          } else {
            final sections = [
              {'id': 3, 'title': 'عقارات للإيجار'},
              {'id': 2, 'title': 'عقارات للبيع'},
              {'id': 10313, 'title': 'أراضي'},
            ];
            
            final allSectionsEmpty = sections.every((s) => allCategories.where((c) => c.parentId == s['id']).isEmpty);
            if (allSectionsEmpty) {
              return ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: ShimmerLoading(
                       child: Container(width: 150, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)))
                    ),
                  ),
                  const ShimmerCategoryGrid(itemCount: 6),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: ShimmerLoading(
                       child: Container(width: 150, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)))
                    ),
                  ),
                  const ShimmerCategoryGrid(itemCount: 3),
                ],
              );
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.symmetric(vertical: 24),
              itemCount: sections.length,
              itemBuilder: (context, sectionIndex) {
                 final sectionId = sections[sectionIndex]['id'] as int;
                 final sectionTitle = sections[sectionIndex]['title'] as String;
                 
                 final sectionCats = allCategories.where((c) => c.parentId == sectionId).toList();
                 if (sectionCats.isEmpty) return const SizedBox.shrink();
                 sectionCats.sort((a, b) => b.adsCount.compareTo(a.adsCount));
                 
                 return Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                       child: Text(
                         sectionTitle,
                         style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
                       ),
                     ),
                     GridView.builder(
                       shrinkWrap: true,
                       physics: const NeverScrollableScrollPhysics(),
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                         crossAxisCount: 2,
                         childAspectRatio: 0.9,
                         crossAxisSpacing: 16,
                         mainAxisSpacing: 16,
                       ),
                       itemCount: sectionCats.length,
                       itemBuilder: (context, index) {
                         return _buildCategoryCard(context, sectionCats[index], allCategories);
                       }
                     ),
                     const SizedBox(height: 16),
                   ]
                 );
              }
            );
          }

        },
      ),
    );

    final pullToRefresh = RefreshIndicator(
      onRefresh: () async {
        final provider = Provider.of<AppProvider>(context, listen: false);
        if (widget.parentId != null) {
          await provider.loadSubCategories(widget.parentId!);
        } else {
          await Future.wait([
            provider.loadSubCategories(3),
            provider.loadSubCategories(2),
            provider.loadSubCategories(10313),
          ]);
        }
      },
      child: grid,
    );

    if (widget.parentId != null) {
      String imagePath;
      String subtitle;
      if (widget.parentId == 2) {
        imagePath = 'assets/images/real_estate/house_sale.png';
        subtitle = 'اكتشف أفضل الخيارات المتاحة للبيع';
      } else if (widget.parentId == 3) {
        imagePath = 'assets/images/real_estate/rent_apt.png';
        subtitle = 'ابحث عن مسكنك المثالي للإيجار';
      } else {
        imagePath = _getImageForCategory(widget.parentId!);
        subtitle = 'اكتشف أفضل العروض المتاحة';
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          onRefresh: () async {
            await Provider.of<AppProvider>(context, listen: false).loadSubCategories(widget.parentId!);
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverAppBar(
                expandedHeight: 140.0,
                pinned: true,
                stretch: true,
                backgroundColor: const Color(0xFF0075FF),
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 12, right: 48),
                  title: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                      fontSize: 18,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.9),
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 48,
                        bottom: 54, // Increased to avoid overlap with scaled title
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  transform: Matrix4.translationValues(0.0, -20.0, 0.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Consumer<AppProvider>(
                    builder: (context, provider, child) {
                      final allCategories = provider.categories;
                      
                      final displayCategories = allCategories?.where((c) => c.parentId == widget.parentId).toList() ?? [];

                      if (_isLoadingSubcategories) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 24.0),
                          child: ShimmerCategoryGrid(itemCount: 9),
                        );
                      }

                      if (displayCategories.isEmpty) {
                        return const SizedBox(height: 300, child: Center(child: Text('لا توجد أقسام فرعية', style: TextStyle(fontSize: 16, color: Colors.grey))));
                      }

                      displayCategories.sort((a, b) => b.adsCount.compareTo(a.adsCount));

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 24, 12, 40),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: displayCategories.length,
                        itemBuilder: (context, index) {
                          return _buildCategoryCard(context, displayCategories[index], allCategories ?? []);
                        },
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32.0, top: 0.0),
                  child: const NativeAdWidget(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pullToRefresh;
  }

  String _getImageForCategory(int id) {
    switch (id) {
      // Sale Categories
      case 10310: return 'assets/images/real_estate/sale_house.png';
      case 10311: return 'assets/images/real_estate/sale_commercial.png';
      case 10313: return 'assets/images/real_estate/land_land.png';
      case 10314: return 'assets/images/real_estate/sale_farm.png';
      case 10315: return 'assets/images/real_estate/sale_resort.png';
      
      // Rent Categories
      case 306: return 'assets/images/real_estate/shared_housing.png';
      case 310: return 'assets/images/real_estate/rent_house.png';
      case 311: return 'assets/images/real_estate/rent_commercial.png';
      case 313: return 'assets/images/real_estate/land_land.png';
      case 314: return 'assets/images/real_estate/land_farm.png';
      case 315: return 'assets/images/real_estate/land_resort.png';
      case 316: return 'assets/images/real_estate/land_country.png';
      
      // Lands Categories
      case 19000: return 'assets/images/real_estate/land_residential.png';
      case 19010: return 'assets/images/real_estate/land_commercial.png';
      case 19020: return 'assets/images/real_estate/land_industrial.png';
      case 19030: return 'assets/images/real_estate/land_agricultural.png';
      case 19040: return 'assets/images/real_estate/land_touristic.png';
      case 19050: return 'assets/images/real_estate/land_mixed.png';
      case 19060: return 'assets/images/real_estate/land_gov.png';
      case 19070: return 'assets/images/real_estate/land_unzoned.png';
      
      default: return 'assets/images/real_estate/house.png';
    }
  }

  Widget _buildCategoryCard(BuildContext context, Category cat, List<Category> allCategories) {
    final imagePath = _getImageForCategory(cat.id);
    final isSale = cat.parentId == 2;
    final gradientColors = isSale 
        ? const [Color(0xFF0075FF), Color(0xFF0052B4)] 
        : const [Color(0xFF8E2DE2), Color(0xFF4A00E0)];
    
    return GestureDetector(
      onTap: () async {
        final provider = Provider.of<AppProvider>(context, listen: false);

        // Leaf node: already fetched and confirmed no children → skip the loader
        if (provider.isLeafCategory(cat.id)) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryDetailsPage(
                category: cat,
                allCategories: allCategories,
                initialSearchQuery: widget.initialSearchQuery,
                originalSearchQuery: widget.originalSearchQuery,
                initialTags: widget.initialTags,
                initialLocations: widget.initialLocations,
              ),
            ),
          );
          return;
        }

        // Check if we already have the subcategories loaded
        final existingChildren = provider.categories?.where((c) => c.parentId == cat.id).toList() ?? [];
        if (provider.fetchedParentIds.contains(cat.id) && existingChildren.isNotEmpty) {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoriesPage(
                parentId: cat.id,
                title: cat.name,
                category: cat,
                allCategories: allCategories,
                initialSearchQuery: widget.initialSearchQuery,
                initialTags: widget.initialTags,
                initialLocations: widget.initialLocations,
              ),
            ),
          );
          return;
        }

        // Need to fetch from server -> Show loader
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF0075FF)),
          ),
        );

        final success = await provider.loadSubCategories(cat.id);

        if (!context.mounted) return;
        Navigator.pop(context); // Remove the loader

        final displayCategories = provider.categories?.where((c) => c.parentId == cat.id).toList() ?? [];

        if (success && displayCategories.isEmpty) {
          // It's 100% the latest category (leaf)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryDetailsPage(
                category: cat,
                allCategories: allCategories,
                initialSearchQuery: widget.initialSearchQuery,
                originalSearchQuery: widget.originalSearchQuery,
                initialTags: widget.initialTags,
                initialLocations: widget.initialLocations,
              ),
            ),
          );
        } else {
          // Has children -> go to CategoriesPage
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoriesPage(
                parentId: cat.id,
                title: cat.name,
                category: cat,
                allCategories: allCategories,
                initialSearchQuery: widget.initialSearchQuery,
                initialTags: widget.initialTags,
                initialLocations: widget.initialLocations,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large Image
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradientColors.map((c) => c.withOpacity(0.5)).toList(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    imagePath,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Black Text at the bottom
            FittedBox(
              child: Text(
                cat.name,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1E1E2C),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
            if (cat.adsCount > 0) ...[
              const SizedBox(height: 2),
              Text(
                '${cat.adsCount} إعلان',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}


