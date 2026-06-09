import 'package:flutter/foundation.dart';
import '../models/saved_search.dart';
import '../services/api_service.dart';

class SavedSearchProvider with ChangeNotifier {
  List<SavedSearch> _savedSearches = [];
  bool _isLoading = false;

  List<SavedSearch> get savedSearches => _savedSearches;
  bool get isLoading => _isLoading;

  SavedSearchProvider() {
    refreshSearches();
  }

  Future<void> refreshSearches() async {
    _isLoading = true;
    notifyListeners();
    try {
      _savedSearches = await ApiService().fetchSavedSearches();
      _savedSearches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Error loading saved searches from backend: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSearch(SavedSearch search) async {
    try {
      // Create on backend
      final createdSearch = await ApiService().createSavedSearch(search);
      
      // Update local list (remove duplicates)
      _savedSearches.removeWhere((element) {
        return element.categoryId == search.categoryId &&
               element.searchQuery == search.searchQuery &&
               element.minPrice == search.minPrice &&
               element.maxPrice == search.maxPrice &&
               listEquals(element.locations, search.locations) &&
               listEquals(element.tags, search.tags);
      });
      
      _savedSearches.insert(0, createdSearch);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving search to backend: $e');
    }
  }

  Future<void> updateSearch(SavedSearch search) async {
    try {
      // Fallback to delete and create since there's no dedicated PUT endpoint yet
      await ApiService().deleteSavedSearch(search.id);
      await saveSearch(search);
    } catch (e) {
      debugPrint('Error updating search: $e');
    }
  }

  Future<void> deleteSearch(String id) async {
    try {
      await ApiService().deleteSavedSearch(id);
      _savedSearches.removeWhere((element) => element.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting search: $e');
    }
  }

  void clear() {
    _savedSearches.clear();
    notifyListeners();
  }
}
