import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/category.dart';
import '../models/ad.dart';
import '../models/location.dart';
import '../models/saved_search.dart';
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../services/analytics_engine.dart';

import '../features/chat/presentation/screens/premium_chat_screen.dart';
import '../features/chat/presentation/screens/premium_inbox_screen.dart';
import '../features/chat/data/repositories/firebase_chat_repository.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/premium_video_player.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/notification_provider.dart';
import 'notifications_page.dart';
import '../providers/auth_provider.dart';
import '../providers/saved_search_provider.dart';
import '../models/saved_search.dart';
import 'ad_details_page.dart';
import 'add_ad_images.dart';
import 'root_screen.dart';
import '../widgets/premium_real_estate_card.dart';
import '../widgets/emoji_category_icon.dart';
import '../widgets/premium_filter_bottom_sheet.dart';

class CategoryDetailsPage extends StatefulWidget {
  final Category category;
  final List<Category> allCategories;
  final Color? parentBrandColor;
  final Ad? highlightedAd;
  final double? initialMinPrice;
  final double? initialMaxPrice;
  final List<String>? initialTags;
  final List<String>? initialLocations;
  final String? initialSort;
  final bool? initialIsHot;
  final String? initialSearchQuery;
  final bool initialShowSaveSearch;

  const CategoryDetailsPage({
    super.key, 
    required this.category, 
    this.allCategories = const [],
    this.parentBrandColor,
    this.highlightedAd,
    this.initialMinPrice,
    this.initialMaxPrice,
    this.initialTags,
    this.initialLocations,
    this.initialSort,
    this.initialIsHot,
    this.initialSearchQuery,
    this.initialShowSaveSearch = false,
  });

  @override
  State<CategoryDetailsPage> createState() => _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends State<CategoryDetailsPage> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _tagsScrollController = ScrollController();

  bool _isMapMode = false; // Phase 1: Map/List Toggle State
  final ValueNotifier<bool> _isBottomNavVisible = ValueNotifier<bool>(true);
  static const _navAccent = Color(0xFF1A73E8);

