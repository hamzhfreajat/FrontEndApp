import 'package:flutter/foundation.dart' hide Category;
import '../models/ad.dart';
import '../models/category.dart';
import '../models/metrics.dart';
import '../models/ticker.dart';
import '../models/story.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Cached data
  UserMetrics? metrics;
  List<LiveTicker>? tickers;
  List<Category>? categories;
  List<Story>? stories;

  List<Ad> recentlyViewedAds = [];
  List<City>? dbCities;

  List<Region>? selectedRegions;
  City? selectedCity;
  String? rawLocationFallback;

  /// Tracks which parentIds have had their children fetched from the server.
  final Set<int> fetchedParentIds = {};

  /// Returns true if children for [categoryId] have been fetched and none exist.
  bool isLeafCategory(int categoryId) {
    if (!fetchedParentIds.contains(categoryId)) return false;
    return categories?.any((c) => c.parentId == categoryId) != true;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Optimistically updates the global favorites counter
  Future<void> toggleFavoriteCount(bool isSaved) async {
    if (metrics == null) {
      try {
        metrics = await _apiService.fetchDashboardMetrics();
      } catch (e) {
        metrics = UserMetrics(
          savedItems: isSaved ? 1 : 0, 
          recentlyViewed: 0, 
          activeAds: 0
        );
      }
      notifyListeners();
      return;
    }

    final newCount = isSaved 
        ? metrics!.savedItems + 1 
        : (metrics!.savedItems > 0 ? metrics!.savedItems - 1 : 0);
    
    metrics = UserMetrics(
      savedItems: newCount,
      recentlyViewed: metrics!.recentlyViewed,
      activeAds: metrics!.activeAds,
    );
    notifyListeners();
  }

  void clearUserData() {
    metrics = null;
    recentlyViewedAds = [];
    notifyListeners();
  }

  Future<void> refreshAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Execute sequentially to prevent triggering Ngrok's 429 Too Many Requests rate limits
      // which causes random "Empty UI" scenarios and dropped connections
      metrics = await _apiService.fetchDashboardMetrics();
      tickers = await _apiService.fetchTicker();
      final rawCats = await _apiService.fetchCategories(parentId: 'null');
      fetchedParentIds.clear(); // Clear the fetch cache since we are overwriting the category tree
      categories = rawCats.where((c) => !c.name.contains('بنتهاوس') && !c.name.contains('دوبليكس')).toList();
      stories = await _apiService.fetchStories();
      await loadRecentlyViewed();
      
      // Load locations asynchronously in the background so it doesn't delay the Home Page
      _apiService.fetchLocations().then((locations) async {
        dbCities = locations;
        await initDefaultRegion();
      }).catchError((e) {
        if (kDebugMode) print("Error fetching locations in background: $e");
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching app cache data: \$e");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setLocation(City? city, List<Region>? regions, [String? fallback]) async {
    selectedCity = city;
    selectedRegions = regions;
    rawLocationFallback = fallback;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    if (city != null) {
      await prefs.setInt('saved_city_id', city.id);
    } else {
      await prefs.remove('saved_city_id');
    }

    if (regions != null && regions.isNotEmpty) {
      final regionIds = regions.map((r) => r.id).toList();
      await prefs.setString('saved_region_ids', jsonEncode(regionIds));
    } else {
      await prefs.remove('saved_region_ids');
      await prefs.remove('saved_region_id'); // clear old single region cache
    }

    if (fallback != null) {
      await prefs.setString('saved_raw_location_fallback', fallback);
    } else {
      await prefs.remove('saved_raw_location_fallback');
    }
  }

  Future<void> initDefaultRegion() async {
    if (dbCities == null || dbCities!.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final savedCityId = prefs.getInt('saved_city_id');
    final savedRegionIdsStr = prefs.getString('saved_region_ids');
    final savedOldRegionId = prefs.getInt('saved_region_id'); // backwards compatibility
    final savedFallback = prefs.getString('saved_raw_location_fallback');
    
    if (savedCityId != null) {
      try {
        selectedCity = dbCities!.firstWhere((c) => c.id == savedCityId);
        selectedRegions = [];
        if (savedRegionIdsStr != null) {
          final List<dynamic> decoded = jsonDecode(savedRegionIdsStr);
          for (var id in decoded) {
            try {
               selectedRegions!.add(selectedCity!.regions.firstWhere((r) => r.id == id));
            } catch (_) {}
          }
        } else if (savedOldRegionId != null) {
          try {
            selectedRegions!.add(selectedCity!.regions.firstWhere((r) => r.id == savedOldRegionId));
          } catch (_) {}
        }
        
        if (selectedRegions!.isEmpty) {
          selectedRegions = null;
        }
        rawLocationFallback = null;
      } catch (e) {
        selectedCity = null;
        selectedRegions = null;
        rawLocationFallback = 'كل الأردن';
      }
    } else if (savedFallback != null) {
      selectedCity = null;
      selectedRegions = null;
      rawLocationFallback = savedFallback;
    } else {
      // Default to 'All Jordan'
      selectedCity = null;
      selectedRegions = null;
      rawLocationFallback = 'كل الأردن';
    }
    
    notifyListeners();
  }

  Future<void> runGpsLocation() async {
    if (dbCities == null || dbCities!.isEmpty) return;
    
    // GPS Hook
    final sysLocation = await LocationService.getSystemLocationParts();
    if (sysLocation != null) {
      final match = LocationService.mapSystemToDBRegion(sysLocation, dbCities!);
      if (match != null) {
        selectedRegions = [match];
        selectedCity = dbCities!.firstWhere((c) => c.id == match.cityId);
        rawLocationFallback = null;
      } else {
        selectedRegions = null;
        selectedCity = null;
        final rawCity = sysLocation['city'] ?? '';
        final rawRegion = sysLocation['region'] ?? '';
        if (rawRegion.isNotEmpty && rawCity.isNotEmpty) {
          rawLocationFallback = '$rawRegion، $rawCity';
        } else if (rawCity.isNotEmpty) {
          rawLocationFallback = rawCity;
        } else if (rawRegion.isNotEmpty) {
          rawLocationFallback = rawRegion;
        }
      }
      notifyListeners();
    }
  }

  Future<void> loadRecentlyViewed() async {
    try {
      recentlyViewedAds = await _apiService.fetchRecentlyViewedAds();
    } catch (e) {
      if (kDebugMode) print("Error loading recently viewed: $e");
    }
  }

  Future<void> addToRecentlyViewed(Ad ad) async {
    // Optimistic local update
    recentlyViewedAds.removeWhere((e) => e.id == ad.id);
    recentlyViewedAds.insert(0, ad);
    if (recentlyViewedAds.length > 20) {
      recentlyViewedAds = recentlyViewedAds.sublist(0, 20);
    }
    notifyListeners();
    
    // Background async to server
    await _apiService.recordAdView(ad.id);
  }

  // Pre-load subcategories dynamically (lazy loading)
  Future<bool> loadSubCategories(int parentId, {List<String>? locations}) async {
    if (kDebugMode) {
      print('[AppProvider] loadSubCategories called for parentId=$parentId, categories null? ${categories == null}');
    }
    try {
      final rawChildren = await _apiService.fetchCategories(parentId: parentId.toString(), locations: locations);
      final children = rawChildren.where((c) => !c.name.contains('بنتهاوس') && !c.name.contains('دوبليكس')).toList();
      if (kDebugMode) {
        print('[AppProvider] Fetched ${children.length} children for parentId=$parentId');
      }
      if (categories != null) {
        final newIds = children.map((c) => c.id).toSet();
        categories!.removeWhere((c) => newIds.contains(c.id));
        categories!.addAll(children);
        if (kDebugMode) {
          print('[AppProvider] categories list now has ${categories!.length} items');
        }
        notifyListeners();
      } else {
        // categories was null — initialize it with the children
        categories = children;
        if (kDebugMode) {
          print('[AppProvider] categories was null, initialized with ${children.length} items');
        }
        notifyListeners();
      }
      fetchedParentIds.add(parentId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[AppProvider] ERROR fetching subcategories for $parentId: $e');
      }
      return false;
    }
  }
}
