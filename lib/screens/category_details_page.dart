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
import '../widgets/premium_login_bottom_sheet.dart';
import '../services/analytics_engine.dart';

import '../features/chat/presentation/screens/premium_chat_screen.dart';
import '../features/chat/presentation/screens/premium_inbox_screen.dart';
import '../features/chat/data/repositories/firebase_chat_repository.dart';
import '../widgets/premium_login_bottom_sheet.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/premium_video_player.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../providers/notification_provider.dart';
import 'notifications_page.dart';
import '../providers/auth_provider.dart';
import '../providers/saved_search_provider.dart';
import '../models/saved_search.dart';
import 'ad_details_page.dart';
import '../widgets/premium_share_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'add_ad_images.dart';
import 'root_screen.dart';
import '../widgets/premium_real_estate_card.dart';
import '../widgets/emoji_category_icon.dart';
import '../widgets/inline_banner_ad.dart';
import '../widgets/premium_filter_bottom_sheet.dart';
import '../widgets/inline_banner_ad.dart';

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
  final String? originalSearchQuery;
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
    this.originalSearchQuery,
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

  
  Category _getRootCategory(Category current) {
    Category cat = current;
    while (cat.parentId != null) {
      final parent = widget.allCategories.firstWhere((c) => c.id == cat.parentId, orElse: () => cat);
      if (parent.id == cat.id) break; 
      cat = parent;
    }
    return cat;
  }

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
  String? _originalSearchQuery;
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

  void _shareCategory() {
    String baseUrl = 'https://share.sooq-com.com/category/${widget.category.id}';
    
    List<String> queryParams = [];
    if (_searchQuery.isNotEmpty) queryParams.add('query=${Uri.encodeComponent(_searchQuery)}');
    if (_minPrice != null) queryParams.add('minPrice=$_minPrice');
    if (_maxPrice != null) queryParams.add('maxPrice=$_maxPrice');
    if (_isHot == true) queryParams.add('isHot=true');
    if (_locationsFilter != null && _locationsFilter!.isNotEmpty) {
      queryParams.add('locations=${Uri.encodeComponent(_locationsFilter!.join(','))}');
    }
    if (_selectedTags.isNotEmpty) {
      queryParams.add('tags=${Uri.encodeComponent(_selectedTags.join(','))}');
    }

    String finalUrl = baseUrl;
    if (queryParams.isNotEmpty) {
      finalUrl += '?' + queryParams.join('&');
    }

    String shareTitle = 'Ø¥Ø¹Ù„Ø§Ù†Ø§Øª Ù‚Ø³Ù… ${widget.category.name}';
    
    List<String> previewImages = [];
    for (var ad in _ads) {
      if (ad.images.isNotEmpty) {
        previewImages.add(ad.images.first);
        if (previewImages.length >= 4) break;
      }
    }

    PremiumShareBottomSheet.showForLink(
      context, 
      title: shareTitle, 
      url: finalUrl,
      previewImages: previewImages.isNotEmpty ? previewImages : null,
    );
  }

  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: widget.category.name);
    _searchQuery = widget.initialSearchQuery ?? '';
    _originalSearchQuery = widget.originalSearchQuery ?? _searchQuery;
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
    } else if (appProvider.rawLocationFallback != null && appProvider.rawLocationFallback != 'ÙƒÙ„ Ø§Ù„Ø£Ø±Ø¯Ù†') {
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
          _saveCurrentSearch('batch_100');
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ÙŠØ±Ø¬Ù‰ ØªÙØ¹ÙŠÙ„ Ø®Ø¯Ù…Ø§Øª Ø§Ù„Ù…ÙˆÙ‚Ø¹')));
        if (mounted) setState(() => _isLoadingAds = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ØªÙ… Ø±ÙØ¶ ØµÙ„Ø§Ø­ÙŠØ© Ø§Ù„Ù…ÙˆÙ‚Ø¹')));
          if (mounted) setState(() => _isLoadingAds = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ØªÙ… Ø±ÙØ¶ ØµÙ„Ø§Ø­ÙŠØ© Ø§Ù„Ù…ÙˆÙ‚Ø¹ Ù†Ù‡Ø§Ø¦ÙŠØ§Ù‹ØŒ ÙŠØ±Ø¬Ù‰ ØªÙØ¹ÙŠÙ„Ù‡Ø§ Ù…Ù† Ø§Ù„Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª')));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø¬Ù„Ø¨ Ø§Ù„Ù…ÙˆÙ‚Ø¹')));
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

      final cleanedLocations = (_locationsFilter != null && (_locationsFilter!.contains('ÙƒÙ„ Ø§Ù„Ù…Ø¯Ù†') || _locationsFilter!.contains('ÙƒÙ„ Ø§Ù„Ø£Ø±Ø¯Ù†'))) ? null : _locationsFilter;

      // Recursively load the whole subtree (without blocking the ads fetching)
      // so we can surface only the "ended" (leaf) subcategories as chips.
      _loadLeafSubCategories(widget.category.id, cleanedLocations, thisGeneration, forceRefresh: true)
          .then((_) {
            if (mounted && thisGeneration == _fetchGeneration) {
              setState(() => _isSubcategoriesLoaded = true);
            }
          })
          .catchError((_) {
            if (mounted && thisGeneration == _fetchGeneration) {
              setState(() => _isSubcategoriesLoaded = true);
            }
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
          originalSearch: _originalSearchQuery?.isNotEmpty == true ? _originalSearchQuery : null,
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
          }
          currentTags.addAll(ad.tags);
        }
        
        if (_availableTags.isEmpty) {
          for (var ad in fetchedAds) {
            for (var tag in ad.tags) {
              _availableTags.add(tag);
            }
          }
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

  /// Recursively loads the entire subcategory subtree under [parentId] so the
  /// details page can display only the leaf ("ended") subcategories. Deeper
  /// levels are fetched lazily (only once); the direct parent is refreshed when
  /// [forceRefresh] is set so location-aware counts stay up to date.
  Future<void> _loadLeafSubCategories(int parentId, List<String>? locations, int generation, {bool forceRefresh = false}) async {
    if (!mounted || generation != _fetchGeneration) return;
    final provider = Provider.of<AppProvider>(context, listen: false);

    if (forceRefresh || !provider.fetchedParentIds.contains(parentId)) {
      await provider.loadSubCategories(parentId, locations: locations);
    }
    if (!mounted || generation != _fetchGeneration) return;

    final children = provider.categories?.where((c) => c.parentId == parentId).toList() ?? [];
    if (children.isEmpty) return;

    await Future.wait(
      children.map((c) => _loadLeafSubCategories(c.id, locations, generation)),
    );
  }

  /// Flattens the loaded subtree under [parentId] down to leaf categories only
  /// (categories that themselves have no subcategories). Parents that have
  /// subcategories are skipped and replaced by their leaf descendants.
  List<Category> _collectLeafSubCategories(List<Category> allCats, int parentId) {
    final result = <Category>[];
    for (final child in allCats.where((c) => c.parentId == parentId)) {
      final hasChildren = allCats.any((c) => c.parentId == child.id);
      if (hasChildren) {
        result.addAll(_collectLeafSubCategories(allCats, child.id));
      } else {
        result.add(child);
      }
    }
    return result;
  }

  Future<void> _loadMoreAds() async {
    if (!mounted) return;
    setState(() => _isLoadingMore = true);
    try {
      final cleanedLocations = (_locationsFilter != null && (_locationsFilter!.contains('ÙƒÙ„ Ø§Ù„Ù…Ø¯Ù†') || _locationsFilter!.contains('ÙƒÙ„ Ø§Ù„Ø£Ø±Ø¯Ù†'))) ? null : _locationsFilter;

      final fetchedAds = await _apiService.fetchAds(
        categoryId: widget.category.id, 
        tags: _selectedTags.isNotEmpty ? _selectedTags : null, 
        skip: _skip, 
        limit: _limit,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        originalSearch: _originalSearchQuery?.isNotEmpty == true ? _originalSearchQuery : null,
        sortBy: _sortBy,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        locations: cleanedLocations,
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
        if (_availableTags.isEmpty) {
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
            SliverFillRemaining(
              hasScrollBody: false,
              fillOverscroll: false,
              child: Builder(
                builder: (context) {
                  if (_isLoadingAds || _ads.isNotEmpty) return const SizedBox.shrink();
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InlineBannerAd(),
                    ],
                  );
                }
              ),
            ),
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
              _bottomNavItem(Icons.home_outlined, 'Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠØ©', false, brandColor, () {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RootScreen(initialIndex: 0)), (route) => false);
              }),
              _bottomNavItem(Icons.grid_view_rounded, 'Ø§Ù„Ø£Ù‚Ø³Ø§Ù…', true, brandColor, null),
              _bottomNavItem(Icons.article_outlined, 'Ø¥Ø¹Ù„Ø§Ù†Ø§ØªÙŠ', false, brandColor, () {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RootScreen(initialIndex: 2)), (route) => false);
              }),
              _bottomNavItem(Icons.person_outline_rounded, 'Ø­Ø³Ø§Ø¨ÙŠ', false, brandColor, () {
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
      onTap: () {
        final currentUserId = context.read<AuthProvider>().userData?['sub']?.toString();
        if (currentUserId == null || currentUserId.isEmpty) {
          PremiumLoginBottomSheet.show(
            context, 
            subtitle: 'ÙŠØ±Ø¬Ù‰ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ù„Ø¥Ø¶Ø§ÙØ© Ø¥Ø¹Ù„Ø§Ù† Ø¬Ø¯ÙŠØ¯',
            onLoginSuccess: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAdImagesPage()));
            },
          );
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAdImagesPage()));
      },
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
            Text('Ø£Ø¶Ù Ø¥Ø¹Ù„Ø§Ù†', style: TextStyle(
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
          Row(
            children: [
              Icon(Icons.home_outlined, size: 10, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(_getRootCategory(widget.category).name, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
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
            final currentUserId = authProvider.userData?['id']?.toString() ?? authProvider.userData?['sub']?.toString() ?? '';
            return IconButton(
              icon: const Icon(Icons.support_agent_rounded, color: Colors.black87, size: 24),
              onPressed: () {
                if (currentUserId.isEmpty) {
                  PremiumLoginBottomSheet.show(
                    context, 
                    subtitle: 'ÙŠØ±Ø¬Ù‰ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ù„Ù„ÙˆØµÙˆÙ„ Ù„Ø®Ø¯Ù…Ø© Ø§Ù„Ø¹Ù…Ù„Ø§Ø¡',
                    onLoginSuccess: () {},
                  );
                  return;
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumChatScreen(
                  adId: 'support',
                  adTitle: 'Ø®Ø¯Ù…Ø© Ø§Ù„Ø¹Ù…Ù„Ø§Ø¡',
                  adPrice: '',
                  adImageUrl: '',
                  currentUserId: currentUserId,
                  currentUserName: authProvider.userData?['full_name']?.toString() ?? authProvider.userData?['username']?.toString() ?? authProvider.userData?['name']?.toString() ?? 'Ù…Ø³ØªØ®Ø¯Ù…',
                  currentUserPhone: authProvider.userData?['phone_number']?.toString(),
                  otherUserId: 'admin',
                  otherUserName: 'ÙØ±ÙŠÙ‚ Ø§Ù„Ø¯Ø¹Ù…',
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
                        if (currentUserId.isEmpty) {
                          PremiumLoginBottomSheet.show(
                            context, 
                            subtitle: 'ÙŠØ±Ø¬Ù‰ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ù„ÙØªØ­ Ø§Ù„Ø±Ø³Ø§Ø¦Ù„',
                            onLoginSuccess: () {},
                          );
                          return;
                        }
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
        // Share Action
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.black87, size: 24),
          onPressed: _shareCategory,
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
      const SnackBar(content: Text('ØªÙ… Ø­ÙØ¸ Ø§Ù„Ø¨Ø­Ø« Ø¨Ù†Ø¬Ø§Ø­!', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.green),
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
                    child: Text('ØªØ±ØªÙŠØ¨ Ø­Ø³Ø¨', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Colors.black87)),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0, bottom: 8.0, right: 8.0),
                    child: Text('Ø§Ù„Ø³Ø¹Ø±', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black45)),
                  ),
                  _buildSortOption(ctx, 'price_asc', 'Ù…Ù† Ø§Ù„Ø£Ù‚Ù„ Ù„Ù„Ø£Ø¹Ù„Ù‰', Icons.arrow_upward_rounded, Colors.green),
                  const SizedBox(height: 4),
                  _buildSortOption(ctx, 'price_desc', 'Ù…Ù† Ø§Ù„Ø£Ø¹Ù„Ù‰ Ù„Ù„Ø£Ù‚Ù„', Icons.arrow_downward_rounded, Colors.green.shade800),

                  const Padding(
                    padding: EdgeInsets.only(top: 16.0, bottom: 8.0, right: 8.0),
                    child: Text('Ø§Ù„ÙˆÙ‚Øª', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black45)),
                  ),
                  _buildSortOption(ctx, 'newest', 'Ø§Ù„Ø£Ø­Ø¯Ø« Ø£ÙˆÙ„Ø§Ù‹', Icons.new_releases_rounded, Colors.blue),
                  const SizedBox(height: 4),
                  _buildSortOption(ctx, 'oldest', 'Ø§Ù„Ø£Ù‚Ø¯Ù… Ø£ÙˆÙ„Ø§Ù‹', Icons.history_rounded, Colors.blueGrey),

                  const Padding(
                    padding: EdgeInsets.only(top: 16.0, bottom: 8.0, right: 8.0),
                    child: Text('Ø§Ù„Ø±Ø§Ø¦Ø¬', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black45)),
                  ),
                  _buildSortOption(ctx, 'nearest', 'Ø§Ù„Ø£Ù‚Ø±Ø¨ Ø¥Ù„ÙŠÙƒ', Icons.location_on_rounded, Colors.red.shade400),
                  const SizedBox(height: 4),
                  _buildSortOption(ctx, 'most_viewed', 'Ø§Ù„Ø£ÙƒØ«Ø± Ù…Ø´Ø§Ù‡Ø¯Ø©', Icons.local_fire_department_rounded, Colors.deepOrange),
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
    // Only offer leaf ("ended") subcategories â€” never a category with children.
    final subCategories = _collectLeafSubCategories(allCats, widget.category.id);

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
             _saveCurrentSearch('batch_100');
           }
        }
      }
    });
  }
  String _normalizeArabic(String text) {
    return text
        .replaceAll('Ø£', 'Ø§')
        .replaceAll('Ø¥', 'Ø§')
        .replaceAll('Ø¢', 'Ø§')
        .replaceAll('Ø©', 'Ù‡')
        .replaceAll('Ù‰', 'ÙŠ');
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
              
            final allRegionsGlobally = searchQuery.isEmpty
                ? <Region>[]
                : dbCities.expand((c) => c.regions).where((r) => _normalizeArabic(r.nameAr).contains(normalizedSearch)).toList();
            
            final Map<String, int> globalRegionNameCounts = {};
            if (searchQuery.isNotEmpty) {
              for (var c in dbCities) {
                for (var r in c.regions) {
                  globalRegionNameCounts[r.nameAr] = (globalRegionNameCounts[r.nameAr] ?? 0) + 1;
                }
              }
            }
              
            final filteredRegions = selectedCityForFilter == null || searchQuery.isEmpty 
              ? selectedCityForFilter?.regions ?? []
              : selectedCityForFilter!.regions.where((r) => _normalizeArabic(r.nameAr).contains(normalizedSearch)).toList();

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              height: MediaQuery.of(context).size.height * 0.8 + (selectedRegionsForFilter.isNotEmpty ? 60 : 0),
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
                              selectedCityForFilter == null ? 'Ø§Ø®ØªØ± Ø§Ù„Ù…Ø¯ÙŠÙ†Ø©' : 'Ù…Ù†Ø§Ø·Ù‚ ${selectedCityForFilter!.nameAr}', 
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
                    child: Row(
                      children: [
                        Expanded(
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
                                hintText: selectedCityForFilter == null ? 'Ø§Ø¨Ø­Ø« Ø¹Ù† Ù…Ø¯ÙŠÙ†Ø©...' : 'Ø§Ø¨Ø­Ø« Ø¹Ù† Ù…Ù†Ø·Ù‚Ø©...',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15, fontWeight: FontWeight.normal),
                                prefixIcon: Icon(Icons.search_rounded, color: brandColor),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                              ),
                            )
                          ),
                        ),
                        if (searchQuery.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                searchController.clear();
                                searchQuery = '';
                              });
                            },
                            child: Text('Ù…Ø³Ø­', style: TextStyle(color: brandColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selectedRegionsForFilter.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: SingleChildScrollView(
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
                  ],
                  if (selectedCityForFilter == null) ...[
                    // Step 1: Cities
                    Expanded(
                      child: ListView.separated(
                        itemCount: (searchQuery.isEmpty ? 1 : 0) + filteredCities.length + allRegionsGlobally.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        itemBuilder: (context, index) {
                          if (searchQuery.isEmpty && index == 0) {
                            return Container(
                              color: Colors.white,
                              child: ListTile(
                                title: const Text('ÙƒÙ„ Ø§Ù„Ø£Ø±Ø¯Ù†', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                trailing: const Icon(Icons.chevron_left, size: 22, textDirection: TextDirection.ltr, color: Colors.grey),
                                onTap: () async {
                                  final appProvider = Provider.of<AppProvider>(context, listen: false);
                                  await appProvider.setLocation(null, null, 'ÙƒÙ„ Ø§Ù„Ø£Ø±Ø¯Ù†');
                                  setState(() { _locationsFilter = ['ÙƒÙ„ Ø§Ù„Ø£Ø±Ø¯Ù†']; });
                                  Navigator.pop(ctx);
                                  _fetchAds();
                                },
                              ),
                            );
                          }
                          
                          int adjustedIndex = searchQuery.isEmpty ? index - 1 : index;
                          if (adjustedIndex < filteredCities.length) {
                            final c = filteredCities[adjustedIndex];
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
                          } else {
                            final r = allRegionsGlobally[adjustedIndex - filteredCities.length];
                            final city = dbCities.firstWhere((c) => c.id == r.cityId);
                            final bool hasDuplicate = (globalRegionNameCounts[r.nameAr] ?? 0) > 1;
                            
                            return Container(
                              color: Colors.white,
                              child: CheckboxListTile(
                                title: Row(
                                  children: [
                                    Text(r.nameAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                    if (hasDuplicate) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey.shade300)
                                        ),
                                        child: Text(city.nameAr, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                                      ),
                                    ]
                                  ],
                                ),
                                value: selectedRegionsForFilter.any((reg) => reg.id == r.id),
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
                          }
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
                              child: CheckboxListTile(
                                title: Text('ÙƒÙ„ Ù…Ù†Ø§Ø·Ù‚ ${selectedCityForFilter!.nameAr}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                value: false,
                                activeColor: brandColor,
                                onChanged: (bool? value) async {
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
                  ],
                  // Always show apply button
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
                            setState(() { _locationsFilter = selectedCityForFilter != null ? [selectedCityForFilter!.nameAr] : null; });
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
                            await appProvider.setLocation(involvedCities.isNotEmpty ? involvedCities.first : selectedCityForFilter, selectedRegionsForFilter.toList(), null);
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
                        child: const Text('ØªØ·Ø¨ÙŠÙ‚', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),

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
        String locationText = 'Ø¬Ø§Ø±ÙŠ Ø§Ù„ØªØ­Ø¯ÙŠØ¯...';
        
        if (_locationsFilter != null && _locationsFilter!.isNotEmpty) {
          locationText = _locationsFilter!.join('ØŒ ');
        } else if (provider.rawLocationFallback != null) {
          locationText = provider.rawLocationFallback!;
        } else if (provider.selectedCity != null) {
          if (provider.selectedRegions != null && provider.selectedRegions!.isNotEmpty) {
            final regionNames = provider.selectedRegions!.map((r) => r.nameAr).join('ØŒ ');
            locationText = '$regionNamesØŒ ${provider.selectedCity!.nameAr}';
          } else {
            locationText = provider.selectedCity!.nameAr;
          }
        } else {
          locationText = 'ÙƒÙ„ Ø§Ù„Ø£Ø±Ø¯Ù†';
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
                      Text('Ø§Ù„Ù…ÙˆÙ‚Ø¹ Ø§Ù„Ø­Ø§Ù„ÙŠ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.2)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              locationText, 
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
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
                      await appProvider.setLocation(null, null, 'ÙƒÙ„ Ø§Ù„Ø£Ø±Ø¯Ù†');
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: -0.5, color: Colors.black87),
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
                            '$_totalAdsCount Ø¥Ø¹Ù„Ø§Ù†',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: brandColor),
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
                  child: _buildActionPill(icon: Icons.tune, label: 'ÙÙ„ØªØ±Ø©', badgeCount: (_minPrice != null || _maxPrice != null) ? 1 : 0, brandColor: brandColor, onTap: () => _showFilterBottomSheet(brandColor))
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Consumer<AppProvider>(
                    builder: (context, provider, child) {
                      final locName = _locationsFilter != null && _locationsFilter!.isNotEmpty 
                        ? _locationsFilter!.join('ØŒ ') 
                        : provider.rawLocationFallback ?? provider.selectedCity?.nameAr ?? 'Ø§Ù„Ø£Ø±Ø¯Ù†';
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
                _buildQuickAction('ðŸ†• Ø¬Ø¯ÙŠØ¯', _sortBy == 'newest', () {
                  setState(() {
                    _sortBy = 'newest';
                    _isHot = false;
                  });
                  _fetchAds();
                }),
                const SizedBox(width: 8),
                _buildQuickAction('ðŸ”¥ Ø§Ù„Ø£ÙƒØ«Ø± Ù…Ø´Ø§Ù‡Ø¯Ø©', _sortBy == 'most_viewed', () {
                  setState(() {
                    _sortBy = 'most_viewed';
                    _isHot = false;
                  });
                  _fetchAds();
                }),
                const SizedBox(width: 8),
                _buildQuickAction('ðŸ’° Ø§Ù„Ø£Ø±Ø®Øµ', _sortBy == 'price_asc', () {
                  setState(() {
                    _sortBy = 'price_asc';
                    _isHot = false;
                  });
                  _fetchAds();
                }),
                const SizedBox(width: 8),
                _buildQuickAction('ðŸ“ Ø§Ù„Ø£Ù‚Ø±Ø¨ Ø§Ù„ÙŠÙƒ', _sortBy == 'nearest', () {
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
              Text('80% Ù…ÙˆØ«Ù‚Ø©', style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w700)),
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
              Text('Ø·Ù„Ø¨ Ø¹Ø§Ù„ÙŠ', style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w700)),
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
              Text('Ù…Ø­Ø¯Ù‘Ø«', style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w700)),
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
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          onSubmitted: (value) async {
            setState(() {
              _searchQuery = value;
              _originalSearchQuery = value;
            });
            if (value.trim().isNotEmpty) {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              if (authProvider.isAuthenticated) {
                _apiService.saveRecentSearch(value.trim());
              } else {
                final prefs = await SharedPreferences.getInstance();
                List<String> recent = prefs.getStringList('recent_searches') ?? [];
                recent.remove(value.trim());
                recent.insert(0, value.trim());
                if (recent.length > 5) recent = recent.sublist(0, 5);
                await prefs.setStringList('recent_searches', recent);
              }
            }
            _fetchAds();
          },
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Ø§Ù„Ø¨Ø­Ø« ÙÙŠ ${widget.category.name}...',
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
    if (tag.contains('Ù…ØµØ¹Ø¯')) return 'ðŸ›—';
    if (tag.contains('Ø­Ø§Ø±Ø³')) return 'ðŸ‘®';
    if (tag.contains('Ù…ÙØ±ÙˆØ´')) return 'ðŸ›‹ï¸';
    if (tag.contains('ØºØ±Ù')) return 'ðŸ›ï¸';
    if (tag.contains('Ù…ÙƒÙŠÙ')) return 'â„ï¸';
    if (tag.contains('ØªØ¯ÙØ¦Ø©')) return 'ðŸ”¥';
    if (tag.contains('ÙƒØ±Ø§Ø¬') || tag.contains('Ø³ÙŠØ§Ø±Ø©')) return 'ðŸš—';
    if (tag.contains('Ù…Ø³Ø¨Ø­')) return 'ðŸŠ';
    if (tag.contains('Ø¨Ù„ÙƒÙˆÙ†Ø©') || tag.contains('ØªØ±Ø§Ø³') || tag.contains('ØªØ±Ø³')) return 'ðŸª´';
    if (tag.contains('Ø¬Ø¯ÙŠØ¯')) return 'âœ¨';
    if (tag.contains('Ø¹Ø±Ø³Ø§Ù†')) return 'ðŸ’';
    if (tag.contains('Ø­Ø¯ÙŠÙ‚Ø©') || tag.contains('Ù…Ø´Ø¬Ø±')) return 'ðŸŒ³';
    if (tag.contains('Ù…Ø³ØªÙˆØ¯Ø¹')) return 'ðŸ“¦';
    if (tag.contains('ÙƒØ§Ù…ÙŠØ±Ø§Øª')) return 'ðŸ“¹';
    if (tag.contains('Ù…Ø·Ø¨Ø®')) return 'ðŸ³';
    if (tag.contains('ØºØ³ÙŠÙ„')) return 'ðŸ§º';
    if (tag.contains('Ø§Ø·Ù„Ø§Ù„Ø©') || tag.contains('Ø¨Ø­Ø±ÙŠØ©')) return 'ðŸŒŠ';
    if (tag.contains('Ø§Ø³ØªØ«Ù…Ø§Ø±') || tag.contains('ØªØ¬Ø§Ø±ÙŠ')) return 'ðŸ“ˆ';
    if (tag.contains('Ø´Ø§Ø±Ø¹') || tag.contains('Ø´Ø§Ø±Ø¹ÙŠÙ†')) return 'ðŸ›£ï¸';
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
    final rootCat = _getRootCategory(widget.category);
    final isCar = rootCat.id == 1 || rootCat.name.contains('Ø³ÙŠØ§Ø±Ø§Øª');
    final isRealEstate = rootCat.id == 3 || rootCat.name.contains('Ø¹Ù‚Ø§Ø±Ø§Øª');

    if (isCar) {
      priorityTags = ['Ø£ÙˆØªÙˆÙ…Ø§ØªÙŠÙƒ', 'ÙØ­Øµ ÙƒØ§Ù…Ù„', 'ÙØªØ­Ø© Ø³Ù‚Ù', 'Ø¬Ù„Ø¯', 'ØªØ±Ø®ÙŠØµ Ø¬Ø¯ÙŠØ¯', 'Ø¨Ø¯ÙˆÙ† Ø­ÙˆØ§Ø¯Ø«', 'Ø¯Ù‡Ø§Ù† Ø§Ù„ÙˆÙƒØ§Ù„Ø©', 'Ø¨Ø§Ù†ÙˆØ±Ø§Ù…Ø§', 'Ø¨ØµÙ…Ø©', 'Ù…Ø«Ø¨Øª Ø³Ø±Ø¹Ø©', 'ÙƒØ§Ù…ÙŠØ±Ø§ Ø®Ù„ÙÙŠØ©', 'ØªØ¯ÙØ¦Ø© Ù…Ù‚Ø§Ø¹Ø¯', 'Ø´Ø§Ø´Ø© Ù„Ù…Ø³'];
    } else if (isRealEstate) {
      if (catName.contains('Ø£Ø±Ø§Ø¶ÙŠ') || catName.contains('Ø£Ø±Ø¶ ') || catName.endsWith(' Ø£Ø±Ø¶') || catName == 'Ø£Ø±Ø¶' || catName.contains('Ù…Ø²Ø±Ø¹Ø©')) {
        priorityTags = ['ÙˆØ§ØµÙ„ Ø®Ø¯Ù…Ø§Øª', 'Ù‚ÙˆØ´Ø§Ù† Ù…Ø³ØªÙ‚Ù„', 'Ø¹Ù„Ù‰ Ø´Ø§Ø±Ø¹ÙŠÙ†', 'Ø£Ø±Ø¶ Ù„Ù„Ø§Ø³ØªØ«Ù…Ø§Ø±', 'Ù…Ù† Ø§Ù„Ù…Ø§Ù„Ùƒ Ù…Ø¨Ø§Ø´Ø±Ø©', 'Ø£Ø±Ø¶ Ø³ÙƒÙ†ÙŠØ©', 'Ø£Ø±Ø¶ ØªØ¬Ø§Ø±ÙŠØ©', 'Ø¬Ø§Ù‡Ø²Ø© Ù„Ù„Ø¨Ù†Ø§Ø¡', 'Ø¯Ø§Ø®Ù„ Ø§Ù„ØªÙ†Ø¸ÙŠÙ…', 'Ù…ÙØ±ÙˆØ²Ø©', 'Ø¹Ù„Ù‰ Ø´Ø§Ø±Ø¹ Ø±Ø¦ÙŠØ³ÙŠ', 'Ù…Ø·Ù„Ø©', 'Ø£Ù‚Ø³Ø§Ø·'];
      } else if (catName.contains('ØªØ¬Ø§Ø±ÙŠ')) {
        priorityTags = ['Ù…ÙˆÙ‚Ø¹ Ø­ÙŠÙˆÙŠ', 'ØºØ±ÙØ© Ø§Ø³ØªÙ‚Ø¨Ø§Ù„', 'Ø¨Ø¯ÙˆÙ† Ø®Ù„Ùˆ', 'ØºØ±ÙØªÙŠÙ† Ù…ÙƒØªØ¨ÙŠØªÙŠÙ†', 'Ù…Ø·Ø¨Ø® ÙˆØ­Ù…Ø§Ù…'];
      } else if (catName.contains('Ø§Ù„Ø¹Ù‚Ø¨Ø©')) {
        priorityTags = ['Ø§Ø·Ù„Ø§Ù„Ø© Ø¨Ø­Ø±ÙŠØ©', 'ÙƒØ±Ø§Ø¬ Ø®Ø§Øµ', 'Ù…ØµØ¹Ø¯', 'Ù…Ù† Ø§Ù„Ù…Ø§Ù„Ùƒ Ù…Ø¨Ø§Ø´Ø±Ø©', 'ÙŠÙˆØ¬Ø¯ Ø­Ø§Ø±Ø³', if (catName.contains('Ø§ÙŠØ¬Ø§Ø±') || catName.contains('Ø¥ÙŠØ¬Ø§Ø±')) 'Ø´Ø§Ù…Ù„ Ø§Ù„ØªØ£Ù…ÙŠÙ†', 'Ù…Ø´Ø¬Ø±', 'Ù…Ø³ÙˆØ±', 'Ù…Ø·Ø¨Ø® Ø±Ø§ÙƒØ¨', 'ØºØ±ÙØ© ØºØ³ÙŠÙ„', 'Ø³ÙˆØ¨Ø± Ø¯ÙŠÙ„ÙˆÙƒØ³', 'ÙƒØ§Ù…ÙŠØ±Ø§Øª Ù…Ø±Ø§Ù‚Ø¨Ø©', 'Ù…Ø³Ø¨Ø­', 'Ù…Ø³ØªÙˆØ¯Ø¹', 'Ø­Ø¯ÙŠÙ‚Ø©', 'Ø¨Ù„ÙƒÙˆÙ†Ø©', 'ØºØ±ÙØ© Ø®Ø§Ø¯Ù…Ø©', 'ØªØ±Ø³', 'Ø¯Ø¨Ù„ Ø¬Ù„Ø§Ø³', 'Ø¹Ø±Ø³Ø§Ù†', 'Ù…Ø¯Ø®Ù„ Ù…Ø³ØªÙ‚Ù„', 'Ø£Ø¨Ø§Ø¬ÙˆØ±Ø§Øª'];
      } else {
        priorityTags = ['ÙƒØ±Ø§Ø¬ Ø®Ø§Øµ', 'Ù…ØµØ¹Ø¯', 'Ù…Ù† Ø§Ù„Ù…Ø§Ù„Ùƒ Ù…Ø¨Ø§Ø´Ø±Ø©', 'ÙŠÙˆØ¬Ø¯ Ø­Ø§Ø±Ø³', if (catName.contains('Ø§ÙŠØ¬Ø§Ø±') || catName.contains('Ø¥ÙŠØ¬Ø§Ø±')) 'Ø´Ø§Ù…Ù„ Ø§Ù„ØªØ£Ù…ÙŠÙ†', 'Ù…Ø´Ø¬Ø±', 'Ù…Ø³ÙˆØ±', 'Ù…Ø·Ø¨Ø® Ø±Ø§ÙƒØ¨', 'ØºØ±ÙØ© ØºØ³ÙŠÙ„', 'Ø³ÙˆØ¨Ø± Ø¯ÙŠÙ„ÙˆÙƒØ³', 'ÙƒØ§Ù…ÙŠØ±Ø§Øª Ù…Ø±Ø§Ù‚Ø¨Ø©', 'Ù…Ø³Ø¨Ø­', 'Ù…Ø³ØªÙˆØ¯Ø¹', 'Ø­Ø¯ÙŠÙ‚Ø©', 'Ø¨Ù„ÙƒÙˆÙ†Ø©', 'ØºØ±ÙØ© Ø®Ø§Ø¯Ù…Ø©', 'ØªØ±Ø³', 'Ø¯Ø¨Ù„ Ø¬Ù„Ø§Ø³', 'Ø¹Ø±Ø³Ø§Ù†', 'Ù…Ø¯Ø®Ù„ Ù…Ø³ØªÙ‚Ù„', 'Ø£Ø¨Ø§Ø¬ÙˆØ±Ø§Øª'];
      }
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
      List<String> tags = ['Ø§Ù„ÙƒÙ„', ...validTags];

      List<Widget> row1 = [];

      for (int i = 0; i < tags.length; i++) {
        final tag = tags[i];
        final isSelected = tag == 'Ø§Ù„ÙƒÙ„' ? normalSelectedTags.isEmpty : normalSelectedTags.contains(tag);
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
                    Text('Ø¹ÙˆØ§Ù…Ù„ Ø§Ù„ØªØµÙÙŠØ© Ø§Ù„Ù†Ø´Ø·Ø©:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
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
                              content: Text('ØªÙ… Ø­ÙØ¸ Ø§Ù„Ø¨Ø­Ø« Ù„Ù„ÙØ¦Ø© ${widget.category.name}'),
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
                            Text('Ø­ÙØ¸ Ø§Ù„Ø¨Ø­Ø«', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).primaryColor)),
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
                            appProvider.setLocation(null, null, 'ÙƒÙ„ Ø§Ù„Ø£Ø±Ø¯Ù†');
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
                      child: Text('Ù…Ø³Ø­ Ø§Ù„ÙƒÙ„', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red.shade500)),
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
                          appProvider.setLocation(null, null, 'ÙƒÙ„ Ø§Ù„Ø£Ø±Ø¯Ù†');
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
                child: Text('ÙŠÙˆØ¬Ø¯ ÙÙ„Ø§ØªØ± Ø§Ø³ØªØ®Ø¯Ù…ØªÙ‡Ø§ Ù…Ø³Ø¨Ù‚Ø§Ù‹', style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: brandColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Ø§Ø³ØªØ¹Ø§Ø¯Ø© Ø§Ù„ÙÙ„Ø§ØªØ± â™»ï¸', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
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
      return 'Ø§Ù„Ø³Ø¹Ø± Ù…Ù† $val Ø¯.Ø£';
    }
    if (tag.startsWith('internal_max_price:')) {
      final val = double.tryParse(tag.substring(19))?.toInt() ?? 0;
      return 'Ø§Ù„Ø³Ø¹Ø± Ø¥Ù„Ù‰ $val Ø¯.Ø£';
    }
    if (tag.startsWith('bedrooms:')) {
      final val = tag.substring(9);
      return val == 'Ø³ØªÙˆØ¯ÙŠÙˆ' ? 'Ø³ØªÙˆØ¯ÙŠÙˆ' : '$val ØºØ±Ù Ù†ÙˆÙ…';
    }
    if (tag.startsWith('bathrooms:')) return '${tag.substring(10)} Ø­Ù…Ø§Ù…Ø§Øª';
    if (tag.startsWith('floor:')) {
      final f = tag.substring(6);
      if (f.contains('Ø·Ø§Ø¨Ù‚') || f.contains('Ø§Ù„Ø·Ø§Ø¨Ù‚') || f.contains('Ø£Ø±Ø¶ÙŠ') || f.contains('Ø±ÙˆÙ')) return f;
      return 'Ø·Ø§Ø¨Ù‚ $f';
    }
    if (tag.startsWith('age:')) return 'Ø¹Ù…Ø± ${tag.substring(4)}';
    if (tag.startsWith('min_area:')) return 'Ù…Ø³Ø§Ø­Ø© Ø£ÙƒØ¨Ø± Ù…Ù† ${tag.substring(9)}';
    if (tag.startsWith('max_area:')) return 'Ù…Ø³Ø§Ø­Ø© Ø£Ù‚Ù„ Ù…Ù† ${tag.substring(9)}';
    
    // For any other tag that has an English prefix (e.g., zoning_classification:Ø³ÙƒÙ† Ø£), just show the value
    if (tag.contains(':') && RegExp(r'^[a-zA-Z_]+$').hasMatch(tag.split(':').first)) {
      return tag.split(':').skip(1).join(':').trim();
    }
    
    return tag;
  }

  Widget _buildTagChip(String tag, bool isSelected, Color brandColor) {
    final displayTag = _formatTagForDisplay(tag);
    final iconStr = tag == 'Ø§Ù„ÙƒÙ„' ? '' : _getIconForTag(displayTag);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (tag == 'Ø§Ù„ÙƒÙ„') {
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
            if (isSelected && tag != 'Ø§Ù„ÙƒÙ„') ...[
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
    final isCommercial = catName.contains('Ù…Ø­Ù„Ø§Øª') || catName.contains('Ù…ÙƒØ§ØªØ¨') || catName.contains('ØªØ¬Ø§Ø±ÙŠ') || catName.contains('Ù…Ø®Ø§Ø²Ù†') || catName.contains('Ø¹ÙŠØ§Ø¯Ø§Øª') || catName.contains('Ù…Ø¹Ø§Ø±Ø¶') || catName.contains('Ù…Ø³ØªÙˆØ¯Ø¹') || catName.contains('ØµÙ†Ø§Ø¹ÙŠ') || catName.contains('Ù…Ø¨Ù†Ù‰') || catName.contains('Ù…Ø¨Ø§Ù†ÙŠ') || catName.contains('Ù…Ø¬Ù…Ø¹');
    
    if (isCommercial) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterRow('Ø§Ù„ÙØ±Ø´', 'furnished', ['Ù…ÙØ±ÙˆØ´Ø©', 'ØºÙŠØ± Ù…ÙØ±ÙˆØ´Ø©'], brandColor),
          const SizedBox(height: 12),
          _buildFilterRow('Ø¹Ù…Ø± Ø§Ù„Ø¨Ù†Ø§Ø¡', 'age', ['0 - 1 Ø³Ù†Ø©', '1 - 5 Ø³Ù†ÙˆØ§Øª', '5 - 10 Ø³Ù†ÙˆØ§Øª', '10 - 19 Ø³Ù†Ø©', '20+ Ø³Ù†Ø©'], brandColor),
        ]
      );
    }

    if (!catName.contains('Ø´Ù‚Ù‚') && !catName.contains('Ø¹Ù‚Ø§Ø±Ø§Øª') && !catName.contains('ÙÙ„Ù„') && !catName.contains('Ø§Ø³ØªÙˆØ¯ÙŠÙˆÙ‡Ø§Øª') && !catName.contains('Ø³ÙƒÙ†ÙŠ')) {
       return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterRow('Ø¹Ø¯Ø¯ Ø§Ù„ØºØ±Ù', 'bedrooms', ['Ø³ØªÙˆØ¯ÙŠÙˆ', '1', '2', '3', '4', '5', '+6'], brandColor),
        const SizedBox(height: 12),
        _buildFilterRow('Ø§Ù„ÙØ±Ø´', 'furnished', ['Ù…ÙØ±ÙˆØ´Ø©', 'ØºÙŠØ± Ù…ÙØ±ÙˆØ´Ø©', 'Ù…ÙØ±ÙˆØ´ Ø¬Ø²Ø¦ÙŠØ§Ù‹'], brandColor),
        const SizedBox(height: 12),
        _buildFilterRow('Ø§Ù„Ø·Ø§Ø¨Ù‚', 'floor', ['Ø·Ø§Ø¨Ù‚ Ø§Ù„ØªØ³ÙˆÙŠØ©', 'Ø·Ø§Ø¨Ù‚ Ø´Ø¨Ù‡ Ø£Ø±Ø¶ÙŠ', 'Ø§Ù„Ø·Ø§Ø¨Ù‚ Ø§Ù„Ø£Ø±Ø¶ÙŠ', '1', '2', '3', '4', '5', '6', '7', 'Ø·Ø§Ø¨Ù‚ Ø£Ø®ÙŠØ±', 'Ø±ÙˆÙ', 'Ø·Ø§Ø¨Ù‚ Ø£Ø®ÙŠØ± Ù…Ø¹ Ø±ÙˆÙ'], brandColor),
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

    // Only ever surface "ended" (leaf) subcategories here â€” never a category
    // that itself has subcategories. Parents are flattened to their leaves.
    final subCategories = _collectLeafSubCategories(allCats, widget.category.id)
        .where((c) => _searchQuery.isEmpty || c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
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
                                  fit: BoxFit.contain,
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
                        child: Text('Ù…ÙŠØ²Ø© ØªÙØ§Ø¹Ù„ÙŠØ©', style: TextStyle(color: brandColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      const Text('Ø§Ø³ØªÙƒØ´Ø§Ù Ø§Ù„Ø®Ø±ÙŠØ·Ø©',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(
                          'Ø§ÙƒØªØ´Ù Ø¥Ø¹Ù„Ø§Ù†Ø§Øª ${widget.category.name} Ø¨Ø§Ù„Ù‚Ø±Ø¨ Ù…Ù†Ùƒ Ø¨Ø³Ù‡ÙˆÙ„Ø©',
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
                'ØªØ¹Ø°Ø± Ø§Ù„Ø§ØªØµØ§Ù„ Ø¨Ø§Ù„Ø¥Ù†ØªØ±Ù†Øª',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                'ÙŠØ±Ø¬Ù‰ Ø§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§ØªØµØ§Ù„Ùƒ Ø¨Ø§Ù„Ø¥Ù†ØªØ±Ù†Øª ÙˆØ§Ù„Ù…Ø­Ø§ÙˆÙ„Ø© Ù…Ø±Ø© Ø£Ø®Ø±Ù‰.',
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
                  label: const Text('Ø¥Ø¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø©', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
      if (widget.category.id == 0) {
        final allCats = Provider.of<AppProvider>(context, listen: false).categories ?? widget.allCategories;
        Category? rentCat;
        Category? saleCat;
        try { rentCat = allCats.firstWhere((c) => c.id == 3); } catch(_) {}
        try { saleCat = allCats.firstWhere((c) => c.id == 103); } catch(_) {}
        
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.search_off_rounded, size: 64, color: Colors.blue.shade300),
                ),
                const SizedBox(height: 24),
                const Text('Ø¹Ø°Ø±Ø§Ù‹ØŒ Ù„Ù… Ù†Ø¹Ø«Ø± Ø¹Ù„Ù‰ Ù†ØªØ§Ø¦Ø¬ Ù…Ø·Ø§Ø¨Ù‚Ø© Ù„Ø¨Ø­Ø«Ùƒ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text('Ù„Ù…Ø³Ø§Ø¹Ø¯ØªÙƒ Ø¨Ø´ÙƒÙ„ Ø£ÙØ¶Ù„ØŒ ÙŠØ±Ø¬Ù‰ Ø§Ø®ØªÙŠØ§Ø± Ø£Ø­Ø¯ Ø§Ù„Ø£Ù‚Ø³Ø§Ù… Ø§Ù„ØªØ§Ù„ÙŠØ© ÙˆØªØµÙØ­ Ø§Ù„Ø£Ù‚Ø³Ø§Ù… Ø§Ù„ÙØ±Ø¹ÙŠØ©:', style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                if (rentCat != null)
                  _buildFallbackCategoryCard(rentCat, Icons.key_rounded, const Color(0xFF00BFA5)),
                if (rentCat != null) const SizedBox(height: 16),
                if (saleCat != null)
                  _buildFallbackCategoryCard(saleCat, Icons.home_work_rounded, const Color(0xFF1A73E8)),
              ],
            ),
          ),
        );
      }

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
                'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¥Ø¹Ù„Ø§Ù†Ø§Øª Ù…Ø·Ø§Ø¨Ù‚Ø©',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                'Ù„Ù… Ù†ØªÙ…ÙƒÙ† Ù…Ù† Ø§Ù„Ø¹Ø«ÙˆØ± Ø¹Ù„Ù‰ Ù†ØªØ§Ø¦Ø¬ ØªØ·Ø§Ø¨Ù‚ Ø¨Ø­Ø«Ùƒ Ø¨Ø¯Ù‚Ø©. Ø¬Ø±Ø¨ Ø§Ø³ØªØ®Ø¯Ø§Ù… ÙƒÙ„Ù…Ø§Øª Ø¹Ø§Ù…Ø© Ø£Ùˆ Ø¥Ø²Ø§Ù„Ø© Ø¨Ø¹Ø¶ Ø§Ù„ÙÙ„Ø§ØªØ±.',
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
                    child: const Text('Ù…Ø³Ø­ Ø§Ù„ÙÙ„Ø§ØªØ±', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
              final isAdSlot = (index > 0) && (index % 5 == 0);
              
              return RepaintBoundary(
                child: Column(
                  children: [
                    if (isAdSlot) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: InlineBannerAd(),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: PremiumRealEstateCard(
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
                    ),
                  ],
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
        border: ad.isFeatured || ad.cpcBid > 0 
            ? Border.all(color: const Color(0xFFD4AF37), width: 2.0)
            : (!hasImages ? Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1.5)) : null),
        borderRadius: ad.isFeatured || ad.cpcBid > 0 ? BorderRadius.circular(12) : null,
        boxShadow: ad.isFeatured || ad.cpcBid > 0 
            ? [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.2), blurRadius: 8, spreadRadius: 1)] 
            : null,
      ),
      margin: ad.isFeatured || ad.cpcBid > 0 ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8) : EdgeInsets.zero,
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
                            Text('Ù…Ø³ØªÙƒØ´Ù Ù…ÙˆØ«ÙˆÙ‚',
                                style: TextStyle(
                                    color: Color(0xFF0075FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
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
                              Text('Ù…Ø·Ù„ÙˆØ¨ Ø¨ÙƒØ«Ø±Ø©', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11))
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
                    fontWeight: FontWeight.bold,
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
                      '${ad.price.toStringAsFixed(0)} Ø¯ÙŠÙ†Ø§Ø±',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
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
                                  locationText = '$cityØŒ $region';
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
                    if (paymentMethod == 'Ø£Ù‚Ø³Ø§Ø·' || paymentMethod == 'ÙƒØ§Ø´ Ø£Ùˆ Ø£Ù‚Ø³Ø§Ø·') {
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
                                child: Text('Ø¯ÙØ¹Ø© Ø£ÙˆÙ„Ù‰: ${downPayment.toStringAsFixed(0)} Ø¯ÙŠÙ†Ø§Ø±', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A2387))),
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
                          : 'Ø­Ø¯ÙŠØ«Ø§Ù‹',
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
                        propertyDetails.add('${details.rooms} ØºØ±ÙØ©');
                      }
                      if (details.bathrooms != null && details.bathrooms! > 0) {
                        propertyDetails.add('${details.bathrooms} Ø­Ù…Ø§Ù…');
                      }
                      if (details.furnished != null && details.furnished!.isNotEmpty) {
                        if (details.furnished == 'Ù…ÙØ±ÙˆØ´' || details.furnished!.contains('Yes') || details.furnished == 'Ù†Ø¹Ù…') {
                          propertyDetails.add('Ù…ÙØ±ÙˆØ´');
                        } else if (details.furnished == 'ØºÙŠØ± Ù…ÙØ±ÙˆØ´' || details.furnished!.contains('No') || details.furnished == 'Ù„Ø§') {
                          propertyDetails.add('ØºÙŠØ± Ù…ÙØ±ÙˆØ´');
                        } else {
                          propertyDetails.add(details.furnished!);
                        }
                      }
                      if (details.rentIncludes.isNotEmpty) {
                        for(var bill in details.rentIncludes) {
                          if (bill.contains('ÙƒÙ‡Ø±Ø¨Ø§Ø¡') || bill.contains('Electricity')) {
                             propertyDetails.add('Ø´Ø§Ù…Ù„ ÙƒÙ‡Ø±Ø¨Ø§Ø¡');
                          } else if (bill.contains('Ù…Ø§Ø¡') || bill.contains('Water')) {
                             propertyDetails.add('Ø´Ø§Ù…Ù„ Ù…Ø§Ø¡');
                          } else if (bill.contains('Ø§Ù†ØªØ±Ù†Øª') || bill.contains('Internet')) {
                             propertyDetails.add('Ø´Ø§Ù…Ù„ Ø§Ù†ØªØ±Ù†Øª');
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
                           if (currentUserId == null || !authProvider.isAuthenticated) {
                             PremiumLoginBottomSheet.show(context,
                                 title: 'ÙŠØ±Ø¬Ù‰ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ø£ÙˆÙ„Ø§Ù‹',
                                 subtitle: 'ÙŠØ¬Ø¨ Ø£Ù† ØªØ³Ø¬Ù„ Ø¯Ø®ÙˆÙ„Ùƒ Ù„ØªØªÙ…ÙƒÙ† Ù…Ù† Ø§Ù„ØªÙˆØ§ØµÙ„ Ù…Ø¹ Ø§Ù„Ù…Ø¹Ù„Ù†',
                                 onLoginSuccess: () {
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumInboxScreen()));
                                 });
                             return;
                           }
                           if (currentUserId == ad.userId.toString()) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ù„Ø§ ÙŠÙ…ÙƒÙ†Ùƒ Ø¨Ø¯Ø¡ Ù…Ø­Ø§Ø¯Ø«Ø© Ù…Ø¹ Ù†ÙØ³Ùƒ')));
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
                               currentUserName: authProvider.userData?['full_name']?.toString() ?? authProvider.userData?['username']?.toString() ?? 'Ù…Ø³ØªØ®Ø¯Ù…',
                               otherUserId: ad.userId.toString(),
                               otherUserName: ad.ownerName,
                               otherUserPhone: ad.phoneNumber,
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
                              Text('ØªÙˆØ§ØµÙ„', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatefulBuilder(
                      builder: (context, setLocalState) {
                        return GestureDetector(
                          onTap: () async {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            if (!authProvider.isAuthenticated) {
                              PremiumLoginBottomSheet.show(context,
                                title: 'ÙŠØ±Ø¬Ù‰ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ø£ÙˆÙ„Ø§Ù‹',
                                subtitle: 'Ù‚Ù… Ø¨ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ù„Ø­ÙØ¸ Ø§Ù„Ø¥Ø¹Ù„Ø§Ù† ÙÙŠ Ø§Ù„Ù…ÙØ¶Ù„Ø© ÙˆØ§Ù„Ø±Ø¬ÙˆØ¹ Ø¥Ù„ÙŠÙ‡ Ù„Ø§Ø­Ù‚Ø§Ù‹',
                                onLoginSuccess: () {}
                              );
                              return;
                            }
                            final originalState = ad.isSaved;
                            setLocalState(() => ad.isSaved = !originalState);
                            try {
                              final isNowSaved = await ApiService().toggleSaveAd(ad.id);
                              if (isNowSaved != ad.isSaved) {
                                setLocalState(() => ad.isSaved = isNowSaved);
                              }
                            } catch (e) {
                              setLocalState(() => ad.isSaved = originalState);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø­ÙØ¸ Ø§Ù„Ø¥Ø¹Ù„Ø§Ù†')));
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ad.isSaved ? Colors.red.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ad.isSaved ? Colors.red.shade200 : Colors.grey.shade200),
                            ),
                            child: Icon(ad.isSaved ? Icons.favorite : Icons.favorite_border, color: ad.isSaved ? Colors.redAccent : Colors.grey.shade600, size: 20),
                          ),
                        );
                      }
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        PremiumShareBottomSheet.show(context, ad);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Icon(Icons.share_outlined, color: Colors.grey.shade600, size: 20),
                      ),
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

    if (difference.inDays > 0) {
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    } else if (difference.inHours > 0) {
      return 'Ù…Ù†Ø° ${difference.inHours} Ø³Ø§Ø¹Ø©';
    } else if (difference.inMinutes > 0) {
      return 'Ù…Ù†Ø° ${difference.inMinutes} Ø¯Ù‚ÙŠÙ‚Ø©';
    } else {
      return 'Ø§Ù„Ø¢Ù†';
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
    // Static Row layout â€” NO nested scrollable viewports = zero lag
    final images = ad.images.take(3).toList(); // Show max 3 images
    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            // First (main) image â€” takes more space
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
                Text('Ù…ÙˆØ«ÙˆÙ‚', style: TextStyle(color: Color(0xFF0075FF), fontSize: 10, fontWeight: FontWeight.bold)),
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
                      Text('Ù…Ø·Ù„ÙˆØ¨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))
                    ],
                  ),
                ),
              if (ad.isFeatured)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('Ù…Ù…ÙŠØ²', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))
                    ],
                  ),
                ),
              if (ad.marketPriceStatus != null && ad.marketPriceStatus != 'NO_DATA')
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ad.marketPriceStatus == 'BELOW_MARKET' ? Colors.green : ad.marketPriceStatus == 'ABOVE_MARKET' ? Colors.red : Colors.blue,
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: Text(
                    ad.marketPriceStatus == 'BELOW_MARKET' ? 'Ø³Ø¹Ø± Ø£Ù‚Ù„ Ù…Ù† Ø§Ù„Ø³ÙˆÙ‚' 
                    : ad.marketPriceStatus == 'ABOVE_MARKET' ? 'Ø£Ø¹Ù„Ù‰ Ù…Ù† Ø§Ù„Ù…ØªÙˆØ³Ø·' 
                    : 'Ø³Ø¹Ø± Ø¹Ø§Ø¯Ù„',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)
                  ),
                ),
              if (ad.cpcBid > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.campaign, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('Ù…Ù…ÙˆÙ„', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))
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
  Widget _buildFallbackCategoryCard(Category cat, IconData icon, Color brandColor) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryDetailsPage(
              category: cat,
              allCategories: Provider.of<AppProvider>(context, listen: false).categories ?? widget.allCategories,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: brandColor.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: brandColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: brandColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ØªØµÙØ­ Ø§Ù„Ø£Ù‚Ø³Ø§Ù… Ø§Ù„ÙØ±Ø¹ÙŠØ©',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: brandColor),
          ],
        ),
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
