import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:classifieds_frontend/services/api_service.dart';
import 'package:classifieds_frontend/models/category.dart';
import 'package:classifieds_frontend/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'category_details_page.dart';

class SmartFinderWizard extends StatefulWidget {
  const SmartFinderWizard({super.key});

  @override
  _SmartFinderWizardState createState() => _SmartFinderWizardState();
}

class _SmartFinderWizardState extends State<SmartFinderWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Category selection
  Category? _selectedParentCategory; // e.g. "عقارات للإيجار"
  Category? _selectedSubCategory;    // e.g. "سكني"
  Category? _selectedLeafCategory;   // e.g. "شقق للإيجار" (the one sent to API)
  
  // Filters
  final TextEditingController _minPriceCtrl = TextEditingController();
  final TextEditingController _maxPriceCtrl = TextEditingController();
  final TextEditingController _minAreaCtrl = TextEditingController();
  final TextEditingController _maxAreaCtrl = TextEditingController();
  final TextEditingController _citySearchCtrl = TextEditingController();
  final TextEditingController _regionSearchCtrl = TextEditingController();
  List<String> _selectedRooms = [];
  List<String> _selectedBathrooms = [];
  List<String> _selectedFurnished = [];
  List<String> _selectedFloor = [];
  
  // Results
  bool _isLoadingCategories = false;
  bool _isLoadingAggregation = false;
  final Map<int, List<Category>> _fetchedSubcategories = {};
  List<Map<String, dynamic>> _aggregatedCities = [];
  String? _selectedCity;
  List<Map<String, dynamic>> _aggregatedRegions = [];
  
  List<Map<String, dynamic>> get _filteredCities {
    final query = _citySearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _aggregatedCities;
    return _aggregatedCities.where((c) => c['city'].toString().toLowerCase().contains(query)).toList();
  }

  List<Map<String, dynamic>> get _filteredRegions {
    final query = _regionSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _aggregatedRegions;
    return _aggregatedRegions.where((r) => r['region'].toString().toLowerCase().contains(query)).toList();
  }
  
  // Professional color theme for the wizard (Deep Blue)
  final Color _primaryWizardColor = const Color(0xFF1A73E8);

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _minAreaCtrl.dispose();
    _maxAreaCtrl.dispose();
    _citySearchCtrl.dispose();
    _regionSearchCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// The category used for API calls — uses the most specific one selected
  Category? get _effectiveCategory => _selectedLeafCategory ?? _selectedSubCategory ?? _selectedParentCategory;

  bool get _isRent {
    final name = _selectedParentCategory?.name ?? '';
    return name.contains('ايجار') || name.contains('إيجار');
  }

  List<String> _buildTags() {
    List<String> tags = [];
    for (var r in _selectedRooms) tags.add('bedrooms:$r');
    for (var b in _selectedBathrooms) tags.add('bathrooms:$b');
    for (var f in _selectedFurnished) tags.add('furnished:$f');
    for (var fl in _selectedFloor) tags.add('floor:$fl');
    if (_minAreaCtrl.text.isNotEmpty) tags.add('min_area:${_minAreaCtrl.text}');
    if (_maxAreaCtrl.text.isNotEmpty) tags.add('max_area:${_maxAreaCtrl.text}');
    return tags;
  }

  void _goToPage(int page) {
    _pageController.animateToPage(page, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    setState(() => _currentStep = page);
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _goToPage(_currentStep - 1);
    }
  }

  Future<void> _fetchAggregatedCities() async {
    setState(() => _isLoadingAggregation = true);

    final tags = _buildTags();
    double? minP = double.tryParse(_minPriceCtrl.text);
    double? maxP = double.tryParse(_maxPriceCtrl.text);

    try {
      final data = await ApiService().fetchAdsAggregation(
        groupBy: 'location',
        categoryId: _effectiveCategory?.id,
        minPrice: minP,
        maxPrice: maxP,
        tags: tags.isNotEmpty ? tags : null,
      );

      final Map<String, int> cityCounts = {};
      for (final row in data) {
        final loc = (row['group'] as String? ?? '').trim();
        final count = row['count'] as int? ?? 0;
        if (loc.isEmpty) continue;
        final city = loc.split(',').first.trim();
        if (city.isEmpty) continue;
        cityCounts[city] = (cityCounts[city] ?? 0) + count;
      }

      final cities = cityCounts.entries
          .map((e) => {'city': e.key, 'count': e.value})
          .toList();
      cities.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      setState(() {
        _aggregatedCities = cities;
        _isLoadingAggregation = false;
      });
    } catch (e) {
      setState(() => _isLoadingAggregation = false);
    }
  }

  void _onCitySelected(String city, int totalCount) async {

    setState(() {
      _selectedCity = city;
      _isLoadingAggregation = true;
    });
    _goToPage(3);

    final tags = _buildTags();
    double? minP = double.tryParse(_minPriceCtrl.text);
    double? maxP = double.tryParse(_maxPriceCtrl.text);

    try {
      final data = await ApiService().fetchAdsAggregation(
        groupBy: 'location',
        categoryId: _effectiveCategory?.id,
        minPrice: minP,
        maxPrice: maxP,
        tags: tags.isNotEmpty ? tags : null,
        locations: [city],
      );

      final regions = data
          .where((row) {
            final loc = row['group'] as String? ?? '';
            return loc.startsWith(city) && loc.contains(',');
          })
          .map((row) => {'region': row['group'] as String, 'count': row['count'] as int})
          .toList();
      regions.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      setState(() {
        _aggregatedRegions = regions;
        _isLoadingAggregation = false;
      });
    } catch (e) {
      setState(() => _isLoadingAggregation = false);
    }
  }

  void _navigateToResults(List<String> locations) {
    final tags = _buildTags();
    double? minP = double.tryParse(_minPriceCtrl.text);
    double? maxP = double.tryParse(_maxPriceCtrl.text);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailsPage(
          category: _effectiveCategory!,
          initialTags: tags,
          initialLocations: locations,
          initialMinPrice: minP,
          initialMaxPrice: maxP,
        ),
      ),
    );
  }

  void _subscribeToFilter() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم الاشتراك بنجاح! سيتم إشعارك فور توفر إعلانات جديدة.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildCategorySelection(),
            _buildFilters(),
            _buildCitySelection(),
            _buildRegionSelection(),
          ],
        ),
      ),
    );
  }

  // ─── Gradient Header ──────────────────────────────────────────────────
  Widget _buildGradientHeader(String title, String? subtitle, {bool showBack = false, VoidCallback? onBackOverride}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryWizardColor.withValues(alpha: 0.1), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 10,
        bottom: 40,
        left: 24,
        right: 24,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack)
            Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onBackOverride ?? _prevStep,
                color: const Color(0xFF0F172A),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 0: Category Selection (with subcategory drill-down) ────────
  Widget _buildCategorySelection() {
    final allCategories = context.watch<AppProvider>().categories ?? [];

    // Determine what to show based on drill-down state
    List<Category> displayCategories;
    String headerTitle;
    String headerSubtitle;
    bool showBackBtn = false;
    VoidCallback? onBack;

    if (_selectedParentCategory == null) {
      // Step 0a: Show top-level real estate categories
      displayCategories = allCategories.where((c) =>
        c.parentId == null && (c.name.contains('عقارات للبيع') || c.name.contains('عقارات للايجار') || c.name.contains('عقارات للإيجار'))
      ).toList();
      headerTitle = 'ما الذي تبحث عنه؟';
      headerSubtitle = 'حدد نوع العقار للبدء بالبحث';
    } else if (_selectedSubCategory == null) {
      // Step 0b: Show subcategories of parent (سكني، تجاري، etc.)
      displayCategories = _fetchedSubcategories[_selectedParentCategory!.id] ?? [];
      headerTitle = _selectedParentCategory!.name;
      headerSubtitle = 'اختر القسم الفرعي';
      showBackBtn = true;
      onBack = () => setState(() => _selectedParentCategory = null);
    } else {
      // Step 0c: Show leaf categories (شقق للإيجار, فلل, etc.)
      displayCategories = _fetchedSubcategories[_selectedSubCategory!.id] ?? [];
      if (displayCategories.isEmpty) {
        // No deeper level — auto-advance
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _selectedLeafCategory = null;
          _goToPage(1);
        });
        return const SizedBox.shrink();
      }
      headerTitle = _selectedSubCategory!.name;
      headerSubtitle = 'اختر نوع العقار';
      showBackBtn = true;
      onBack = () => setState(() => _selectedSubCategory = null);
    }

    return Column(
      children: [
        _buildGradientHeader(headerTitle, headerSubtitle, showBack: showBackBtn, onBackOverride: onBack),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: allCategories.isEmpty || _isLoadingCategories
              ? const Center(child: CircularProgressIndicator())
              : displayCategories.isEmpty
                ? Center(child: Text('لا توجد أقسام فرعية', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)))
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: displayCategories.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final cat = displayCategories[index];
                      
                      IconData catIcon = Icons.home_work_outlined;
                      if (cat.name.contains('بيع')) catIcon = Icons.sell_outlined;
                      if (cat.name.contains('ايجار') || cat.name.contains('إيجار')) catIcon = Icons.key_outlined;
                      if (cat.name.contains('سكني')) catIcon = Icons.apartment_outlined;
                      if (cat.name.contains('تجاري')) catIcon = Icons.store_outlined;
                      if (cat.name.contains('مزارع')) catIcon = Icons.park_outlined;
                      if (cat.name.contains('أراضي')) catIcon = Icons.landscape_outlined;
                      if (cat.name.contains('شاليه') || cat.name.contains('منتجع')) catIcon = Icons.beach_access_outlined;
                      if (cat.name.contains('سكن مشترك')) catIcon = Icons.group_outlined;
                      if (cat.name.contains('شقق')) catIcon = Icons.apartment_outlined;
                      if (cat.name.contains('ستوديو')) catIcon = Icons.single_bed_outlined;
                      if (cat.name.contains('فلل') || cat.name.contains('بيوت مستقلة')) catIcon = Icons.villa_outlined;
                      if (cat.name.contains('محلات') || cat.name.contains('معارض')) catIcon = Icons.storefront_outlined;
                      if (cat.name.contains('مكاتب')) catIcon = Icons.business_outlined;
                      if (cat.name.contains('طابق كامل')) catIcon = Icons.layers_outlined;
                      if (cat.name.contains('غرفة')) catIcon = Icons.meeting_room_outlined;

                      final adsCount = cat.adsCount;

                      return InkWell(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          if (_selectedParentCategory == null) {
                            // Tapped a parent: fetch its subcategories
                            setState(() => _isLoadingCategories = true);
                            try {
                              if (!_fetchedSubcategories.containsKey(cat.id)) {
                                final subcats = await ApiService().fetchCategories(parentId: cat.id.toString());
                                _fetchedSubcategories[cat.id] = subcats.where((c) => !c.name.contains('بنتهاوس') && !c.name.contains('دوبليكس')).toList();
                              }
                            } catch (e) {}
                            setState(() {
                              _isLoadingCategories = false;
                              _selectedParentCategory = cat;
                            });
                          } else if (_selectedSubCategory == null) {
                            // Tapped a subcategory: fetch its leaf categories
                            setState(() => _isLoadingCategories = true);
                            try {
                              if (!_fetchedSubcategories.containsKey(cat.id)) {
                                final subcats = await ApiService().fetchCategories(parentId: cat.id.toString());
                                _fetchedSubcategories[cat.id] = subcats.where((c) => !c.name.contains('بنتهاوس') && !c.name.contains('دوبليكس')).toList();
                              }
                            } catch (e) {}
                            
                            final leafCats = _fetchedSubcategories[cat.id] ?? [];
                            
                            setState(() {
                              _isLoadingCategories = false;
                              if (leafCats.isNotEmpty) {
                                _selectedSubCategory = cat;
                              } else {
                                // No deeper level, this IS the leaf
                                _selectedSubCategory = cat;
                                _selectedLeafCategory = null;
                                Future.delayed(const Duration(milliseconds: 200), () => _goToPage(1));
                              }
                            });
                          } else {
                            // Tapped a leaf category
                            setState(() => _selectedLeafCategory = cat);
                            Future.delayed(const Duration(milliseconds: 200), () => _goToPage(1));
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _primaryWizardColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(catIcon, size: 28, color: _primaryWizardColor),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat.name,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    if (adsCount > 0) ...[
                                      const SizedBox(height: 4),
                                      Text('$adsCount إعلان', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ─── Step 1: Filters ─────────────────────────────────────────────────
  Widget _buildFilters() {
    return Column(
      children: [
        _buildGradientHeader('المواصفات المطلوبة', _effectiveCategory?.name, showBack: true, onBackOverride: () {
          // Go back to category selection and reset drill-down
          setState(() {
            _selectedLeafCategory = null;
            _selectedSubCategory = null;
          });
          _goToPage(0);
        }),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 8),
              children: [
                _buildPriceFilter(),
                const SizedBox(height: 24),
                _buildAreaFilter(),
                const SizedBox(height: 24),
                _buildMultiSelectChips(
                  label: 'عدد الغرف',
                  values: _selectedRooms,
                  options: ['ستوديو', '1', '2', '3', '4', '5', '+6'],
                  onChanged: (vals) => setState(() => _selectedRooms = vals),
                  icon: Icons.bed_outlined,
                ),
                _buildMultiSelectChips(
                  label: 'الحمامات',
                  values: _selectedBathrooms,
                  options: ['1', '2', '3', '4', '5', '+6'],
                  onChanged: (vals) => setState(() => _selectedBathrooms = vals),
                  icon: Icons.bathtub_outlined,
                ),
                _buildMultiSelectChips(
                  label: 'الفرش',
                  values: _selectedFurnished,
                  options: ['مفروشة', 'غير مفروشة', 'مفروش جزئياً'],
                  onChanged: (vals) => setState(() => _selectedFurnished = vals),
                  icon: Icons.chair_outlined,
                ),
                _buildMultiSelectChips(
                  label: 'الطابق',
                  values: _selectedFloor,
                  options: ['طابق التسوية', 'طابق شبه أرضي', 'الطابق الأرضي', '1', '2', '3', '4', '5', '6', '7', 'طابق أخير', 'روف', 'طابق أخير مع روف'],
                  onChanged: (vals) => setState(() => _selectedFloor = vals),
                  icon: Icons.layers_outlined,
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryWizardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  _fetchAggregatedCities();
                  _goToPage(2);
                },
                child: const Text('البحث عن مناطق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Step 2: City Selection ───────────────────────────────────────────
  Widget _buildCitySelection() {
    return Column(
      children: [
        _buildGradientHeader('المدن المطابقة', null, showBack: true),
        if (_isLoadingAggregation)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_aggregatedCities.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]),
                      child: const Icon(Icons.search_off, size: 60, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    const Text('لا توجد إعلانات مطابقة حالياً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    const Text('جرب تغيير المواصفات أو اشترك ليصلك إشعار عند توفرها.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryWizardColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _subscribeToFilter,
                      icon: const Icon(Icons.notifications_active, color: Colors.white),
                      label: const Text('أعلمني عند توفرها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: TextField(
                    controller: _citySearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن مدينة...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredCities.isEmpty 
                    ? const Center(child: Text('لا توجد نتائج مطابقة لبحثك', style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          itemCount: _filteredCities.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final cityData = _filteredCities[index];
                  final count = cityData['count'];
                  return InkWell(
                    onTap: () => _onCitySelected(cityData['city'], count),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: _primaryWizardColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.location_city, color: _primaryWizardColor, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Text(cityData['city'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                child: Text('$count إعلان', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  ],
    );
  }

  // ─── Step 3: Region Selection ─────────────────────────────────────────
  Widget _buildRegionSelection() {
    return Column(
      children: [
        _buildGradientHeader('مناطق في ${_selectedCity ?? ""}', null, showBack: true),
        if (_isLoadingAggregation)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  TextField(
                    controller: _regionSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن منطقة...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _navigateToResults([_selectedCity!]),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _primaryWizardColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _primaryWizardColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.maps_home_work, color: _primaryWizardColor, size: 24),
                                const SizedBox(width: 16),
                                Flexible(child: Text('عرض جميع إعلانات $_selectedCity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryWizardColor))),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 16, color: _primaryWizardColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _filteredRegions.isEmpty
                        ? const Center(child: Text('لا توجد نتائج مطابقة لبحثك', style: TextStyle(color: Colors.grey, fontSize: 16)))
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filteredRegions.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final regionData = _filteredRegions[index];
                        final count = regionData['count'];
                        return InkWell(
                          onTap: () => _navigateToResults([regionData['region']]),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(regionData['region'].split(',').last.trim(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                      child: Text('$count إعلان', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ─── Shared UI Components ─────────────────────────────────────────────

  Widget _buildAreaFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.square_foot, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            const Text('المساحة (متر مربع)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(controller: _minAreaCtrl, hint: 'من', keyboardType: TextInputType.number)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0), child: Text('-', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            Expanded(child: _buildTextField(controller: _maxAreaCtrl, hint: 'إلى', keyboardType: TextInputType.number)),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_money, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            const Text('السعر (دينار)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(controller: _minPriceCtrl, hint: 'من', keyboardType: TextInputType.number)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0), child: Text('-', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            Expanded(child: _buildTextField(controller: _maxPriceCtrl, hint: 'إلى', keyboardType: TextInputType.number)),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryWizardColor, width: 2)),
      ),
    );
  }

  Widget _buildMultiSelectChips({
    required String label,
    required List<String> values,
    required List<String> options,
    required Function(List<String>) onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: options.map((opt) {
              final isSelected = values.contains(opt);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  final newValues = List<String>.from(values);
                  if (isSelected) {
                    newValues.remove(opt);
                  } else {
                    newValues.add(opt);
                  }
                  onChanged(newValues);
                },
                child: AnimatedContainer(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 64),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryWizardColor : Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isSelected ? _primaryWizardColor : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: _primaryWizardColor.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        opt,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


}
