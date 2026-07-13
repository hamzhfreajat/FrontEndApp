import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../services/search_intent_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'category_details_page.dart';
import 'categories_page.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/analytics_engine.dart';
import '../widgets/emoji_category_icon.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isInitLoading = true;

  List<Map<String, dynamic>> _trendingSearches = [];
  List<String> _recentSearches = [];
  List<Category> _saleCategories = [];
  List<Category> _rentCategories = [];

  List<Category> get _allDisplayedCategories =>
      [..._saleCategories, ..._rentCategories];

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: 'search');
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _apiService.getTrendingSearches(),
      ]);
      final prefs = await SharedPreferences.getInstance();
      final recent = prefs.getStringList('recent_searches') ?? [];

      if (mounted) {
        final provider = Provider.of<AppProvider>(context, listen: false);
        final saleCats = provider.categories
                ?.where((c) =>
                    (c.id == 2 || c.parentId == 2) &&
                    !c.name.contains('سكني'))
                .toList() ??
            [];
        final rentCats = provider.categories
                ?.where((c) =>
                    (c.id == 3 || c.parentId == 3) &&
                    !c.name.contains('سكني'))
                .toList() ??
            [];

        saleCats.sort((a, b) => b.adsCount.compareTo(a.adsCount));
        rentCats.sort((a, b) => b.adsCount.compareTo(a.adsCount));

        setState(() {
          _trendingSearches =
              List<Map<String, dynamic>>.from(results[0] as List);
          _saleCategories = saleCats.take(8).toList();
          _rentCategories = rentCats.take(8).toList();
          _recentSearches = recent;
          _isInitLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitLoading = false);
        _animController.forward();
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {});
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Core: parse query → navigate
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _navigateToAds(String keyword,
      {int? forceCategoryId, bool isTag = false, String? rawTag}) async {
    if (keyword.trim().isEmpty && forceCategoryId == null) return;

    // Hide keyboard
    FocusScope.of(context).unfocus();

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final cities = appProvider.dbCities;
    final prefs = await SharedPreferences.getInstance();

    List<String> recent = prefs.getStringList('recent_searches') ?? [];
    recent.remove(keyword);
    recent.insert(0, keyword);
    if (recent.length > 8) recent = recent.sublist(0, 8);
    await prefs.setStringList('recent_searches', recent);

    setState(() => _isLoading = true);

    // ── 1. Parse intent locally (instant) ─────────────────
    final intent = SearchIntentEngine.parse(keyword, cities: cities);

    setState(() => _isLoading = false);

    if (!mounted) return;

    // ── 2. Merge intent (using local only) ────────────────────────────────────
    final mergedIntent = _mergeIntents(
      local: intent,
      server: null, // Removed slow server fallback
      forceCategoryId: forceCategoryId,
      isTag: isTag,
      rawTag: rawTag,
      keyword: keyword,
    );

    // ── 3. Route ──────────────────────────────────────────────────────────
    final allCats = appProvider.categories ?? _allDisplayedCategories;

    if (mergedIntent.categoryId == null || mergedIntent.confidence < 0.45) {
      // Ambiguous — show disambiguation sheet
      _showCategorySelectionBottomSheet(
        keyword: keyword,
        intent: mergedIntent,
        isTag: isTag,
        rawTag: rawTag,
      );
      return;
    }

    _routeByIntent(mergedIntent, allCats, isTag: isTag, rawTag: rawTag);
  }

  // ── Merge local NLP + server response ────────────────────────────────────
  _MergedIntent _mergeIntents({
    required SearchIntent local,
    required Map<String, dynamic>? server,
    required int? forceCategoryId,
    required bool isTag,
    required String? rawTag,
    required String keyword,
  }) {
    // Server overrides local category only if server confidence is high
    int? catId = forceCategoryId ?? local.categoryId;
    String? catName = local.categoryName;
    String? location = local.location;
    List<String> tags = List<String>.from(local.tags);
    double confidence = local.confidence;

    if (server != null) {
      final serverCatId = server['category_id'] as int?;
      final serverLocation = server['location'] as String?;
      final serverTags =
          server['tags'] != null ? List<String>.from(server['tags']) : null;

      if (serverCatId != null && catId == null) {
        catId = serverCatId;
        catName = server['category_name'] as String?;
        confidence = (confidence + 0.3).clamp(0.0, 1.0);
      }
      if (serverLocation != null && location == null) {
        location = serverLocation;
      }
      if (serverTags != null) {
        for (final t in serverTags) {
          if (!tags.contains(t)) tags.add(t);
        }
      }
    }

    // If isTag is requested, prepend rawTag
    if (isTag && rawTag != null && !tags.contains(rawTag)) {
      tags.insert(0, rawTag);
    }

    return _MergedIntent(
      categoryId: catId,
      categoryName: catName,
      tags: tags,
      location: location,
      confidence: confidence,
      cleanQuery: local.cleanQuery,
    );
  }

  // ── Route to proper page based on merged intent ───────────────────────────
  void _routeByIntent(
    _MergedIntent intent,
    List<Category> allCats, {
    bool isTag = false,
    String? rawTag,
  }) {
    Category? targetCat;
    try {
      targetCat = allCats.firstWhere((c) => c.id == intent.categoryId);
    } catch (_) {
      targetCat =
          Category(id: intent.categoryId!, name: intent.categoryName ?? '');
    }

    final hasSubcategories = intent.categoryId == 2 ||
        intent.categoryId == 3 ||
        intent.categoryId == 10313 ||
        allCats.any((c) => c.parentId == intent.categoryId);

    List<String> currentTags = List<String>.from(intent.tags);

    // ── Leaf Category Promotion ──
    // If we have tags and subcategories, try to promote to the actual leaf category
    if (hasSubcategories && currentTags.isNotEmpty && targetCat != null) {
      String n(String s) => s
          .replaceAll('أ', 'ا')
          .replaceAll('إ', 'ا')
          .replaceAll('ة', 'ه')
          .replaceAll('ى', 'ي')
          .trim()
          .toLowerCase();

      final subCats = allCats.where((c) => c.parentId == targetCat!.id).toList();

      for (final tag in currentTags) {
        final nTag = n(tag);
        Category? matchedSubCat;

        // Map specific tags to known Soogcom subcategory names
        final bool isResidential = ['شقه', 'شقق', 'استوديو', 'فيلا', 'بيت', 'دور', 'روف', 'غرفه'].contains(nTag);
        final bool isCommercial = ['محل', 'تجاري', 'مستودع', 'مكتب', 'عياده', 'معرض'].contains(nTag);
        final bool isLand = nTag.contains('ارض') || nTag.contains('اراضي');
        final bool isFarm = nTag.contains('مزرع');
        final bool isChalet = nTag.contains('شاليه');

        for (final c in subCats) {
          final nName = n(c.name);
          
          if (isResidential && nName.contains('سكن')) {
            matchedSubCat = c;
            break;
          } else if (isCommercial && nName.contains('تجار')) {
            matchedSubCat = c;
            break;
          } else if (isLand && nName.contains('اراض')) {
            matchedSubCat = c;
            break;
          } else if (isFarm && nName.contains('مزارع')) {
            matchedSubCat = c;
            break;
          } else if (isChalet && nName.contains('شاليه')) {
            matchedSubCat = c;
            break;
          } else if (nName == nTag || nName.contains(nTag)) {
            matchedSubCat = c;
            break;
          }
        }

        if (matchedSubCat != null) {
          targetCat = matchedSubCat;
          // We DO NOT remove the tag here, because we want CategoryDetailsPage 
          // to use it as a pre-applied filter (e.g., category: "سكني", filter: "شقة").
          break; // Stop after promoting the first matching tag
        }
      }
    }

    final finalTags = currentTags.isEmpty ? null : currentTags;
    final locs = intent.location != null ? [intent.location!] : null;

    final isGenericCategorySearch = finalTags == null &&
        intent.location == null &&
        (intent.cleanQuery == null || intent.cleanQuery!.isEmpty);

    if (hasSubcategories && isGenericCategorySearch) {
      // Navigate to subcategory picker but with pre-filters
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoriesPage(
            parentId: targetCat!.id,
            allCategories: allCats,
            title: targetCat.name,
            category: targetCat,
            initialSearchQuery: intent.cleanQuery,
            initialTags: finalTags,
            initialLocations: locs,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryDetailsPage(
            category: targetCat!,
            allCategories: allCats,
            initialSearchQuery: intent.cleanQuery,
            initialTags: finalTags,
            initialLocations: locs,
          ),
        ),
      );
    }
  }

  // ── Disambiguation bottom sheet ────────────────────────────────────────────
  void _showCategorySelectionBottomSheet({
    required String keyword,
    required _MergedIntent intent,
    bool isTag = false,
    String? rawTag,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        final allCats = appProvider.categories ?? _allDisplayedCategories;

        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Icon(Icons.manage_search_rounded,
                  size: 52, color: Color(0xFF0075FF)),
              const SizedBox(height: 16),
              const Text(
                'حدد القسم المطلوب',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Tajawal'),
              ),
              const SizedBox(height: 6),
              Text(
                'لم نتمكن من تحديد نوع العقار تلقائياً، يرجى الاختيار',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _buildCategoryOption(
                      title: 'عقارات للبيع',
                      icon: '🏠',
                      color: const Color(0xFF0075FF),
                      onTap: () {
                        Navigator.pop(ctx);
                        final merged = _MergedIntent(
                          categoryId: 2,
                          categoryName: 'عقارات للبيع',
                          tags: intent.tags,
                          location: intent.location,
                          confidence: 1.0,
                          cleanQuery: intent.cleanQuery,
                        );
                        _routeByIntent(merged, allCats,
                            isTag: isTag, rawTag: rawTag);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCategoryOption(
                      title: 'عقارات للإيجار',
                      icon: '🔑',
                      color: const Color(0xFF00B0FF),
                      onTap: () {
                        Navigator.pop(ctx);
                        final merged = _MergedIntent(
                          categoryId: 3,
                          categoryName: 'عقارات للإيجار',
                          tags: intent.tags,
                          location: intent.location,
                          confidence: 1.0,
                          cleanQuery: intent.cleanQuery,
                        );
                        _routeByIntent(merged, allCats,
                            isTag: isTag, rawTag: rawTag);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCategoryOption(
                      title: 'أراضي',
                      icon: '🌍',
                      color: const Color(0xFF00C853),
                      onTap: () {
                        Navigator.pop(ctx);
                        final merged = _MergedIntent(
                          categoryId: 10313,
                          categoryName: 'أراضي',
                          tags: intent.tags,
                          location: intent.location,
                          confidence: 1.0,
                          cleanQuery: intent.cleanQuery,
                        );
                        _routeByIntent(merged, allCats,
                            isTag: isTag, rawTag: rawTag);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryOption({
    required String title,
    required String icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UI helpers
  // ══════════════════════════════════════════════════════════════════════════

  Color _getColor(String? hexString,
      {Color fallback = const Color(0xFF0075FF)}) {
    if (hexString == null || hexString.isEmpty) return fallback;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  String _getFallbackEmoji(String categoryName) {
    if (categoryName.contains('عقارات')) return '🏢';
    if (categoryName.contains('سيارات')) return '🚗';
    if (categoryName.contains('الكترونيات')) return '📱';
    if (categoryName.contains('وظائف')) return '💼';
    return '📁';
  }

  Widget _buildCategoryGrid(List<Category> categories) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final catColor = _getColor(cat.colorHex);

        return GestureDetector(
          onTap: () {
            final appProvider =
                Provider.of<AppProvider>(context, listen: false);
            final allCats =
                appProvider.categories ?? _allDisplayedCategories;
            final merged = _MergedIntent(
              categoryId: cat.id,
              categoryName: cat.name,
              tags: const [],
              location: null,
              confidence: 1.0,
              cleanQuery: null,
            );
            _routeByIntent(merged, allCats);
          },
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: EmojiCategoryIcon(
                    iconName: (cat.iconName != null &&
                            cat.iconName!.isNotEmpty)
                        ? cat.iconName
                        : _getFallbackEmoji(cat.name),
                    size: 26,
                    color: catColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cat.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF1E1E2C),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    height: 1.2),
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bool hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Stack(
        children: [
          // Background blob
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0075FF).withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildSearchHeader(hasQuery),
                Expanded(
                  child: _isInitLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : FadeTransition(
                              opacity: _fadeAnim,
                              child: _buildInitialState(),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(bool hasQuery) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 20, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 5)),
                ],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      const Icon(Icons.search_rounded,
                          color: Color(0xFF0075FF), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _navigateToAds(val.trim());
                            }
                          },
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: 'ابحث عن شقة، أرض، فيلا...',
                            hintStyle: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.normal),
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
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(Icons.cancel_rounded,
                                color: Colors.grey, size: 20),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick shortcut chips
          _buildQuickShortcuts(),
          const SizedBox(height: 28),

          if (_recentSearches.isNotEmpty) ...[
            _buildSectionHeader(
                'آخر عمليات البحث', Icons.history_rounded, Colors.grey),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _recentSearches.map((term) {
                return GestureDetector(
                  onTap: () {
                    _searchController.text = term;
                    _searchController.selection =
                        TextSelection.collapsed(offset: term.length);
                    _navigateToAds(term);
                  },
                  child: _buildChip(
                    label: term,
                    icon: Icons.history_rounded,
                    color: Colors.grey.shade700,
                    bgColor: Colors.grey.shade50,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],

          if (_trendingSearches.isNotEmpty) ...[
            _buildSectionHeader(
                'الأكثر بحثاً', Icons.local_fire_department_rounded, Colors.orange),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _trendingSearches.map((item) {
                final term = item['text'] as String;
                final rawValue = item['raw_value'] as String?;
                return GestureDetector(
                  onTap: () {
                    _searchController.text = term;
                    _searchController.selection =
                        TextSelection.collapsed(offset: term.length);
                    _navigateToAds(term, isTag: true, rawTag: rawValue);
                  },
                  child: _buildChip(
                    label: term,
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF0075FF),
                    bgColor: const Color(0xFF0075FF).withOpacity(0.06),
                    borderColor: const Color(0xFF0075FF).withOpacity(0.2),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],

          if (_saleCategories.isNotEmpty) ...[
            _buildSectionHeader(
                'عقارات للبيع', Icons.home_rounded, const Color(0xFF0075FF)),
            const SizedBox(height: 16),
            _buildCategoryGrid(_saleCategories),
            const SizedBox(height: 32),
          ],

          if (_rentCategories.isNotEmpty) ...[
            _buildSectionHeader(
                'عقارات للإيجار', Icons.vpn_key_rounded, const Color(0xFF00B0FF)),
            const SizedBox(height: 16),
            _buildCategoryGrid(_rentCategories),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: 'Tajawal',
              color: const Color(0xFF1E1E2C)),
        ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: borderColor ?? Colors.transparent, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickShortcuts() {
    final shortcuts = [
      _QuickShortcut(
          label: 'شقق للإيجار', emoji: '🏠', query: 'شقق للايجار', catId: 3),
      _QuickShortcut(
          label: 'شقق للبيع', emoji: '🏡', query: 'شقق للبيع', catId: 2),
      _QuickShortcut(
          label: 'أراضي للبيع',
          emoji: '🌍',
          query: 'اراضي للبيع',
          catId: 10313),
      _QuickShortcut(
          label: 'شقق مفروشة', emoji: '🛋️', query: 'شقق مفروشه للايجار', catId: 3),
      _QuickShortcut(
          label: 'فيلا للإيجار', emoji: '🏰', query: 'فيلا للايجار', catId: 3),
      _QuickShortcut(
          label: 'بيت للبيع', emoji: '🏘️', query: 'بيت للبيع', catId: 2),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = shortcuts[i];
          return GestureDetector(
            onTap: () {
              _searchController.text = s.query;
              _navigateToAds(s.query, forceCategoryId: s.catId);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0075FF), Color(0xFF00B4FF)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF0075FF).withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.emoji,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Private data classes ──────────────────────────────────────────────────

class _MergedIntent {
  final int? categoryId;
  final String? categoryName;
  final List<String> tags;
  final String? location;
  final double confidence;
  final String? cleanQuery;

  const _MergedIntent({
    this.categoryId,
    this.categoryName,
    this.tags = const [],
    this.location,
    this.confidence = 1.0,
    this.cleanQuery,
  });
}

class _QuickShortcut {
  final String label;
  final String emoji;
  final String query;
  final int catId;

  const _QuickShortcut({
    required this.label,
    required this.emoji,
    required this.query,
    required this.catId,
  });
}
