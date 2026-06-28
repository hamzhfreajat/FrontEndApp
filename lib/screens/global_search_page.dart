import 'dart:async';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'category_details_page.dart';

import '../services/analytics_engine.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ApiService _apiService = ApiService();
  Timer? _debounce;

  bool _isLoading = false;
  bool _isInitLoading = true;

  List<Map<String, dynamic>> _trendingSearches = [];
  List<String> _recentSearches = [];
  
  static const List<Map<String, dynamic>> _quickCategories = [
    {'name': 'شقق للإيجار', 'icon': '🔑', 'parent': 'للايجار', 'fallbackId': 3},
    {'name': 'ستوديوهات للإيجار', 'icon': '🛋️', 'parent': 'للايجار', 'fallbackId': 3},
    {'name': 'بيوت مستقلة للإيجار', 'icon': '🏡', 'parent': 'للايجار', 'fallbackId': 3},
    {'name': 'شقق للبيع', 'icon': '🏢', 'parent': 'للبيع', 'fallbackId': 2},
    {'name': 'ستوديوهات للبيع', 'icon': '🛋️', 'parent': 'للبيع', 'fallbackId': 2},
    {'name': 'بيوت مستقلة للبيع', 'icon': '🏘️', 'parent': 'للبيع', 'fallbackId': 2},
    {'name': 'سكن مشترك', 'icon': '👥', 'parent': 'للايجار', 'fallbackId': 3},
    {'name': 'سكن طلاب (ذكور)', 'icon': '👨‍🎓', 'parent': 'للايجار', 'fallbackId': 3},
    {'name': 'سكن طالبات (إناث)', 'icon': '👩‍🎓', 'parent': 'للايجار', 'fallbackId': 3},
    {'name': 'سكن موظفين', 'icon': '👨‍💼', 'parent': 'للايجار', 'fallbackId': 3},
    {'name': 'سكن موظفات', 'icon': '👩‍💼', 'parent': 'للايجار', 'fallbackId': 3},
    {'name': 'مزرعة للإيجار', 'icon': '🌳', 'parent': 'للايجار', 'fallbackId': 3},
  ];

  List<Map<String, dynamic>> _searchGroups = [];
  Map<String, dynamic>? _searchIntent;
  List<Category> _topCategories = [];

  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: 'search');
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _apiService.getTrendingSearches(),
        _apiService.fetchCategories(parentId: 'null'),
      ]);
      final prefs = await SharedPreferences.getInstance();
      final recent = prefs.getStringList('recent_searches') ?? [];
      if (mounted) {
        setState(() {
          _trendingSearches = results[0] as List<Map<String, dynamic>>;
          _topCategories = results[1] as List<Category>;
          _recentSearches = recent;
          _isInitLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {});
  }

  void _navigateToAds(String keyword, {int? categoryId, String? section, bool isTag = false, String? rawTag}) async {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    String? cleanSearchQuery = keyword.isNotEmpty ? keyword : null;
    
    // Save to recent searches if there's a keyword
    if (keyword.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      List<String> recent = prefs.getStringList('recent_searches') ?? [];
      recent.remove(keyword);
      recent.insert(0, keyword);
      if (recent.length > 5) recent = recent.sublist(0, 5);
      await prefs.setStringList('recent_searches', recent);
      
      // Fetch intent via autocomplete API on submit instead of while typing
      setState(() => _isLoading = true);
      try {
        final results = await _apiService.searchAutocomplete(keyword);
        _searchIntent = results['intent'] as Map<String, dynamic>?;
        if (results['normalized_query'] != null) {
          cleanSearchQuery = (results['normalized_query'] as String).trim();
          if (cleanSearchQuery!.isEmpty) cleanSearchQuery = null;
        }
      } catch (_) {
        _searchIntent = null;
      }
      setState(() => _isLoading = false);
    }

    if (!mounted) return;
    
    // Note: The backend search API now relies on its own robust NLP QueryParserService 
    // to map raw queries to categories, tags, and locations. 
    // We pass the raw text query, but if autocomplete already parsed tags and locations,
    // we pass them so the UI reflects the selected filters!
    
    List<String>? intentTags;
    List<String>? intentLocs;
    if (_searchIntent != null) {
      if (_searchIntent!['tags'] != null) {
        intentTags = List<String>.from(_searchIntent!['tags']);
      }
      if (_searchIntent!['location'] != null) {
        intentLocs = [_searchIntent!['location']];
      }
      
      if (categoryId == null && _searchIntent!['category_id'] != null) {
        categoryId = _searchIntent!['category_id'] as int?;
        section = _searchIntent!['category_name'] as String?;
      }
    }

    if (categoryId != null) {
      Category targetCat;
      try {
        targetCat = _topCategories.firstWhere((c) => c.id == categoryId);
      } catch (_) {
        targetCat = Category(id: categoryId, name: section ?? '');
      }
      
      Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryDetailsPage(
        category: targetCat, 
        allCategories: _topCategories,
        initialSearchQuery: cleanSearchQuery,
        initialTags: intentTags,
        initialLocations: intentLocs,
      )));
    } else {
      final cat = Category(id: 0, name: keyword.isNotEmpty ? keyword : 'نتائج البحث', iconName: '🔍');
      if (isTag && rawTag != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryDetailsPage(category: cat, allCategories: _topCategories, initialTags: [rawTag])));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryDetailsPage(
          category: cat, 
          allCategories: _topCategories,
          initialSearchQuery: cleanSearchQuery,
          initialTags: intentTags,
          initialLocations: intentLocs,
        )));
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Back Button (Chevron)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                // Search Input
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5FC),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                _navigateToAds(val.trim());
                              }
                            },
                            onChanged: _onSearchChanged,
                            decoration: const InputDecoration(
                              hintText: 'بحث عن اي شيء...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (hasQuery)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Filter Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.tune_rounded, size: 24, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isInitLoading
          ? const Center(child: CircularProgressIndicator())
          : _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildInitialState(),
    );
  }

  Widget _buildInitialState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches section
          if (_recentSearches.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.history_rounded, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('آخر عمليات البحث', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _recentSearches.map((term) {
                return GestureDetector(
                  onTap: () {
                    _searchController.text = term;
                    _searchController.selection = TextSelection.collapsed(offset: term.length);
                    _navigateToAds(term);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(term, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],

          // Trending section
          if (_trendingSearches.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('الأكثر رواجا', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _trendingSearches.map((item) {
                final term = item['text'] as String;
                final rawValue = item['raw_value'] as String?;
                return GestureDetector(
                  onTap: () {
                    _searchController.text = term;
                    _searchController.selection = TextSelection.collapsed(offset: term.length);
                    _navigateToAds(term, isTag: true, rawTag: rawValue);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Text(term, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],

          // Categories section
          if (_quickCategories.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.dashboard_rounded, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('الأقسام', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: _quickCategories.length,
              itemBuilder: (context, index) {
                final item = _quickCategories[index];
                return GestureDetector(
                  onTap: () {
                    // Navigate to category
                    final cat = Category(id: item['fallbackId'], name: item['parent'], adsCount: 0);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryDetailsPage(category: cat, initialTags: [item['name']])));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A73E8).withOpacity(0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Text(item['icon'], style: const TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            item['name'],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF1E1E2C), fontWeight: FontWeight.bold, fontSize: 10, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

}