  void _onScroll() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isBottomNavVisible.value) _isBottomNavVisible.value = false;
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_isBottomNavVisible.value) _isBottomNavVisible.value = true;
    }

    // Trigger loading 1500px before hitting the bottom (~5-6 ads ahead)
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 1500 &&
        !_isLoadingAds &&
        !_isLoadingMore &&
        _hasMoreAds) {
      _loadMoreAds();
    }
  }

  List<Ad> _ads = [];
  bool _isLoadingAds = true;
  bool _isLoadingMore = false;
  bool _hasMoreAds = true;
  bool _hasError = false;
  int _skip = 0;
  final int _limit = 20;
  List<String> _selectedTags = [];
  int _totalAdsCount = 0;
  final Set<String> _availableTags = {};
  final Map<String, int> _tagCounts = {};
  Set<String> _compatibleTags = {}; // Tags that exist on currently filtered ads
  final List<String> _orderedTags = []; // Stores initial sorted order of tags
  int _fetchGeneration = 0; // Prevents stale fetch results from overwriting newer ones
  bool _isHighlightActive = false;
  bool _isSubcategoriesLoaded = false;
  String _searchQuery = '';
  late final TextEditingController _searchController;

  // Dynamic Filters Hookup
  String? _sortBy = 'newest';
  double? _minPrice;
  double? _maxPrice;
  List<String>? _locationsFilter;
  bool? _isHot;
  double? _userLat;
  double? _userLng;
  
  Map<String, dynamic>? _savedCategoryFilters;

  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: widget.category.name);
    _searchQuery = widget.initialSearchQuery ?? '';
    _searchController = TextEditingController(text: _searchQuery);
    _scrollController.addListener(_onScroll);
    
    // Sync initial location from global AppProvider
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    if (widget.initialSort != null) {
      _sortBy = widget.initialSort;
    }
    if (widget.initialIsHot != null) {
      _isHot = widget.initialIsHot;
    }

    _minPrice = widget.initialMinPrice;
    _maxPrice = widget.initialMaxPrice;
    if (widget.initialTags != null) {
      _selectedTags = List.from(widget.initialTags!);
    }
    
    if (widget.initialLocations != null) {
      _locationsFilter = List.from(widget.initialLocations!);
    } else if (appProvider.selectedRegions != null && appProvider.selectedRegions!.isNotEmpty) {
      _locationsFilter = [];
      if (appProvider.selectedCity != null) {
        _locationsFilter!.add(appProvider.selectedCity!.nameAr);
      }
      _locationsFilter!.addAll(appProvider.selectedRegions!.map((r) => r.nameAr));
    } else if (appProvider.selectedCity != null) {
      _locationsFilter = [appProvider.selectedCity!.nameAr];
    } else if (appProvider.rawLocationFallback != null && appProvider.rawLocationFallback != 'كل الأردن') {
      _locationsFilter = [appProvider.rawLocationFallback!];
    } else {
      _locationsFilter = null; // All Jordan
    }

    if (widget.highlightedAd != null) {
      _isHighlightActive = true;
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _isHighlightActive = false;
          });
        }
      });
    }
    
    if (widget.initialShowSaveSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSaveSearchBottomSheet(context, widget.parentBrandColor ?? Colors.blue);
        }
      });
    }
    // Delay fetching slightly to allow the page transition to animate smoothly
    // without frame drops. Native UI shimmer will show during this time natively!
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _fetchAds();
    });
    
    // Track as the latest category viewed by the user
    _apiService.updateLatestCategory(widget.category.id);
    AnalyticsEngine().logCategoryViewed(
      categoryName: widget.category.name,
    );
    
    // Fetch saved filters for this category
    _loadSavedCategoryFilters();
  }

  Future<void> _loadSavedCategoryFilters() async {
    // Only load if user hasn't opened page with active initial filters
    if (_minPrice != null || _maxPrice != null || _selectedTags.isNotEmpty) return;
    
    Map<String, dynamic>? filters = await _apiService.getCategoryFilters(widget.category.id);
    
    // Fallback to parent category if no saved filters exist for this specific subcategory
    if ((filters == null || (filters['min_price'] == null && filters['max_price'] == null && (filters['tags'] == null || (filters['tags'] as List).isEmpty))) && widget.category.parentId != null) {
      final parentFilters = await _apiService.getCategoryFilters(widget.category.parentId!);
      if (parentFilters != null) {
        filters = parentFilters;
      }
    }

    if (filters != null && mounted) {
      // Don't show if it's completely empty
      if (filters['min_price'] == null && filters['max_price'] == null && (filters['tags'] == null || (filters['tags'] as List).isEmpty)) {
        return;
      }
      setState(() {
        _savedCategoryFilters = filters;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tagsScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingAds = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تفعيل خدمات الموقع')));
        if (mounted) setState(() => _isLoadingAds = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض صلاحية الموقع')));
          if (mounted) setState(() => _isLoadingAds = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض صلاحية الموقع نهائياً، يرجى تفعيلها من الإعدادات')));
        if (mounted) setState(() => _isLoadingAds = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _userLat = position.latitude;
          _userLng = position.longitude;
          _sortBy = 'nearest';
          _isHot = false;
        });
        _fetchAds();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء جلب الموقع')));
      if (mounted) setState(() => _isLoadingAds = false);
    }
  }
  void _saveCurrentFilters() {
    try {
      ApiService().saveCategoryFilters(
        widget.category.id,
        _minPrice,
        _maxPrice,
        _selectedTags,
      );
    } catch (_) {}
  }

  Future<void> _fetchAds() async {
    if (!mounted) return;
    _fetchGeneration++;
    final thisGeneration = _fetchGeneration;
    setState(() {
      _isLoadingAds = true;
      _hasError = false;
      if (_availableTags.isEmpty) _isSubcategoriesLoaded = false;
      _skip = 0;
      _hasMoreAds = true;
      _ads.clear();
      if (widget.highlightedAd != null) {
        _ads.add(widget.highlightedAd!);
      }
    });
    try {
      final tags = _selectedTags.isNotEmpty ? _selectedTags : null;

      final cleanedLocations = (_locationsFilter != null && (_locationsFilter!.contains('كل المدن') || _locationsFilter!.contains('كل الأردن'))) ? null : _locationsFilter;

      // Execute loadSubCategories without blocking the ads fetching
      Provider.of<AppProvider>(context, listen: false)
          .loadSubCategories(widget.category.id, locations: cleanedLocations)
          .then((_) {
            if (mounted && thisGeneration == _fetchGeneration) {
              setState(() => _isSubcategoriesLoaded = true);
            }
          })
          .catchError((_) {
            if (mounted && thisGeneration == _fetchGeneration) {
              setState(() => _isSubcategoriesLoaded = true);
            }
            return false;
          });

      // Execute all 2 requests via concurrent futures 
      final results = await Future.wait([
        _apiService.fetchAdsCount(
          categoryId: widget.category.id, 
          tags: tags,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
          locations: cleanedLocations,
          isHot: _isHot,
        ),
        _apiService.fetchAds(
          categoryId: widget.category.id, 
          tags: tags, 
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          skip: _skip, 
          limit: _limit,
          sortBy: _sortBy,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
          locations: cleanedLocations,
          isHot: _isHot,
          userLat: _sortBy == 'nearest' ? _userLat : null,
          userLng: _sortBy == 'nearest' ? _userLng : null,
        ),
      ]);
      
      if (!mounted || thisGeneration != _fetchGeneration) return;

      final count = results[0] as int;
      final fetchedAds = results[1] as List<Ad>;
      
      setState(() {
        _ads = fetchedAds;
        if (widget.highlightedAd != null) {
          _ads.removeWhere((a) => a.id == widget.highlightedAd!.id);
          _ads.insert(0, widget.highlightedAd!);
        }
        _totalAdsCount = count;
        _skip += _limit;
        _hasMoreAds = fetchedAds.length == _limit;
        _isLoadingAds = false;
        
        // Always collect tags from ads so the tag bar stays populated
        // _compatibleTags = tags that exist on the CURRENT filtered results
        _tagCounts.clear();
        final Set<String> currentTags = {};
        for (var ad in fetchedAds) {
          for (var tag in ad.tags) {
            _tagCounts[tag] = (_tagCounts[tag] ?? 0) + 1;
            _availableTags.add(tag);
          }
          currentTags.addAll(ad.tags);
        }
        _compatibleTags = currentTags;
        
        // Populate ordered tags once
        if (_orderedTags.isEmpty && _availableTags.isNotEmpty) {
           var list = _availableTags.toList();
           list.sort((a, b) {
             int countCompare = (_tagCounts[b] ?? 0).compareTo(_tagCounts[a] ?? 0);
             if (countCompare != 0) return countCompare;
             return a.compareTo(b);
           });
           _orderedTags.addAll(list);
        } else {
           for (var tag in _availableTags) {
              if (!_orderedTags.contains(tag)) _orderedTags.add(tag);
           }
        }
      });
    } catch (_) {
      if (!mounted || thisGeneration != _fetchGeneration) return;
      setState(() {
        _isLoadingAds = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMoreAds() async {
    if (!mounted) return;
    setState(() => _isLoadingMore = true);
    try {
      final fetchedAds = await _apiService.fetchAds(
        categoryId: widget.category.id, 
        tags: _selectedTags.isNotEmpty ? _selectedTags : null, 
        skip: _skip, 
        limit: _limit,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        sortBy: _sortBy,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        locations: _locationsFilter,
        isHot: _isHot,
        userLat: _sortBy == 'nearest' ? _userLat : null,
        userLng: _sortBy == 'nearest' ? _userLng : null,
      );
      if (!mounted) return;
      setState(() {
        _ads.addAll(fetchedAds);
        _skip += _limit;
        _hasMoreAds = fetchedAds.length == _limit;
        _isLoadingMore = false;
        
        if (_selectedTags.isEmpty) {
          for (var ad in fetchedAds) {
            for (var tag in ad.tags) {
              _tagCounts[tag] = (_tagCounts[tag] ?? 0) + 1;
              _availableTags.add(tag);
            }
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Color _getBrandColor() {
    if (widget.parentBrandColor != null) {
      return widget.parentBrandColor!;
    }
    
    if (widget.category.colorHex != null &&
        widget.category.colorHex!.isNotEmpty) {
      final buffer = StringBuffer();
      if (widget.category.colorHex!.length == 6 ||
          widget.category.colorHex!.length == 7) {
        buffer.write('ff');
      }
      buffer.write(widget.category.colorHex!.replaceFirst('#', ''));
      try {
        return Color(int.parse(buffer.toString(), radix: 16));
      } catch (_) {
        return const Color(0xFF0075FF);
      }
    }
    return const Color(0xFF0075FF);
  }

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
    final brandColor = _getBrandColor();

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFCFCFC),
      body: RefreshIndicator(
        onRefresh: _fetchAds,
        color: brandColor,
        child: CustomScrollView(
          controller: _scrollController,
          cacheExtent: 500,
          physics: const ClampingScrollPhysics(),
          slivers: [
            _buildGlassAppBar(brandColor),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroHeader(brandColor),
                  _buildSearchBar(brandColor),
                  _buildSleekSubCategories(brandColor),
                  _buildMinimalTags(brandColor),
                  if (_ads.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildListingQualityIndicator(),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    width: double.infinity,
                    height: 8,
                    color: const Color(0xFFF9FAFB),
                  ),
                ],
              ),
            ),
            _buildCleanAdsList(),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)), // Space for the floating bottom bar
          ],
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: _isBottomNavVisible,
        builder: (context, isVisible, child) {
          return AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            offset: isVisible ? Offset.zero : const Offset(0, 1),
            child: child,
          );
        },
        child: _buildBottomNav(context, brandColor),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, Color brandColor) {
    return SafeArea(
      bottom: true,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12), // Floating pill
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: brandColor.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Visually Right in RTL
              _buildPremiumAddButton(context, brandColor),
              _bottomNavItem(Icons.home_outlined, 'الرئيسية', false, brandColor, () {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RootScreen(initialIndex: 0)), (route) => false);
              }),
              _bottomNavItem(Icons.grid_view_rounded, 'الأقسام', true, brandColor, null),
              _bottomNavItem(Icons.article_outlined, 'إعلاناتي', false, brandColor, () {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RootScreen(initialIndex: 2)), (route) => false);
              }),
              _bottomNavItem(Icons.person_outline_rounded, 'حسابي', false, brandColor, () {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RootScreen(initialIndex: 3)), (route) => false);
              }),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, bool active, Color brandColor, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: BoxDecoration(
            color: active ? brandColor.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 22, color: active ? brandColor : const Color(0xFF8A93A0)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? brandColor : const Color(0xFF8A93A0),
              overflow: TextOverflow.ellipsis,
            ), maxLines: 1),
          ]),
        ),
      ),
    );
  }

  Widget _buildPremiumAddButton(BuildContext context, Color brandColor) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAdImagesPage())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [brandColor, Color.lerp(brandColor, Colors.black, 0.2) ?? brandColor]
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: brandColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4)
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text('أضف إعلان', style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassAppBar(Color brandColor) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.98),
      surfaceTintColor: Colors.transparent,
      expandedHeight: 50.0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs (Mocked)
          Row(
            children: [
              Icon(Icons.home_outlined, size: 10, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text('العقارات', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              Icon(Icons.chevron_right, size: 10, color: Colors.grey.shade500),
              Flexible(
                child: Text(
                  widget.category.name, 
                  style: TextStyle(fontSize: 10, color: brandColor, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Static Category Title
          Text(
            widget.category.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
        ],
      ),
      actions: [
        // Support Chat Action
        Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final currentUserId = authProvider.userData?['sub']?.toString() ?? '';
            return IconButton(
              icon: const Icon(Icons.support_agent_rounded, color: Colors.black87, size: 24),
              onPressed: () {
                if (currentUserId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى تسجيل الدخول أولاً'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumChatScreen(
                  adId: 'support',
                  adTitle: 'خدمة العملاء',
                  adPrice: '',
                  adImageUrl: '',
                  currentUserId: currentUserId,
                  currentUserName: authProvider.userData?['name']?.toString() ?? 'مستخدم',
                  currentUserPhone: authProvider.userData?['phone_number']?.toString(),
                  otherUserId: 'admin',
                  otherUserName: 'فريق الدعم',
                  isSeller: false,
                )));
              },
            );
          },
        ),
        // Chat Action
        Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final currentUserId = authProvider.userData?['sub']?.toString() ?? '';
            return StreamBuilder<int>(
              stream: FirebaseChatRepository().getTotalUnreadCount(currentUserId),
              builder: (context, snapshot) {
                final unreadChatCount = snapshot.data ?? 0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.black87, size: 24),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumInboxScreen()));
                      },
                    ),
                    if (unreadChatCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE91E63),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Center(
                            child: Text(
                              unreadChatCount > 99 ? '99+' : unreadChatCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                  ],
                );
              },
            );
          },
        ),
        // Notifications Action
        Consumer<NotificationProvider>(
          builder: (context, notificationProvider, child) {
            final unreadCount = notificationProvider.unreadCount;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 24),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE91E63),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
              ],
            );
          }
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _saveCurrentSearch(String alertType) {
    final newSearch = SavedSearch(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      categoryId: widget.category.id,
      categoryName: widget.category.name,
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      locations: _locationsFilter ?? [],
      tags: _selectedTags,
      alertType: alertType,
      createdAt: DateTime.now(),
    );
    Provider.of<SavedSearchProvider>(context, listen: false).saveSearch(newSearch);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ البحث بنجاح!', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.green),
    );
  }

  void _showSaveSearchBottomSheet(BuildContext context, Color brandColor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active, color: brandColor, size: 28),
                  const SizedBox(width: 12),
                  const Text('حفظ البحث وتخصيص التنبيهات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('سجل للحصول على تنبيهات عند إضافة عقارات تطابق بحثك:', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.flash_on, color: Colors.orange),
                title: const Text('تنبيه فوري'),
                subtitle: const Text('أرسل لي إشعاراً فور توفر عقار جديد'),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveCurrentSearch('instant');
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.blue),
                title: const Text('ملخص يومي'),
                subtitle: const Text('أرسل لي ملخصاً بأفضل العقارات المضافة اليوم'),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveCurrentSearch('daily');
                },
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSortOption(BuildContext ctx, String value, String label, IconData iconData, Color iconColor) {
    final bool isActive = _sortBy == value;
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        if (value == 'nearest') {
          _getCurrentLocation();
        } else {
          setState(() => _sortBy = value);
          _fetchAds();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade50.withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? Colors.blue.shade200 : Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? Colors.blue.shade100 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: 18, color: isActive ? Colors.blue.shade700 : iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? Colors.blue.shade800 : Colors.black87,
                ),
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 22),
          ],
        ),
      ),
    );
  }

  void _showSortBottomSheet(Color brandColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: Text('ترتيب حسب', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.black87)),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0, bottom: 8.0, right: 8.0),
                    child: Text('السعر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black45)),
                  ),
                  _buildSortOption(ctx, 'price_asc', 'من الأقل للأعلى', Icons.arrow_upward_rounded, Colors.green),
                  const SizedBox(height: 4),
                  _buildSortOption(ctx, 'price_desc', 'من الأعلى للأقل', Icons.arrow_downward_rounded, Colors.green.shade800),

                  const Padding(
                    padding: EdgeInsets.only(top: 16.0, bottom: 8.0, right: 8.0),
                    child: Text('الوقت', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black45)),
                  ),
                  _buildSortOption(ctx, 'newest', 'الأحدث أولاً', Icons.new_releases_rounded, Colors.blue),
                  const SizedBox(height: 4),
                  _buildSortOption(ctx, 'oldest', 'الأقدم أولاً', Icons.history_rounded, Colors.blueGrey),

                  const Padding(
                    padding: EdgeInsets.only(top: 16.0, bottom: 8.0, right: 8.0),
                    child: Text('الرائج', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black45)),
                  ),
                  _buildSortOption(ctx, 'nearest', 'الأقرب إليك', Icons.location_on_rounded, Colors.red.shade400),
                  const SizedBox(height: 4),
                  _buildSortOption(ctx, 'most_viewed', 'الأكثر مشاهدة', Icons.local_fire_department_rounded, Colors.deepOrange),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  void _showFilterBottomSheet(Color brandColor) {
    final allCats = Provider.of<AppProvider>(context, listen: false).categories ?? widget.allCategories;
    final subCategories = allCats.where((c) => c.parentId == widget.category.id).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return PremiumFilterBottomSheet(
          category: widget.category,
          subCategories: subCategories,
          brandColor: brandColor,
          initialMinPrice: _minPrice,
          initialMaxPrice: _maxPrice,
          initialTags: _selectedTags,
          totalResultsCount: _totalAdsCount,
          searchQuery: _searchQuery,
          isHot: _isHot,
          initialLocations: _locationsFilter,
        );
      }
    ).then((result) {
      if (result != null && result is PremiumFilterData) {
        
        // Push filter tracking event asynchronously
        try {
          ApiService().logUserActivity(
            'APPLY_FILTER',
            categoryId: result.selectedSubCategory?.id ?? widget.category.id,
            filters: {
              if (result.minPrice != null) 'min_price': result.minPrice,
              if (result.maxPrice != null) 'max_price': result.maxPrice,
              if (result.tags.isNotEmpty) 'tags': result.tags,
              if (result.locations != null) 'locations': result.locations,
            }
          );
          
          // Save category filters to preferences (excluding locations as they are global)
          ApiService().saveCategoryFilters(
            result.selectedSubCategory?.id ?? widget.category.id,
            result.minPrice,
            result.maxPrice,
            result.tags
          );
        } catch (_) {}

        if (result.selectedSubCategory != null && result.selectedSubCategory!.id != widget.category.id) {
           Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CategoryDetailsPage(
                  category: result.selectedSubCategory!,
                  allCategories: widget.allCategories,
                  parentBrandColor: brandColor,
                  initialMinPrice: result.minPrice,
                  initialMaxPrice: result.maxPrice,
                  initialTags: result.tags,
                  initialLocations: result.locations,
                  initialShowSaveSearch: result.saveSearchRequested,
              )),
           );
        } else {
           setState(() {
             _minPrice = result.minPrice;
             _maxPrice = result.maxPrice;
             _selectedTags = result.tags;
             _locationsFilter = result.locations;
           });
           _fetchAds();
           if (result.saveSearchRequested) {
             _showSaveSearchBottomSheet(context, brandColor);
           }
        }
      }
    });
  }
  String _normalizeArabic(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  void _showLocationBottomSheet(Color brandColor) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    City? selectedCityForFilter;
    List<Region> selectedRegionsForFilter = List.from(appProvider.selectedRegions ?? []);
    String searchQuery = '';
    final TextEditingController searchController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final appProvider = Provider.of<AppProvider>(context, listen: false);
            final dbCities = appProvider.dbCities ?? [];
            
            final normalizedSearch = _normalizeArabic(searchQuery);
            
            final filteredCities = searchQuery.isEmpty 
              ? dbCities 
              : dbCities.where((c) => _normalizeArabic(c.nameAr).contains(normalizedSearch)).toList();
              
            final filteredRegions = selectedCityForFilter == null || searchQuery.isEmpty 
              ? selectedCityForFilter?.regions ?? []
              : selectedCityForFilter!.regions.where((r) => _normalizeArabic(r.nameAr).contains(normalizedSearch)).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.only(top: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      children: [
                        if (selectedCityForFilter != null)
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
                            onPressed: () => setModalState(() {
                              selectedCityForFilter = null;
                              searchQuery = '';
                              searchController.clear();
                            }),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.black87),
                            onPressed: () => Navigator.pop(ctx),
                          ),

                        Expanded(
                          child: Text(
                            selectedCityForFilter == null ? 'اختر المدينة' : 'مناطق ${selectedCityForFilter!.nameAr}', 
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandColor)
                          ),
                        ),
                        
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: selectedCityForFilter == null ? 'ابحث عن مدينة...' : 'ابحث عن منطقة...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15, fontWeight: FontWeight.normal),
                          prefixIcon: Icon(Icons.search_rounded, color: brandColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        ),
                      )
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: selectedRegionsForFilter.isEmpty
                          ? const SizedBox.shrink()
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: selectedRegionsForFilter.map((r) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Chip(
                                      label: Text(r.nameAr, style: TextStyle(color: brandColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                      backgroundColor: brandColor.withOpacity(0.1),
                                      deleteIcon: Icon(Icons.close, size: 16, color: brandColor),
                                      onDeleted: () async {
                                        setModalState(() {
                                          selectedRegionsForFilter.removeWhere((reg) => reg.id == r.id);
                                        });
                                        final appProvider = Provider.of<AppProvider>(context, listen: false);
                                        if (selectedRegionsForFilter.isEmpty) {
                                          await appProvider.setLocation(selectedCityForFilter, null, null);
                                          setState(() { _locationsFilter = selectedCityForFilter != null ? [selectedCityForFilter!.nameAr] : null; });
                                        } else {
                                          Set<City> involvedCities = {};
                                          if (appProvider.dbCities != null) {
                                            for (var reg in selectedRegionsForFilter) {
                                              try { involvedCities.add(appProvider.dbCities!.firstWhere((c) => c.id == reg.cityId)); } catch (_) {}
                                            }
                                          }
                                          await appProvider.setLocation(involvedCities.isNotEmpty ? involvedCities.first : null, selectedRegionsForFilter.toList(), null);
                                          setState(() { _locationsFilter = selectedRegionsForFilter.map((r) => r.nameAr).toList(); });
                                        }
                                        _fetchAds();
                                      },
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: brandColor.withOpacity(0.2)),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ),
                  
                  if (selectedCityForFilter == null) ...[
                    // Step 1: Cities
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredCities.length + (searchQuery.isEmpty ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        itemBuilder: (context, index) {
                          if (searchQuery.isEmpty && index == 0) {
                            return Container(
                              color: Colors.white,
                              child: ListTile(
                                title: const Text('كل الأردن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                trailing: const Icon(Icons.chevron_left, size: 22, textDirection: TextDirection.ltr, color: Colors.grey),
                                onTap: () async {
                                  final appProvider = Provider.of<AppProvider>(context, listen: false);
                                  await appProvider.setLocation(null, null, 'كل الأردن');
                                  setState(() { _locationsFilter = ['كل الأردن']; });
                                  Navigator.pop(ctx);
                                  _fetchAds();
                                },
                              ),
                            );
                          }
                          
                          final c = filteredCities[searchQuery.isEmpty ? index - 1 : index];
                          return Container(
                            color: Colors.white,
                            child: ListTile(
                              title: Text(c.nameAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                              trailing: const Icon(Icons.chevron_left, size: 22, textDirection: TextDirection.ltr, color: Colors.grey),
                              onTap: () {
                                setModalState(() {
                                  selectedCityForFilter = c;
                                  searchQuery = '';
                                  searchController.clear();
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    // Step 2: Regions
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredRegions.length + (searchQuery.isEmpty ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        itemBuilder: (context, index) {
                          if (searchQuery.isEmpty && index == 0) {
                            return Container(
                              color: Colors.white,
                              child: ListTile(
                                title: Text('كل مناطق ${selectedCityForFilter!.nameAr}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                trailing: const Icon(Icons.chevron_left, size: 22, textDirection: TextDirection.ltr, color: Colors.grey),
                                onTap: () async {
                                  final appProvider = Provider.of<AppProvider>(context, listen: false);
                                  await appProvider.setLocation(selectedCityForFilter, null, null);
                                  setState(() { _locationsFilter = [selectedCityForFilter!.nameAr]; });
                                  Navigator.pop(ctx);
                                  _fetchAds();
                                },
                              ),
                            );
                          }
                          
                          final r = filteredRegions[searchQuery.isEmpty ? index - 1 : index];
                          final isSelected = selectedRegionsForFilter.any((reg) => reg.id == r.id);
                          return Container(
                            color: Colors.white,
                            child: CheckboxListTile(
                              title: Text(r.nameAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                              value: isSelected,
                              activeColor: brandColor,
                              onChanged: (bool? value) {
                                setModalState(() {
                                  if (value == true) {
                                    selectedRegionsForFilter.add(r);
                                  } else {
                                    selectedRegionsForFilter.removeWhere((reg) => reg.id == r.id);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final appProvider = Provider.of<AppProvider>(context, listen: false);
                            if (selectedRegionsForFilter.isEmpty) {
                              await appProvider.setLocation(selectedCityForFilter, null, null);
                              setState(() { _locationsFilter = [selectedCityForFilter!.nameAr]; });
                            } else {
                              Set<City> involvedCities = {};
                              if (appProvider.dbCities != null) {
                                for (var r in selectedRegionsForFilter) {
                                  try {
                                    final city = appProvider.dbCities!.firstWhere((c) => c.id == r.cityId);
                                    involvedCities.add(city);
                                  } catch (_) {}
                                }
                              }
                              await appProvider.setLocation(involvedCities.isNotEmpty ? involvedCities.first : selectedCityForFilter, selectedRegionsForFilter, null);
                              setState(() { 
                                _locationsFilter = [
                                  ...involvedCities.map((c) => c.nameAr),
                                  ...selectedRegionsForFilter.map((r) => r.nameAr)
                                ]; 
                              });
                            }
                            Navigator.pop(ctx);
                            _fetchAds();
                          },
                          child: const Text('تطبيق', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }
        );
      }
    );
  }


  Widget _buildSmartSummaryBar(Color brandColor) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        String locationText = 'جاري التحديد...';
        
        if (_locationsFilter != null && _locationsFilter!.isNotEmpty) {
          locationText = _locationsFilter!.join('، ');
        } else if (provider.rawLocationFallback != null) {
          locationText = provider.rawLocationFallback!;
        } else if (provider.selectedCity != null) {
          if (provider.selectedRegions != null && provider.selectedRegions!.isNotEmpty) {
            final regionNames = provider.selectedRegions!.map((r) => r.nameAr).join('، ');
            locationText = '$regionNames، ${provider.selectedCity!.nameAr}';
          } else {
            locationText = provider.selectedCity!.nameAr;
          }
        } else {
          locationText = 'كل الأردن';
        }

        return GestureDetector(
          onTap: () {
            _showLocationBottomSheet(brandColor);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(color: brandColor.withOpacity(0.08), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 4)),
              ],
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [brandColor, Color.lerp(brandColor, Colors.black, 0.2)!]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: brandColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('الموقع الحالي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.2)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              locationText, 
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_locationsFilter != null || _selectedTags.isNotEmpty || _minPrice != null || _maxPrice != null || _sortBy != 'newest' || _isHot != null)
                  InkWell(
                    onTap: () async {
                      final appProvider = Provider.of<AppProvider>(context, listen: false);
                      await appProvider.setLocation(null, null, 'كل الأردن');
                      setState(() {
                        _selectedTags.clear();
                        _minPrice = null;
                        _maxPrice = null;
                        _sortBy = 'newest';
                        _isHot = null;
                        _locationsFilter = null;
                      });
                      _saveCurrentFilters();
                      _fetchAds();
                    }, 
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade600),
                    ),
                  )
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildHeroHeader(Color brandColor) {
    final String? catIconName = widget.category.iconName;

    return Container(
      width: double.infinity,
      // Minimal layered gradient
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [brandColor.withOpacity(0.06), Colors.white],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.category.name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5, color: Colors.black87),
                  ),
                ),
                if (_isLoadingAds)
                  ShimmerLoading(
                    child: Container(
                      width: 48,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                else
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      key: ValueKey(_totalAdsCount),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: brandColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: brandColor.withOpacity(0.2), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: brandColor.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.format_list_bulleted_rounded, size: 18, color: brandColor),
                          const SizedBox(width: 6),
                          Text(
                            '$_totalAdsCount إعلان',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: brandColor),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // _buildSmartSummaryBar(brandColor), // Removed as per request to not have two location pickers
          
          // Action Buttons Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionPill(icon: Icons.tune, label: 'فلترة', badgeCount: (_minPrice != null || _maxPrice != null) ? 1 : 0, brandColor: brandColor, onTap: () => _showFilterBottomSheet(brandColor))
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Consumer<AppProvider>(
                    builder: (context, provider, child) {
                      final locName = _locationsFilter != null && _locationsFilter!.isNotEmpty 
                        ? _locationsFilter!.join('، ') 
                        : provider.rawLocationFallback ?? provider.selectedCity?.nameAr ?? 'الأردن';
                      return _buildActionPill(
                        icon: Icons.location_on_outlined, 
                        label: locName, 
                        badgeCount: (_locationsFilter != null && _locationsFilter!.isNotEmpty) ? 1 : 0, 
                        brandColor: brandColor, 
                        onTap: () => _showLocationBottomSheet(brandColor)
                      );
                    }
                  ),
                ),
              ],
            ),
          ),

          // Smart Quick Actions (Horizontally Scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildQuickAction('🆕 جديد', _sortBy == 'newest', () {
                  setState(() {
                    _sortBy = 'newest';
                    _isHot = false;
                  });
                  _fetchAds();
                }),
                const SizedBox(width: 8),
                _buildQuickAction('🔥 الأكثر مشاهدة', _sortBy == 'most_viewed', () {
                  setState(() {
                    _sortBy = 'most_viewed';
                    _isHot = false;
                  });
                  _fetchAds();
                }),
                const SizedBox(width: 8),
                _buildQuickAction('💰 الأرخص', _sortBy == 'price_asc', () {
                  setState(() {
                    _sortBy = 'price_asc';
                    _isHot = false;
                  });
                  _fetchAds();
                }),
                const SizedBox(width: 8),
                _buildQuickAction('📍 الأقرب اليك', _sortBy == 'nearest', () {
                  _getCurrentLocation();
                }),
              ],
            ),
          ),
          
          const SizedBox(height: 4),
        ],
      ),
    );
  }
  
  Widget _buildQuickAction(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? Border.all(color: Colors.blue) : null,
        ),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? Colors.blue : Colors.black87)),
      ),
    );
  }

  Widget _buildActionPill({required IconData icon, required String label, int badgeCount = 0, required Color brandColor, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: badgeCount > 0 ? brandColor : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
            ]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.black87),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label, 
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (badgeCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: brandColor, shape: BoxShape.circle),
              child: Text(badgeCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            )
          ]
        ],
        ),
      ),
    );
  }

  Widget _buildListingQualityIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified, size: 12, color: Colors.green.shade700),
              ),
              const SizedBox(width: 6),
              Text('80% موثقة', style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w700)),
            ],
          ),
          Container(width: 1, height: 16, color: Colors.grey.shade200),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_fire_department, size: 12, color: Colors.orange.shade700),
              ),
              const SizedBox(width: 6),
              Text('طلب عالي', style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w700)),
            ],
          ),
          Container(width: 1, height: 16, color: Colors.grey.shade200),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.update, size: 12, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 6),
              Text('محدّث', style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color brandColor) {
    return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2)
            )
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'البحث في ${widget.category.name}...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.normal),
            prefixIcon: Icon(Icons.search, color: brandColor, size: 20),
            suffixIcon: _searchQuery.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _getIconForTag(String tag) {
    if (tag.contains('مصعد')) return '🛗';
    if (tag.contains('حارس')) return '👮';
    if (tag.contains('مفروش')) return '🛋️';
    if (tag.contains('غرف')) return '🛏️';
    if (tag.contains('مكيف')) return '❄️';
    if (tag.contains('تدفئة')) return '🔥';
    if (tag.contains('كراج') || tag.contains('سيارة')) return '🚗';
    if (tag.contains('مسبح')) return '🏊';
    if (tag.contains('بلكونة') || tag.contains('تراس') || tag.contains('ترس')) return '🪴';
    if (tag.contains('جديد')) return '✨';
    if (tag.contains('عرسان')) return '💍';
    if (tag.contains('حديقة') || tag.contains('مشجر')) return '🌳';
    if (tag.contains('مستودع')) return '📦';
    if (tag.contains('كاميرات')) return '📹';
    if (tag.contains('مطبخ')) return '🍳';
    if (tag.contains('غسيل')) return '🧺';
    if (tag.contains('اطلالة') || tag.contains('بحرية')) return '🌊';
    if (tag.contains('استثمار') || tag.contains('تجاري')) return '📈';
    if (tag.contains('شارع') || tag.contains('شارعين')) return '🛣️';
    return '';
  }

  Widget _buildMinimalTags(Color brandColor) {
    if (_isLoadingAds && _availableTags.isEmpty && _selectedTags.isEmpty) {
      // Shimmer tag placeholders
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(color: Colors.white),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ShimmerLoading(
            child: Row(
              children: List.generate(6, (i) => Container(
                width: [60.0, 80.0, 70.0, 90.0, 65.0, 75.0][i],
                height: 36,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              )),
            ),
          ),
        ),
      );
    }
    final advancedFilters = _selectedTags.where((t) => t.contains(':')).toList();
    if (_minPrice != null) advancedFilters.add('internal_min_price:$_minPrice');
    if (_maxPrice != null) advancedFilters.add('internal_max_price:$_maxPrice');
    if (_locationsFilter != null && _locationsFilter!.isNotEmpty) {
      for (final loc in _locationsFilter!) {
        advancedFilters.add('internal_location:$loc');
      }
    }

    final normalSelectedTags = _selectedTags.where((t) => !t.contains(':')).toList();

    if (_ads.isEmpty && _availableTags.isEmpty && _searchQuery.isEmpty && advancedFilters.isEmpty) return const SizedBox.shrink();

    List<String> priorityTags = [];
    final catName = widget.category.name;
    if (catName.contains('أراضي') || catName.contains('اراضي')) {
      priorityTags = ['واصل خدمات', 'قوشان مستقل', 'على شارعين', 'أرض للاسثمار', 'من المالك مباشرة', 'أرض سكنية', 'أرض تجارية', 'جاهزة للبناء', 'داخل التنظيم', 'مفروزة', 'على شارع رئيسي', 'مطلة', 'أقساط'];
    } else if (catName.contains('تجاري')) {
      priorityTags = ['موقع حيوي', 'غرفة استقبال', 'بدون خلو', 'غرفتين مكتبيتين', 'مطبخ وحمام'];
    } else if (catName.contains('العقبة')) {
      priorityTags = ['اطلالة بحرية', 'كراج خاص', 'مصعد', 'من المالك مباشرة', 'يوجد حارس', if (catName.contains('ايجار') || catName.contains('إيجار')) 'شامل التأمين', 'مشجر', 'مسور', 'مطبخ راكب', 'غرفة غسيل', 'سوبر ديلوكس', 'كاميرات مراقبة', 'مسبح', 'مستودع', 'حديقة', 'بلكونة', 'غرفة خادمة', 'ترس', 'دبل جلاس', 'عرسان', 'مدخل مستقل', 'أباجورات'];
    } else {
      priorityTags = ['كراج خاص', 'مصعد', 'من المالك مباشرة', 'يوجد حارس', if (catName.contains('ايجار') || catName.contains('إيجار')) 'شامل التأمين', 'مشجر', 'مسور', 'مطبخ راكب', 'غرفة غسيل', 'سوبر ديلوكس', 'كاميرات مراقبة', 'مسبح', 'مستودع', 'حديقة', 'بلكونة', 'غرفة خادمة', 'ترس', 'دبل جلاس', 'عرسان', 'مدخل مستقل', 'أباجورات'];
    }

    final Set<String> finalTagsSet = {};
    for (var tag in priorityTags) {
      finalTagsSet.add(tag);
    }
    for (var tag in normalSelectedTags) {
      finalTagsSet.add(tag);
    }

    final combined = <String>{..._availableTags.where((t) => !t.contains(':'))};
    List<String> dynamicTags = combined.toList();
    
    // Filter out location names (Cities and Regions) from dynamic tags
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    if (appProvider.dbCities != null) {
      final Set<String> locNames = {};
      for (var c in appProvider.dbCities!) {
        locNames.add(c.nameAr.trim());
        for (var r in c.regions) locNames.add(r.nameAr.trim());
      }
      dynamicTags.removeWhere((t) => locNames.contains(t.trim()));
    }
    
    // Keep dynamic tags sorted by frequency as before
    dynamicTags.sort((a, b) {
      int indexA = _orderedTags.indexOf(a);
      int indexB = _orderedTags.indexOf(b);
      if (indexA == -1) indexA = 9999;
      if (indexB == -1) indexB = 9999;
      return indexA.compareTo(indexB);
    });

    for (var tag in dynamicTags) {
      finalTagsSet.add(tag);
    }

    List<String> validTags = finalTagsSet.toList();

    if (_searchQuery.isNotEmpty) {
      validTags = validTags.where((t) => t.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    Widget? tagsListWidget;

    if (validTags.isNotEmpty) {
      List<String> tags = ['الكل', ...validTags];

      List<Widget> row1 = [];

      for (int i = 0; i < tags.length; i++) {
        final tag = tags[i];
        final isSelected = tag == 'الكل' ? normalSelectedTags.isEmpty : normalSelectedTags.contains(tag);
        final widgetItem = Padding(
          padding: EdgeInsets.only(left: i < tags.length - 1 ? 8.0 : 0),
          child: _buildTagChip(tag, isSelected, brandColor),
        );
        row1.add(widgetItem);
      }

      tagsListWidget = Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(color: Colors.white),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: row1,
          ),
        ),
      );
    }

    Widget? activeFiltersWidget;
    if (advancedFilters.isNotEmpty) {
      activeFiltersWidget = Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text('عوامل التصفية النشطة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final savedSearch = SavedSearch(
                          id: '',
                          categoryId: widget.category.id,
                          categoryName: widget.category.name,
                          searchQuery: _searchQuery,
                          minPrice: _minPrice,
                          maxPrice: _maxPrice,
                          locations: _locationsFilter ?? [],
                          tags: _selectedTags,
                          alertType: 'instant',
                          createdAt: DateTime.now(),
                        );
                        
                        await Provider.of<SavedSearchProvider>(context, listen: false).saveSearch(savedSearch);
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم حفظ البحث للفئة ${widget.category.name}'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Theme.of(context).primaryColor,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bookmark_border, size: 14, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 4),
                            Text('حفظ البحث', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).primaryColor)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTags.removeWhere((t) => t.contains(':'));
                          _minPrice = null;
                          _maxPrice = null;
                          
                          // If we are clearing location filters, also clear the global preference
                          if (_locationsFilter != null && _locationsFilter!.isNotEmpty) {
                            final appProvider = Provider.of<AppProvider>(context, listen: false);
                            appProvider.setLocation(null, null, 'كل الأردن');
                          }
                          
                          _locationsFilter = null;
                          _searchQuery = '';
                          _ads.clear();
                          _skip = 0;
                          _hasMoreAds = true;
                          _isLoadingAds = true;
                        });
                        _saveCurrentFilters();
                        _fetchAds();
                      },
                      child: Text('مسح الكل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red.shade500)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: advancedFilters.map((filter) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (filter.startsWith('internal_min_price:')) {
                        _minPrice = null;
                      } else if (filter.startsWith('internal_max_price:')) {
                        _maxPrice = null;
                      } else if (filter.startsWith('internal_location:')) {
                        final loc = filter.substring(18);
                        _locationsFilter!.remove(loc);
                        if (_locationsFilter!.isEmpty) _locationsFilter = null;
                        
                        // Clear from AppProvider as well so it doesn't return
                        final appProvider = Provider.of<AppProvider>(context, listen: false);
                        if (appProvider.selectedCity?.nameAr == loc) {
                          appProvider.setLocation(null, null, 'كل الأردن');
                        } else if (appProvider.selectedRegions != null) {
                          final updatedRegions = appProvider.selectedRegions!.where((r) => r.nameAr != loc).toList();
                          appProvider.setLocation(appProvider.selectedCity, updatedRegions.isEmpty ? null : updatedRegions, appProvider.rawLocationFallback);
                        }
                      } else {
                        _selectedTags.remove(filter);
                      }
                      _ads.clear();
                      _skip = 0;
                      _hasMoreAds = true;
                      _isLoadingAds = true;
                    });
                    _saveCurrentFilters();
                    _fetchAds();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: brandColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: brandColor.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTagForDisplay(filter),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: brandColor),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.close_rounded, size: 16, color: brandColor.withOpacity(0.6)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    Widget? savedFiltersRestoreWidget;
    if (_savedCategoryFilters != null) {
      savedFiltersRestoreWidget = GestureDetector(
        onTap: () {
          setState(() {
            _minPrice = _savedCategoryFilters!['min_price']?.toDouble();
            _maxPrice = _savedCategoryFilters!['max_price']?.toDouble();
            if (_savedCategoryFilters!['tags'] != null) {
              _selectedTags = List<String>.from(_savedCategoryFilters!['tags']);
            }
            _savedCategoryFilters = null; // Hide the widget after applying
            _ads.clear();
            _skip = 0;
            _hasMoreAds = true;
            _isLoadingAds = true;
          });
          _fetchAds();
        },
        child: Container(
          width: double.infinity,
          color: brandColor.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 20, color: brandColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text('يوجد فلاتر استخدمتها مسبقاً', style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: brandColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('استعادة الفلاتر ♻️', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
              ),
            ],
          ),
        ),
      );
    }

    if (tagsListWidget == null && activeFiltersWidget == null && savedFiltersRestoreWidget == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (savedFiltersRestoreWidget != null) savedFiltersRestoreWidget,
        if (tagsListWidget != null) tagsListWidget,
        if (activeFiltersWidget != null) activeFiltersWidget,
      ],
    );
  }

  String _formatTagForDisplay(String tag) {
    if (tag.startsWith('internal_location:')) return tag.substring(18);
    if (tag.startsWith('internal_min_price:')) {
      final val = double.tryParse(tag.substring(19))?.toInt() ?? 0;
      return 'السعر من $val د.أ';
    }
    if (tag.startsWith('internal_max_price:')) {
      final val = double.tryParse(tag.substring(19))?.toInt() ?? 0;
      return 'السعر إلى $val د.أ';
    }
    if (tag.startsWith('bedrooms:')) {
      final val = tag.substring(9);
      return val == 'ستوديو' ? 'ستوديو' : '$val غرف نوم';
    }
    if (tag.startsWith('bathrooms:')) return '${tag.substring(10)} حمامات';
    if (tag.startsWith('floor:')) return 'طابق ${tag.substring(6)}';
    if (tag.startsWith('age:')) return 'عمر ${tag.substring(4)}';
    if (tag.startsWith('min_area:')) return 'مساحة أكبر من ${tag.substring(9)}';
    if (tag.startsWith('max_area:')) return 'مساحة أقل من ${tag.substring(9)}';
    
    // For any other tag that has an English prefix (e.g., zoning_classification:سكن أ), just show the value
    if (tag.contains(':') && RegExp(r'^[a-zA-Z_]+$').hasMatch(tag.split(':').first)) {
      return tag.split(':').skip(1).join(':').trim();
    }
    
    return tag;
  }

  Widget _buildTagChip(String tag, bool isSelected, Color brandColor) {
    final displayTag = _formatTagForDisplay(tag);
    final iconStr = tag == 'الكل' ? '' : _getIconForTag(displayTag);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (tag == 'الكل') {
            _selectedTags.clear();
          } else {
            if (isSelected) {
              _selectedTags.remove(tag);
            } else {
              _selectedTags.add(tag);
            }
          }
          _ads.clear();
          _skip = 0;
          _hasMoreAds = true;
          _isLoadingAds = true;
        });
        _saveCurrentFilters();
        _fetchAds();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? brandColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? brandColor : Colors.grey.shade300, width: 1.5),
          boxShadow: isSelected 
            ? [BoxShadow(color: brandColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
            : [const BoxShadow(color: Colors.transparent)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconStr.isNotEmpty) ...[
              Text(iconStr, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
            ],
            Text(
              displayTag,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (isSelected && tag != 'الكل') ...[
              const SizedBox(width: 6),
              const Icon(Icons.close, size: 14, color: Colors.white),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildRealEstateQuickFilters(Color brandColor) {
    final catName = widget.category.name;
    final isCommercial = catName.contains('محلات') || catName.contains('مكاتب') || catName.contains('تجاري') || catName.contains('مخازن') || catName.contains('عيادات') || catName.contains('معارض') || catName.contains('مستودع') || catName.contains('صناعي') || catName.contains('مبنى') || catName.contains('مباني') || catName.contains('مجمع');
    
    if (isCommercial) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterRow('الفرش', 'furnished', ['مفروشة', 'غير مفروشة'], brandColor),
          const SizedBox(height: 12),
          _buildFilterRow('عمر البناء', 'age', ['0 - 1 سنة', '1 - 5 سنوات', '5 - 10 سنوات', '10 - 19 سنة', '20+ سنة'], brandColor),
        ]
      );
    }

    if (!catName.contains('شقق') && !catName.contains('عقارات') && !catName.contains('فلل') && !catName.contains('استوديوهات') && !catName.contains('سكني')) {
       return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterRow('عدد الغرف', 'bedrooms', ['ستوديو', '1', '2', '3', '4', '5', '+6'], brandColor),
        const SizedBox(height: 12),
        _buildFilterRow('الفرش', 'furnished', ['مفروشة', 'غير مفروشة', 'مفروش جزئياً'], brandColor),
        const SizedBox(height: 12),
        _buildFilterRow('الطابق', 'floor', ['طابق التسوية', 'طابق شبه أرضي', 'الطابق الأرضي', '1', '2', '3', '4', '5', '6', '7'], brandColor),
      ]
    );
  }

  Widget _buildFilterRow(String title, String prefix, List<String> options, Color brandColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: options.map((opt) {
              final tag = '$prefix:$opt';
              final isSelected = _selectedTags.contains(tag);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTags.remove(tag);
                      } else {
                        // Remove previous selection of the same prefix for a cleaner toggle UX
                        _selectedTags.removeWhere((t) => t.startsWith('$prefix:')); 
                        _selectedTags.add(tag);
                      }
                      _ads.clear();
                      _skip = 0;
                      _hasMoreAds = true;
                      _isLoadingAds = true;
                    });
                    _saveCurrentFilters();
                    _fetchAds();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? brandColor.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? brandColor : Colors.grey.shade300, width: isSelected ? 1.5 : 1),
                    ),
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? brandColor : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSleekSubCategories(Color brandColor) {
    if (!_isSubcategoriesLoaded) {
      if (_hasError) return const SizedBox.shrink();
      // Shimmer subcategory pill placeholders
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 100,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ShimmerLoading(
                child: Wrap(
                  direction: Axis.vertical,
                  spacing: 8.0,
                  runSpacing: 10.0,
                  children: List.generate(8, (i) => Container(
                    width: [110.0, 130.0, 100.0, 120.0, 140.0, 95.0, 115.0, 125.0][i],
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                  )),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final allCats = Provider.of<AppProvider>(context).categories ?? widget.allCategories;
    if (allCats.isEmpty) return const SizedBox.shrink();

    final subCategories = allCats
        .where((c) => c.parentId == widget.category.id &&
                      (_searchQuery.isEmpty || c.name.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();
        
    // Sort subcategories by adsCount descending
    subCategories.sort((a, b) => b.adsCount.compareTo(a.adsCount));

    if (subCategories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 60, // Increased height for professional cards
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Added vertical padding for shadows
            child: Row(
              children: [

                // Other subcategories
                ...subCategories.map((sub) {
                final subColor = _getColor(sub.colorHex);

                return Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryDetailsPage(
                          category: sub,
                          allCategories: widget.allCategories,
                          parentBrandColor: brandColor,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14), // Card shape
                      border: Border.all(color: Colors.grey.shade200, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: subColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10), // Rounded square icon container
                          ),
                          child: (() {
                            final subImageUrl = ApiService.resolveIconUrl(sub.iconName);
                            if (subImageUrl != null) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: ApiService.buildIconImage(
                                  subImageUrl,
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.cover,
                                  fallback: EmojiCategoryIcon(
                                    iconName: sub.iconName,
                                    size: 18,
                                    color: subColor,
                                  ),
                                ),
                              );
                            }
                            return EmojiCategoryIcon(
                              iconName: sub.iconName,
                              size: 18,
                              color: subColor,
                            );
                          })(),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          sub.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.black87,
                            letterSpacing: -0.2,
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
              );
              }).toList(),
            ],
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildImageSleekCard(String imageUrl, String title) {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ApiService.networkImage(ApiService.resolveIconUrl(imageUrl) ?? imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity),
          ),
          // Gradient fade for text
          Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7)
                    ])),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 12,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.white,
                  height: 1.2),
              maxLines: 2,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMinimalMapBanner(Color brandColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          // Future: Navigate to Map View
        },
        child: Container(
          height: 140, // Expanded height for map showcase
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: brandColor.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 8)),
            ],
            image: const DecorationImage(
              image: CachedNetworkImageProvider(
                  'https://media.wired.com/photos/59269cd37034dc5f91bec0f1/master/pass/GoogleMapTA.jpg'), // Generic map texture 
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                  Colors.white70, BlendMode.screen), // Brighten it heavily
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Colors.white.withOpacity(0.95), // Solid right side for text
                  Colors.white.withOpacity(0.4),  // Transparent left side for map
                ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                           color: brandColor.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(12)
                        ),
                        child: Text('ميزة تفاعلية', style: TextStyle(color: brandColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      const Text('استكشاف الخريطة',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(
                          'اكتشف إعلانات ${widget.category.name} بالقرب منك بسهولة',
                          style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              height: 1.3)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Map Pins Animation Base
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: brandColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: brandColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: brandColor.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4)
                            )
                          ]
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanAdsList() {
    bool hasHighlightLoading = _isLoadingAds && widget.highlightedAd != null && _ads.isNotEmpty;

    if (_hasError) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 64.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wifi_off_rounded, size: 64, color: Colors.red.shade400),
              ),
              const SizedBox(height: 24),
              const Text(
                'تعذر الاتصال بالإنترنت',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                'يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _fetchAds,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getBrandColor(),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    }

    if (_isLoadingAds && !hasHighlightLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
            padding: EdgeInsets.only(top: 20),
            child: ShimmerRealEstateList(itemCount: 3)),
      );
    }

    var displayAds = _ads;

    if (displayAds.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 64.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 24),
              const Text(
                'لا توجد إعلانات مطابقة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                'لم نتمكن من العثور على نتائج تطابق بحثك بدقة. جرب استخدام كلمات عامة أو إزالة بعض الفلاتر.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 32),
              if (_selectedTags.isNotEmpty || _locationsFilter != null || _searchQuery.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedTags.clear();
                        _locationsFilter = null;
                        _searchQuery = '';
                        _searchController.clear();
                        _ads.clear();
                        _skip = 0;
                        _hasMoreAds = true;
                        _isLoadingAds = true;
                      });
                      _fetchAds();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getBrandColor(),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('مسح الفلاتر', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index < displayAds.length) {
              final ad = displayAds[index];
              return RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      PremiumRealEstateCard(
                        ad: ad,
                        searchQuery: _searchQuery,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdDetailsPage(ad: ad)
                            )
                          ).then((_) {
                            if (mounted) setState(() {});
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            int extraIndex = displayAds.length;
            
            if (hasHighlightLoading) {
              if (index == extraIndex) {
                 return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: ShimmerRealEstateList(itemCount: 2)
                 );
              }
              extraIndex++;
            }

            if (_isLoadingMore && !_isLoadingAds) {
              if (index == extraIndex) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(_getBrandColor()),
                      ),
                    ),
                  ),
                );
              }
            }

            return const SizedBox.shrink();
          },
          childCount: displayAds.length + (hasHighlightLoading ? 1 : 0) + (_isLoadingMore && !_isLoadingAds ? 1 : 0),
          addAutomaticKeepAlives: false, // Don't keep off-screen cards alive in memory
          addRepaintBoundaries: false, // We add our own RepaintBoundary
        ),
      ),
    );
  }

  Widget _buildRowAdCard(Ad ad) {
    bool hasImages = ad.images.isNotEmpty;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        // Removed border radius and shadow to make it a flat full-width block
        border: !hasImages ? Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1.5)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Image Section
          if (hasImages) ...[
            if (ad.images.length == 1)
              _buildSingleImageHero(ad)
            else
              _buildMultipleImagesHero(ad),
          ],

          // 2. Info Section
          Padding(
            padding: EdgeInsets.all(hasImages ? 16.0 : 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta (If no image, show badges here instead)
                if (!hasImages) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0075FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('مستكشف موثوق',
                                style: TextStyle(
                                    color: Color(0xFF0075FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900)),
                            SizedBox(width: 4),
                            Icon(Icons.verified, color: Color(0xFF0075FF), size: 14),
                          ],
                        ),
                      ),
                      if (ad.isHot)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.local_fire_department, color: Colors.redAccent, size: 14),
                              SizedBox(width: 4),
                              Text('مطلوب بكثرة', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11))
                            ],
                          ),
                        )
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Title
                Text(
                  ad.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    height: 1.3,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),

                // Price & Location Line
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${ad.price.toStringAsFixed(0)} دينار',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                        color: Color(0xFF0075FF),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.location_on, color: Colors.grey.shade400, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Builder(
                              builder: (context) {
                                final city = ad.attributes?['city']?.toString();
                                final region = ad.attributes?['region']?.toString();
                                String locationText;
                                if (city != null && city.isNotEmpty && region != null && region.isNotEmpty) {
                                  locationText = '$region، $city';
                                } else if (region != null && region.isNotEmpty) {
                                  locationText = region;
                                } else {
                                  locationText = ad.location;
                                }
                                return Text(
                                  locationText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Down Payment / Payment Method Badge
                Builder(
                  builder: (context) {
                    final paymentMethod = ad.attributes?['payment_method']?.toString() ?? '';
                    final double downPayment = (ad.attributes?['down_payment'] as num?)?.toDouble() ?? 0;
                    if (paymentMethod == 'أقساط' || paymentMethod == 'كاش أو أقساط') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Text(paymentMethod, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange.shade700)),
                            ),
                            if (downPayment > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0E6FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.purple.withOpacity(0.15)),
                                ),
                                child: Text('دفعة أولى: ${downPayment.toStringAsFixed(0)} دينار', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A2387))),
                              ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Date Line
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey.shade400, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      ad.createdAt != null 
                          ? _formatTimeAgo(ad.createdAt!) 
                          : 'حديثاً',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Beautiful bubble tags for ad properties
                Builder(
                  builder: (context) {
                    List<String> propertyDetails = [];
                    
                    // Add standard system tags if present (as fallback or addition)
                    if (ad.tags.isNotEmpty) {
                      propertyDetails.addAll(ad.tags.take(2)); // Show max 2 system tags so it doesn't crowd
                    }

                    // Extract detailed attributes if we have them
                    if (ad.sharedRoomDetails != null) {
                      final details = ad.sharedRoomDetails!;
                      if (details.rooms != null && details.rooms! > 0) {
                        propertyDetails.add('${details.rooms} غرفة');
                      }
                      if (details.bathrooms != null && details.bathrooms! > 0) {
                        propertyDetails.add('${details.bathrooms} حمام');
                      }
                      if (details.furnished != null && details.furnished!.isNotEmpty) {
                        if (details.furnished == 'مفروش' || details.furnished!.contains('Yes') || details.furnished == 'نعم') {
                          propertyDetails.add('مفروش');
                        } else if (details.furnished == 'غير مفروش' || details.furnished!.contains('No') || details.furnished == 'لا') {
                          propertyDetails.add('غير مفروش');
                        } else {
                          propertyDetails.add(details.furnished!);
                        }
                      }
                      if (details.rentIncludes.isNotEmpty) {
                        for(var bill in details.rentIncludes) {
                          if (bill.contains('كهرباء') || bill.contains('Electricity')) {
                             propertyDetails.add('شامل كهرباء');
                          } else if (bill.contains('ماء') || bill.contains('Water')) {
                             propertyDetails.add('شامل ماء');
                          } else if (bill.contains('انترنت') || bill.contains('Internet')) {
                             propertyDetails.add('شامل انترنت');
                          } else {
                             // Limit to 10 chars max for unknown bills to keep bubbles small
                             propertyDetails.add(bill.length > 15 ? bill.substring(0, 15) : bill);
                          }
                        }
                      }
                    }

                    // Remove duplicates
                    propertyDetails = propertyDetails.toSet().toList();

                    if (propertyDetails.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: propertyDetails.map((detailText) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F5FA), // Very light soft blue/grey
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.withOpacity(0.1)),
                              ),
                              child: Text(
                                detailText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0075FF), // Matched to brand/price color
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                ),

                // Subtitle / comma-separated tags
                if (ad.description != null && ad.description!.isNotEmpty)
                  Text(
                    ad.description!,
                    maxLines: hasImages ? 3 : 5, // Show more text if no image
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                // Action Buttons for All Ads
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                           final authProvider = Provider.of<AuthProvider>(context, listen: false);
                           final currentUserId = authProvider.userData?['sub']?.toString();
                           if (currentUserId == null) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')));
                             return;
                           }
                           Navigator.push(context, MaterialPageRoute(
                             builder: (_) => PremiumChatScreen(
                               adId: ad.id.toString(),
                               adTitle: ad.title,
                               adPrice: ad.price.toStringAsFixed(0),
                               adImageUrl: ad.images.isNotEmpty ? ad.images.first : '',
                               isSeller: false,
                               currentUserId: currentUserId,
                               currentUserName: authProvider.userData?['username'] ?? 'مستخدم',
                               otherUserId: ad.userId.toString(),
                             )
                           ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0075FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('تواصل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Icon(Icons.favorite_border, color: Colors.grey.shade600, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Icon(Icons.share_outlined, color: Colors.grey.shade600, size: 20),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return 'منذ $years سنة';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return 'منذ $months شهر';
    } else if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }

  Widget _buildSingleImageHero(Ad ad) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: ad.videoUrl != null
              ? PremiumVideoPlayer(videoUrl: ad.videoUrl!, thumbnailUrl: ad.images.isNotEmpty ? ad.images.first : null)
              : ApiService.networkImage(
                  ad.images.first,
                  fit: BoxFit.cover,
                  errorWidget: Container(color: Colors.grey.shade100, child: const Icon(Icons.image, color: Colors.grey, size: 60)),
                ),
        ),
        // Gradient Overlay
        Positioned.fill(
          child: IgnorePointer( // Add IgnorePointer so touches pass through to video controls
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                )
              ),
            ),
          ),
        ),
        _buildImageBadges(ad),
      ],
    );
  }

  Widget _buildMultipleImagesHero(Ad ad) {
    // Static Row layout — NO nested scrollable viewports = zero lag
    final images = ad.images.take(3).toList(); // Show max 3 images
    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            // First (main) image — takes more space
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ad.videoUrl != null
                          ? PremiumVideoPlayer(videoUrl: ad.videoUrl!, thumbnailUrl: images.isNotEmpty ? images[0] : null)
                          : ApiService.networkImage(
                              images[0],
                              fit: BoxFit.cover,
                              errorWidget: Container(color: Colors.grey.shade100, child: const Icon(Icons.image, color: Colors.grey, size: 40)),
                            ),
                      // Photo count badge
                      if (ad.images.length > 1)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${ad.images.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 4),
                                const Icon(Icons.image, color: Colors.white, size: 14),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Side column with remaining images stacked vertically
            if (images.length > 1)
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    for (int i = 1; i < images.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ApiService.networkImage(
                                  images[i],
                                  fit: BoxFit.cover,
                                  errorWidget: Container(color: Colors.grey.shade100, child: const Icon(Icons.image, color: Colors.grey, size: 30)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBadges(Ad ad, {bool multiple = false}) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
          top: multiple ? 8 : 12,
          right: multiple ? 8 : 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('موثوق', style: TextStyle(color: Color(0xFF0075FF), fontSize: 10, fontWeight: FontWeight.w900)),
                SizedBox(width: 4),
                Icon(Icons.verified, color: Color(0xFF0075FF), size: 12),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: multiple ? 8 : 12,
          left: multiple ? 8 : 12,
          child: Row(
            children: [
              if (!multiple && ad.images.length > 1)
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(10)),
                 child: Row(
                   children: [
                     const Icon(Icons.photo_library, color: Colors.white, size: 12),
                     const SizedBox(width: 4),
                     Text('${ad.images.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))
                   ],
                 ),
               ),
              if (ad.isHot)
                Container(
                  margin: EdgeInsets.only(left: (!multiple && ad.images.length > 1) ? 8 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('مطلوب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))
                    ],
                  ),
                )
            ],
          ),
        )
      ],
    ),
    );
  }
}


class MultipleImagesHero extends StatefulWidget {
  final Ad ad;

  const MultipleImagesHero({Key? key, required this.ad}) : super(key: key);

  @override
  _MultipleImagesHeroState createState() => _MultipleImagesHeroState();
}

class _MultipleImagesHeroState extends State<MultipleImagesHero> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280, // Increased height for better clarity
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.ad.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ApiService.networkImage(
                    widget.ad.images[index],
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.image,
                          color: Colors.grey, size: 60),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.4)
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Image Counter Pill - Only show on the first image!
          if (_currentIndex == 0)
            Positioned(
              bottom: 12,
              left: 12, // RTL Left
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo_library_outlined, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.ad.images.length}', // Showing the total number of photos
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }


}
