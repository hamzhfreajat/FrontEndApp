import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../providers/app_provider.dart';
import '../models/location.dart';

class PremiumFilterData {
  final double? minPrice;
  final double? maxPrice;
  final List<String> tags;
  final Category? selectedSubCategory;
  final List<String>? locations;
  final bool saveSearchRequested;
  
  PremiumFilterData({
    this.minPrice,
    this.maxPrice,
    required this.tags,
    this.selectedSubCategory,
    this.locations,
    this.saveSearchRequested = false,
  });
}

class PremiumFilterBottomSheet extends StatefulWidget {
  final Category category;
  final List<Category> subCategories;
  final Color brandColor;
  final double? initialMinPrice;
  final double? initialMaxPrice;
  final List<String> initialTags;
  final int totalResultsCount;
  final String? searchQuery;
  final bool? isHot;
  final List<String>? initialLocations;

  const PremiumFilterBottomSheet({
    super.key,
    required this.category,
    required this.subCategories,
    required this.brandColor,
    this.initialMinPrice,
    this.initialMaxPrice,
    required this.initialTags,
    required this.totalResultsCount,
    this.searchQuery,
    this.isHot,
    this.initialLocations,
  });

  @override
  State<PremiumFilterBottomSheet> createState() => _PremiumFilterBottomSheetState();
}

class _PremiumFilterBottomSheetState extends State<PremiumFilterBottomSheet> {
  late double? _minPrice;
  late double? _maxPrice;
  late List<String> _selectedTags;
  final List<Category> _selectedCategoryPath = [];
  Category? get _selectedSubCategory => _selectedCategoryPath.isNotEmpty ? _selectedCategoryPath.last : null;

  // Real estate temp states
  Set<String> _selectedBedrooms = {};
  Set<String> _selectedBathrooms = {};
  Set<String> _selectedFurnished = {};
  Set<String> _selectedRentDuration = {};
  Set<String> _selectedFloor = {};
  Set<String> _selectedAge = {};
  List<String> _selectedFeatures = [];

  // Lands temp states
  Set<String> _selectedGeometricShape = {};
  Set<String> _selectedFacade = {};
  Set<String> _selectedLandType = {};
  Set<String> _selectedOwnershipType = {};
  Set<String> _selectedIsMortgaged = {};
  Set<String> _selectedZoningClassification = {};
  Set<String> _selectedTopography = {};
  Set<String> _selectedInstallmentPossible = {};
  Set<String> _selectedAvailableServices = {};
  Set<String> _selectedMainFeatures = {};
  Set<String> _selectedExtraFeatures = {};
  Set<String> _selectedNearby = {};

  // Deep Location Temp States
  int? _selectedGovernorateId;
  int? _selectedDirectorateId;
  int? _selectedVillageId;
  int? _selectedBasinId;
  int? _selectedCityId;
  Set<int> _selectedRegionIds = {};
  List<Map<String, dynamic>> _directorates = [];
  List<Map<String, dynamic>> _villages = [];
  List<Map<String, dynamic>> _basins = [];
  bool _isLoadingLoc = false;
  final Map<String, dynamic> _dynamicDataLoc = {}; // Stores names


  final TextEditingController _minAreaController = TextEditingController();
  final TextEditingController _maxAreaController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  int? _liveAdsCount;
  bool _isCounting = false;
  final ApiService _apiService = ApiService();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _liveAdsCount = widget.totalResultsCount;
    _minPrice = widget.initialMinPrice;
    _maxPrice = widget.initialMaxPrice;
    _selectedTags = List.from(widget.initialTags);
    
    if (_minPrice != null) _minPriceController.text = _minPrice!.toInt().toString();
    if (_maxPrice != null) _maxPriceController.text = _maxPrice!.toInt().toString();

    _minPriceController.addListener(_triggerCountUpdate);
    _maxPriceController.addListener(_triggerCountUpdate);

    // Try to extract known tags into UI segments
    _extractTagsToUIState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isRealEstate() && mounted) {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        if (appProvider.selectedCity != null) {
          setState(() {
            _selectedCityId = appProvider.selectedCity!.id;
            if (appProvider.selectedRegions != null) {
              _selectedRegionIds = appProvider.selectedRegions!.map((e) => e.id).toSet();
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _minPriceController.removeListener(_triggerCountUpdate);
    _maxPriceController.removeListener(_triggerCountUpdate);
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minAreaController.dispose();
    _maxAreaController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _triggerCountUpdate() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isCounting = true);
      _compileStateToTags();
      final locs = <String>[];
      for (var key in ['governorate', 'directorate', 'village', 'basin']) {
        if (_dynamicDataLoc[key] != null) locs.add(_dynamicDataLoc[key]);
      }
      
      if (_isLands()) {
        // Lands already added governorate, directorate, etc from _dynamicDataLoc above
        // Do not add the global city/region to avoid conflicting locations
      } else if (_isRealEstate() && mounted) {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        if (_selectedCityId != null) {
          final city = appProvider.dbCities?.firstWhere((c) => c.id == _selectedCityId, orElse: () => appProvider.dbCities!.first);
          if (city != null) {
            locs.add(city.nameAr);
            if (_selectedRegionIds.isNotEmpty) {
              locs.addAll(city.regions.where((r) => _selectedRegionIds.contains(r.id)).map((r) => r.nameAr));
            }
          }
        }
      } else {
        if (_dynamicDataLoc['city'] != null) {
          locs.add(_dynamicDataLoc['city']);
        }
        if (_dynamicDataLoc['regions'] != null && (_dynamicDataLoc['regions'] as List).isNotEmpty) {
          locs.addAll(List<String>.from(_dynamicDataLoc['regions']));
        }
        if (locs.isEmpty && widget.initialLocations != null) {
          locs.addAll(widget.initialLocations!);
        }
      }
      
      final finalLocs = locs.where((s) => s.isNotEmpty && s != 'كل الأردن' && s != 'الكل').toList();
      
      try {
        final count = await _apiService.fetchAdsCount(
          categoryId: _selectedSubCategory?.id ?? widget.category.id,
          tags: _selectedTags.isNotEmpty ? _selectedTags : null,
          minPrice: double.tryParse(_minPriceController.text),
          maxPrice: double.tryParse(_maxPriceController.text),
          locations: finalLocs.isNotEmpty ? finalLocs : null,
          search: widget.searchQuery?.isNotEmpty == true ? widget.searchQuery : null,
          isHot: widget.isHot,
        );
        if (mounted) {
          setState(() {
            _liveAdsCount = count;
            _isCounting = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isCounting = false);
      }
    });
  }

  void _extractTagsToUIState() {
    for (var tag in List.from(_selectedTags)) {
      if (tag.startsWith('bedrooms:')) { _selectedBedrooms.add(tag.substring(9)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('bathrooms:')) { _selectedBathrooms.add(tag.substring(10)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('furnished:')) { _selectedFurnished.add(tag.substring(10)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('rent_duration:')) { _selectedRentDuration.add(tag.substring(14)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('floor:')) { _selectedFloor.add(tag.substring(6)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('age:')) { _selectedAge.add(tag.substring(4)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('geometric_shape:')) { _selectedGeometricShape.add(tag.substring(16)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('facade:')) { _selectedFacade.add(tag.substring(7)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('land_type:')) { _selectedLandType.add(tag.substring(10)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('ownership_type:')) { _selectedOwnershipType.add(tag.substring(15)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('is_mortgaged:')) { _selectedIsMortgaged.add(tag.substring(13)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('zoning_classification:')) { _selectedZoningClassification.add(tag.substring(22)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('topography:')) { _selectedTopography.add(tag.substring(11)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('installment_possible:')) { _selectedInstallmentPossible.add(tag.substring(21)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('available_services:')) { _selectedAvailableServices.add(tag.substring(19)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('main_features:')) { _selectedMainFeatures.add(tag.substring(14)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('extra_features:')) { _selectedExtraFeatures.add(tag.substring(15)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('nearby:')) { _selectedNearby.add(tag.substring(7)); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('min_area:')) { _minAreaController.text = tag.substring(9); _selectedTags.remove(tag); continue; }
      if (tag.startsWith('max_area:')) { _maxAreaController.text = tag.substring(9); _selectedTags.remove(tag); continue; }
    }
  }

  void _compileStateToTags() {
    _selectedTags.clear();
    for (var val in _selectedBedrooms) _selectedTags.add('bedrooms:$val');
    for (var val in _selectedBathrooms) _selectedTags.add('bathrooms:$val');
    for (var val in _selectedFurnished) _selectedTags.add('furnished:$val');
    for (var val in _selectedRentDuration) _selectedTags.add('rent_duration:$val');
    for (var val in _selectedFloor) _selectedTags.add('floor:$val');
    for (var val in _selectedAge) _selectedTags.add('age:$val');
    for (var val in _selectedGeometricShape) _selectedTags.add('geometric_shape:$val');
    for (var val in _selectedFacade) _selectedTags.add('facade:$val');
    for (var val in _selectedLandType) _selectedTags.add('land_type:$val');
    for (var val in _selectedOwnershipType) _selectedTags.add('ownership_type:$val');
    for (var val in _selectedIsMortgaged) _selectedTags.add('is_mortgaged:$val');
    for (var val in _selectedZoningClassification) _selectedTags.add('zoning_classification:$val');
    for (var val in _selectedTopography) _selectedTags.add('topography:$val');
    for (var val in _selectedInstallmentPossible) _selectedTags.add('installment_possible:$val');
    for (var val in _selectedAvailableServices) _selectedTags.add('available_services:$val');
    for (var val in _selectedMainFeatures) _selectedTags.add('main_features:$val');
    for (var val in _selectedExtraFeatures) _selectedTags.add('extra_features:$val');
    for (var val in _selectedNearby) _selectedTags.add('nearby:$val');
    
    if (_minAreaController.text.isNotEmpty) _selectedTags.add('min_area:${_minAreaController.text}');
    if (_maxAreaController.text.isNotEmpty) _selectedTags.add('max_area:${_maxAreaController.text}');
    
    _selectedTags.addAll(_selectedFeatures);
  }

  bool _isRealEstate() {
    final catName = widget.category.name;
    final subName = _selectedSubCategory?.name ?? '';
    return catName.contains('عقارات') || catName.contains('شقق') || catName.contains('سكني') || catName.contains('تجاري') || catName.contains('محلات') || catName.contains('مكاتب') || catName.contains('مخازن') || catName.contains('عيادات') || catName.contains('معارض') || catName.contains('مستودع') || catName.contains('صناعي') || catName.contains('مبنى') || catName.contains('مباني') || catName.contains('مجمع') || catName.contains('ستوديو') || catName.contains('شاليه') || catName.contains('فلل') || catName.contains('رووف') || catName.contains('بيوت') || catName.contains('طابق') || catName.contains('أخرى') ||
           subName.contains('شقق') || subName.contains('عقارات') || subName.contains('أراضي') || subName.contains('فلل') || subName.contains('سكني') || subName.contains('تجاري') || subName.contains('محلات') || subName.contains('مكاتب') || subName.contains('مخازن') || subName.contains('عيادات') || subName.contains('معارض') || subName.contains('مستودع') || subName.contains('صناعي') || subName.contains('مبنى') || subName.contains('مباني') || subName.contains('مجمع') || subName.contains('ستوديو') || subName.contains('شاليه') || subName.contains('رووف') || subName.contains('بيوت') || subName.contains('طابق') || subName.contains('أخرى');
  }

  bool _isStudio() {
    final catName = widget.category.name;
    final subName = _selectedSubCategory?.name ?? '';
    return catName.contains('ستوديو') || subName.contains('ستوديو');
  }

  bool _isIndependentHouse() {
    final catName = widget.category.name;
    final subName = _selectedSubCategory?.name ?? '';
    return catName.contains('بيوت مستقلة') || subName.contains('بيوت مستقلة') || catName.contains('فيلا') || catName.contains('فلل') || subName.contains('فيلا') || subName.contains('فلل');
  }

  bool _isWholeFloor() {
    final catName = widget.category.name;
    final subName = _selectedSubCategory?.name ?? '';
    return catName.contains('طابق كامل') || subName.contains('طابق كامل');
  }

  bool _isCommercial() {
    final catName = widget.category.name;
    final subName = _selectedSubCategory?.name ?? '';
    return catName.contains('تجاري') || catName.contains('محلات') || catName.contains('مكاتب') || catName.contains('مخازن') || catName.contains('عيادات') || catName.contains('معارض') || catName.contains('مستودع') || catName.contains('صناعي') || catName.contains('مبنى') || catName.contains('مباني') || catName.contains('مجمع') ||
           subName.contains('تجاري') || subName.contains('محلات') || subName.contains('مكاتب') || subName.contains('مخازن') || subName.contains('عيادات') || subName.contains('معارض') || subName.contains('مستودع') || subName.contains('صناعي') || subName.contains('مبنى') || subName.contains('مباني') || subName.contains('مجمع');
  }

  bool _isRent() {
    final catName = widget.category.name;
    final subName = _selectedSubCategory?.name ?? '';
    return catName.contains('إيجار') || catName.contains('ايجار') || subName.contains('إيجار') || subName.contains('ايجار');
  }

  bool _isLands() {
    final catName = widget.category.name;
    final subName = _selectedSubCategory?.name ?? '';
    return catName.contains('أراضي') || subName.contains('أراضي');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    // Clear all
                    setState(() {
                      _minPriceController.clear();
                      _maxPriceController.clear();
                      _minAreaController.clear();
                      _maxAreaController.clear();
                      _selectedCategoryPath.clear();
                      _selectedBedrooms.clear();
                      _selectedBathrooms.clear();
                      _selectedFloor.clear();
                      _selectedRentDuration.clear();
                      _selectedFurnished.clear();
                      _selectedAge.clear();
                      _selectedFeatures.clear();
                      _selectedGeometricShape.clear();
                      _selectedFacade.clear();
                      _selectedLandType.clear();
                      _selectedOwnershipType.clear();
                      _selectedIsMortgaged.clear();
                      _selectedZoningClassification.clear();
                      _selectedTopography.clear();
                      _selectedInstallmentPossible.clear();
                      _selectedAvailableServices.clear();
                      _selectedMainFeatures.clear();
                      _selectedExtraFeatures.clear();
                      _selectedNearby.clear();
                      _selectedGovernorateId = null;
                      _selectedDirectorateId = null;
                      _selectedVillageId = null;
                      _selectedBasinId = null;
                      _selectedCityId = null;
                      _selectedRegionIds.clear();
                      _dynamicDataLoc.clear();
                    });
                  },
                  child: Text('حذف الخيارات', style: TextStyle(color: widget.brandColor, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const Text('تصفية النتائج', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.subCategories.isNotEmpty)
                  _buildSectionCard(
                    'القسم',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildDynamicCategoryLevels(),
                    ),
                    showReset: _selectedCategoryPath.isNotEmpty,
                    onReset: () {
                      setState(() => _selectedCategoryPath.clear());
                      _triggerCountUpdate();
                    }
                  ),

                // Location Selector is restricted to Lands only
                if (_isLands()) ...[
                  _buildSectionCard('الموقع الجغرافي', Column(
                    children: [
                      _buildDynamicLocationSelector('المحافظة', _selectedGovernorateId, [
                        {'id': 5, 'name_ar': 'محافظة العاصمة'}, {'id': 6, 'name_ar': 'محافظة إربد'}, {'id': 7, 'name_ar': 'محافظة الزرقاء'}, 
                        {'id': 8, 'name_ar': 'محافظة البلقاء'}, {'id': 16, 'name_ar': 'محافظة الطفيلة'}, {'id': 10, 'name_ar': 'محافظة العقبة'}, 
                        {'id': 13, 'name_ar': 'محافظة الكرك'}, {'id': 11, 'name_ar': 'محافظة المفرق'}, {'id': 12, 'name_ar': 'محافظة جرش'}, 
                        {'id': 14, 'name_ar': 'محافظة عجلون'}, {'id': 9, 'name_ar': 'محافظة مادبا'}, {'id': 15, 'name_ar': 'محافظة معان'}
                      ], false, (id, name) async {
                        setState(() {
                          _selectedGovernorateId = id; _dynamicDataLoc['governorate'] = name;
                          _selectedDirectorateId = null; _selectedVillageId = null; _selectedBasinId = null;
                          _directorates = []; _villages = []; _basins = []; _isLoadingLoc = true;
                        });
                        _triggerCountUpdate();
                        if (id != null) {
                           final res = await _apiService.fetchDirectorates(id);
                           setState(() { _directorates = res; _isLoadingLoc = false; });
                        } else { setState(() { _isLoadingLoc = false; }); }
                      }, icon: Icons.map_rounded),
                      _buildDynamicLocationSelector('المديرية', _selectedDirectorateId, _directorates, _isLoadingLoc, (id, name) async {
                        setState(() {
                          _selectedDirectorateId = id; _dynamicDataLoc['directorate'] = name;
                          _selectedVillageId = null; _selectedBasinId = null;
                          _villages = []; _basins = []; _isLoadingLoc = true;
                        });
                        _triggerCountUpdate();
                        if (id != null) {
                           final res = await _apiService.fetchVillages(id);
                           setState(() { _villages = res; _isLoadingLoc = false; });
                        } else { setState(() { _isLoadingLoc = false; }); }
                      }, icon: Icons.account_balance_rounded),
                      _buildDynamicLocationSelector('القرية', _selectedVillageId, _villages, _isLoadingLoc, (id, name) async {
                        setState(() {
                          _selectedVillageId = id; _dynamicDataLoc['village'] = name;
                          _selectedBasinId = null; _basins = []; _isLoadingLoc = true;
                        });
                        _triggerCountUpdate();
                        if (id != null) {
                           final res = await _apiService.fetchBasins(id);
                           setState(() { _basins = res; _isLoadingLoc = false; });
                        } else { setState(() { _isLoadingLoc = false; }); }
                      }, icon: Icons.holiday_village_rounded),
                      _buildDynamicLocationSelector('الحوض', _selectedBasinId, _basins, _isLoadingLoc, (id, name) async {
                        setState(() {
                          _selectedBasinId = id; _dynamicDataLoc['basin'] = name;
                        });
                        _triggerCountUpdate();
                      }, icon: Icons.water_rounded),
                    ],
                  ), showReset: _dynamicDataLoc.isNotEmpty, onReset: () {
                    setState(() {
                      _selectedGovernorateId = null; _selectedDirectorateId = null; _selectedVillageId = null; _selectedBasinId = null;
                      _dynamicDataLoc.clear();
                    });
                    _triggerCountUpdate();
                  }),
                ],

                // If no subcategory is selected, or if the current sub/category is Real Estate, show specific filters.
                if (_isLands()) ...[
                  _buildInputsRow('مساحة الأرض (متر مربع)', 'أدنى مساحة', 'أعلى مساحة', _minAreaController, _maxAreaController),
                  _buildInputsRow('السعر (دينار)', 'أدنى سعر', 'أعلى سعر', _minPriceController, _maxPriceController),
                  _buildMultiSelectSection('نوع العقار (الأرض)', ['سكنية', 'تجارية', 'زراعية', 'صناعية', 'استثمارية', 'سياحية', 'مختلطة', 'أخرى'], _selectedLandType, (val) { setState(() { _selectedLandType.contains(val) ? _selectedLandType.remove(val) : _selectedLandType.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedLandType.clear()); _triggerCountUpdate(); }),
                  _buildMultiSelectSection('تصنيف التنظيم', ['سكن أ', 'سكن ب', 'سكن ج', 'سكن د', 'تجاري', 'زراعي', 'صناعي', 'أخرى'], _selectedZoningClassification, (val) { setState(() { _selectedZoningClassification.contains(val) ? _selectedZoningClassification.remove(val) : _selectedZoningClassification.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedZoningClassification.clear()); _triggerCountUpdate(); }),
                  _buildMultiSelectSection('الواجهة', ['شمالية', 'جنوبية', 'شرقية', 'غربية', 'شمالية شرقية', 'شمالية غربية', 'جنوبية شرقية', 'جنوبية غربية'], _selectedFacade, (val) { setState(() { _selectedFacade.contains(val) ? _selectedFacade.remove(val) : _selectedFacade.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedFacade.clear()); _triggerCountUpdate(); }),
                  _buildMultiSelectSection('الشكل الهندسي', ['مستطيل', 'مربع', 'غير منتظم', 'زاوية / شارعَين'], _selectedGeometricShape, (val) { setState(() { _selectedGeometricShape.contains(val) ? _selectedGeometricShape.remove(val) : _selectedGeometricShape.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedGeometricShape.clear()); _triggerCountUpdate(); }),
                  _buildMultiSelectSection('طبيعة الأرض (التضاريس)', ['مستوية', 'منحدرة', 'جبلية', 'واد'], _selectedTopography, (val) { setState(() { _selectedTopography.contains(val) ? _selectedTopography.remove(val) : _selectedTopography.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedTopography.clear()); _triggerCountUpdate(); }),
                  _buildMultiSelectSection('الخدمات', ['ماء', 'كهرباء', 'صرف صحي', 'إنترنت', 'شوارع معبدة'], _selectedAvailableServices, (val) { setState(() { _selectedAvailableServices.contains(val) ? _selectedAvailableServices.remove(val) : _selectedAvailableServices.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedAvailableServices.clear()); _triggerCountUpdate(); }),
                  _buildMultiSelectSection('نوع الملكية', ['ملك', 'تفويض', 'أخرى'], _selectedOwnershipType, (val) { setState(() { _selectedOwnershipType.contains(val) ? _selectedOwnershipType.remove(val) : _selectedOwnershipType.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedOwnershipType.clear()); _triggerCountUpdate(); }),
                  _buildMultiSelectSection('تخضع للرهن؟', ['نعم', 'لا'], _selectedIsMortgaged, (val) { setState(() { _selectedIsMortgaged.contains(val) ? _selectedIsMortgaged.remove(val) : _selectedIsMortgaged.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedIsMortgaged.clear()); _triggerCountUpdate(); }),
                  _buildMultiSelectSection('متاح بالأقساط؟', ['نعم', 'لا'], _selectedInstallmentPossible, (val) { setState(() { _selectedInstallmentPossible.contains(val) ? _selectedInstallmentPossible.remove(val) : _selectedInstallmentPossible.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedInstallmentPossible.clear()); _triggerCountUpdate(); }),
                ] else if (_isRealEstate()) ...[
                  _buildSectionCard('الموقع الجغرافي', Column(
                    children: [
                      _buildUnifiedLocationSelector(),
                    ],
                  ), showReset: _dynamicDataLoc.containsKey('city') || _dynamicDataLoc.containsKey('regions'), onReset: () {
                    setState(() {
                      _selectedCityId = null; _selectedRegionIds.clear();
                      _dynamicDataLoc.remove('city'); _dynamicDataLoc.remove('regions');
                    });
                    _triggerCountUpdate();
                  }),

                  _buildInputsRow('مساحة البناء', 'أدنى مساحة', 'أعلى مساحة', _minAreaController, _maxAreaController),
                  _buildInputsRow('السعر (دينار)', 'أدنى سعر', 'أعلى سعر', _minPriceController, _maxPriceController),
                  
                  if (!_isCommercial()) ...[
                    if (!_isStudio())
                      _buildMultiSelectSection('عدد الغرف', (_isIndependentHouse() || _isWholeFloor()) ? ['1', '2', '3', '4', '5', '+6'] : ['ستوديو', '1', '2', '3', '4', '5', '+6'], _selectedBedrooms, (val) { setState(() { _selectedBedrooms.contains(val) ? _selectedBedrooms.remove(val) : _selectedBedrooms.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedBedrooms.clear()); _triggerCountUpdate(); }),
                    _buildMultiSelectSection('عدد الحمامات', ['1', '2', '3', '4', '5', '+6'], _selectedBathrooms, (val) { setState(() { _selectedBathrooms.contains(val) ? _selectedBathrooms.remove(val) : _selectedBathrooms.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedBathrooms.clear()); _triggerCountUpdate(); }),
                  ],
                  
                  _buildMultiSelectSection('مفروشة؟', ['مفروشة', 'غير مفروشة', 'مفروش جزئياً'], _selectedFurnished, (val) { setState(() { _selectedFurnished.contains(val) ? _selectedFurnished.remove(val) : _selectedFurnished.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedFurnished.clear()); _triggerCountUpdate(); }),
                  
                  if (!_isIndependentHouse())
                    _buildMultiSelectSection('الطابق', ['طابق التسوية', 'طابق شبه أرضي', 'الطابق الأرضي', '1', '2', '3', '4', '5', '6', '7'], _selectedFloor, (val) { setState(() { _selectedFloor.contains(val) ? _selectedFloor.remove(val) : _selectedFloor.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedFloor.clear()); _triggerCountUpdate(); }),
                  
                  if (_isRent())
                    _buildMultiSelectSection('مدة الإيجار', ['يومي', 'أسبوعي', 'شهري', 'كل 3 أشهر', 'كل أربع أشهر', 'كل 5 أشهر', 'كل 6 أشهر', 'سنوي'], _selectedRentDuration, (val) { setState(() { _selectedRentDuration.contains(val) ? _selectedRentDuration.remove(val) : _selectedRentDuration.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedRentDuration.clear()); _triggerCountUpdate(); }),
                  _buildMultiSelectSection('عمر البناء', ['0 - 11 شهر', '1 - 5 سنوات', '6 - 9 سنوات', '10 - 19 سنوات', '+20 سنة'], _selectedAge, (val) { setState(() { _selectedAge.contains(val) ? _selectedAge.remove(val) : _selectedAge.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedAge.clear()); _triggerCountUpdate(); }),
                  _buildMultiSelectSection('الواجهة', ['شمالية', 'جنوبية', 'شرقية', 'غربية', 'شمالية شرقية', 'شمالية غربية', 'جنوبية شرقية', 'جنوبية غربية'], _selectedFacade, (val) { setState(() { _selectedFacade.contains(val) ? _selectedFacade.remove(val) : _selectedFacade.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedFacade.clear()); _triggerCountUpdate(); }),
                  
                  if (!_isCommercial()) ...[
                    _buildMultiSelectSection('المزايا الرئيسية', ['تكييف مركزي', 'تدفئة', 'شرفة / بلكونة', 'غرفة خادمة', 'غرفة غسيل', 'خزائن حائط', 'مسبح خاص', 'سخان شمسي', 'زجاج شبابيك مزدوج'], _selectedMainFeatures, (val) { setState(() { _selectedMainFeatures.contains(val) ? _selectedMainFeatures.remove(val) : _selectedMainFeatures.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedMainFeatures.clear()); _triggerCountUpdate(); }),
                  ],
                  
                  _buildMultiSelectSection('المزايا الإضافية والمرافق', ['يوجد مصعد', 'موقف سيارات', 'حارس / أمن وحماية', 'نظام كهرباء احتياطي للطوارئ', 'انتركم', if (!_isCommercial()) ...['حديقة', 'كراج تفك', 'منطقة شواء', 'بركة سباحة']], _selectedExtraFeatures, (val) { setState(() { _selectedExtraFeatures.contains(val) ? _selectedExtraFeatures.remove(val) : _selectedExtraFeatures.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedExtraFeatures.clear()); _triggerCountUpdate(); }),
                  _buildMultiSelectSection('مواقع قريبة', ['بنك / صراف آلي', 'دراي كلين', 'سوبر ماركت', 'صالة رياضية / جيم', 'صيدلية', 'محطة باصات', 'مدرسة', 'مستشفى', 'مسجد', 'مطعم'], _selectedNearby, (val) { setState(() { _selectedNearby.contains(val) ? _selectedNearby.remove(val) : _selectedNearby.add(val); }); _triggerCountUpdate(); }, () { setState(() => _selectedNearby.clear()); _triggerCountUpdate(); }),
                ] else ...[
                  // Generic Price
                  _buildInputsRow('السعر', 'أدنى سعر', 'أعلى سعر', _minPriceController, _maxPriceController),
                ]
              ],
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.favorite_border, color: widget.brandColor),
                    label: Text('حفظ البحث', style: TextStyle(color: widget.brandColor)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: widget.brandColor),
                    ),
                    onPressed: () {
                      _compileStateToTags();
                      final locs = <String>[];
                      for (var key in ['governorate', 'directorate', 'village', 'basin']) {
                        if (_dynamicDataLoc[key] != null) locs.add(_dynamicDataLoc[key]);
                      }
                      
                      if (_isLands()) {
                        // Lands already added governorate, directorate, etc from _dynamicDataLoc
                      } else if (_isRealEstate()) {
                        final appProvider = Provider.of<AppProvider>(context, listen: false);
                        if (_selectedCityId != null) {
                          final city = appProvider.dbCities?.firstWhere((c) => c.id == _selectedCityId, orElse: () => appProvider.dbCities!.first);
                          if (city != null) {
                            locs.add(city.nameAr);
                            if (_selectedRegionIds.isNotEmpty) {
                              locs.addAll(city.regions.where((r) => _selectedRegionIds.contains(r.id)).map((r) => r.nameAr));
                            }
                          }
                        }
                      } else {
                        if (_dynamicDataLoc['city'] != null) {
                          locs.add(_dynamicDataLoc['city']);
                        }
                        if (_dynamicDataLoc['regions'] != null && (_dynamicDataLoc['regions'] as List).isNotEmpty) {
                          locs.addAll(List<String>.from(_dynamicDataLoc['regions']));
                        }
                        if (locs.isEmpty && widget.initialLocations != null) {
                          locs.addAll(widget.initialLocations!);
                        }
                      }
                      
                      final finalLocs = locs.where((s) => s.isNotEmpty && s != 'كل الأردن' && s != 'الكل').toList();

                      Navigator.pop(context, PremiumFilterData(
                        minPrice: double.tryParse(_minPriceController.text),
                        maxPrice: double.tryParse(_maxPriceController.text),
                        tags: _selectedTags,
                        selectedSubCategory: _selectedSubCategory,
                        locations: finalLocs.isNotEmpty ? finalLocs : null,
                        saveSearchRequested: true,
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.brandColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      _compileStateToTags();
                      final locs = <String>[];
                      for (var key in ['governorate', 'directorate', 'village', 'basin']) {
                        if (_dynamicDataLoc[key] != null) locs.add(_dynamicDataLoc[key]);
                      }
                      
                      if (_isLands()) {
                        // Lands already added governorate, directorate, etc from _dynamicDataLoc
                      } else if (_isRealEstate()) {
                        final appProvider = Provider.of<AppProvider>(context, listen: false);
                        if (_selectedCityId != null) {
                          final city = appProvider.dbCities?.firstWhere((c) => c.id == _selectedCityId, orElse: () => appProvider.dbCities!.first);
                          if (city != null) {
                            locs.add(city.nameAr);
                            if (_selectedRegionIds.isNotEmpty) {
                              locs.addAll(city.regions.where((r) => _selectedRegionIds.contains(r.id)).map((r) => r.nameAr));
                            }
                          }
                        }
                      } else {
                        if (_dynamicDataLoc['city'] != null) {
                          locs.add(_dynamicDataLoc['city']);
                        }
                        if (_dynamicDataLoc['regions'] != null && (_dynamicDataLoc['regions'] as List).isNotEmpty) {
                          locs.addAll(List<String>.from(_dynamicDataLoc['regions']));
                        }
                        if (locs.isEmpty && widget.initialLocations != null) {
                          locs.addAll(widget.initialLocations!);
                        }
                      }
                      
                      final finalLocs = locs.where((s) => s.isNotEmpty && s != 'كل الأردن' && s != 'الكل').toList();

                      Navigator.pop(context, PremiumFilterData(
                        minPrice: double.tryParse(_minPriceController.text),
                        maxPrice: double.tryParse(_maxPriceController.text),
                        tags: _selectedTags,
                        selectedSubCategory: _selectedSubCategory,
                        locations: finalLocs.isNotEmpty ? finalLocs : null,
                      ));
                    },
                    child: _isCounting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('فلترة (${_liveAdsCount ?? widget.totalResultsCount})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, Widget content, {VoidCallback? onReset, bool showReset = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (showReset && onReset != null)
                GestureDetector(
                  onTap: onReset,
                  child: Text('مسح', style: TextStyle(color: widget.brandColor, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  List<Widget> _buildDynamicCategoryLevels() {
    final List<Widget> levels = [];
    final allCats = Provider.of<AppProvider>(context).categories ?? [];
    List<Category> baseCats = allCats;
    if (baseCats.isEmpty) baseCats = widget.subCategories;

    int currentParentId = widget.category.id;
    int levelIndex = 1;

    while (true) {
      final currentLevelSubs = baseCats.where((c) => c.parentId == currentParentId).toList();
      if (currentLevelSubs.isEmpty) break;

      final currentLevelIndex = levelIndex;
      final selectedAtThisLevel = _selectedCategoryPath.length >= levelIndex ? _selectedCategoryPath[levelIndex - 1] : null;

      if (levelIndex > 1) {
        levels.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
            child: Row(
              children: [
                Icon(Icons.subdirectory_arrow_left_rounded, size: 20, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text('تحديد نوع ${_selectedCategoryPath[levelIndex - 2].name}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                const SizedBox(width: 12),
                Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
              ],
            ),
          ),
        );
      }

      levels.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('الكل', style: TextStyle(
                  color: selectedAtThisLevel == null ? Colors.white : Colors.black87,
                  fontWeight: selectedAtThisLevel == null ? FontWeight.bold : FontWeight.normal
                )),
                selected: selectedAtThisLevel == null,
                selectedColor: widget.brandColor,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                onSelected: (_) {
                  setState(() {
                    if (_selectedCategoryPath.length >= currentLevelIndex) {
                      _selectedCategoryPath.removeRange(currentLevelIndex - 1, _selectedCategoryPath.length);
                    }
                  });
                  _triggerCountUpdate();
                },
              ),
              ...currentLevelSubs.map((sub) {
                final isSelected = selectedAtThisLevel?.id == sub.id;
                return ChoiceChip(
                  label: Text(sub.name, style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                  )),
                  selected: isSelected,
                  selectedColor: widget.brandColor,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                  onSelected: (_) {
                    setState(() {
                      if (_selectedCategoryPath.length >= currentLevelIndex) {
                        _selectedCategoryPath.removeRange(currentLevelIndex - 1, _selectedCategoryPath.length);
                      }
                      _selectedCategoryPath.add(sub);
                    });
                    Provider.of<AppProvider>(context, listen: false).loadSubCategories(sub.id);
                    _triggerCountUpdate();
                  },
                );
              }).toList(),
            ]
          )
        )
      );

      if (selectedAtThisLevel != null) {
        currentParentId = selectedAtThisLevel.id;
        levelIndex++;
      } else {
        break;
      }
    }

    return levels;
  }

  Widget _buildMultiSelectSection(String title, List<String> options, Set<String> selectedValues, Function(String) onToggle, VoidCallback onReset) {
    return _buildSectionCard(
      title,
      showReset: selectedValues.isNotEmpty,
      onReset: onReset,
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = selectedValues.contains(opt);
          return ChoiceChip(
            label: Text(opt, style: TextStyle(
              color: isSelected ? widget.brandColor : Colors.black54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600
            )),
            selected: isSelected,
            selectedColor: widget.brandColor.withOpacity(0.1),
            backgroundColor: const Color(0xFFF9FAFB),
            showCheckmark: true,
            checkmarkColor: widget.brandColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? widget.brandColor.withOpacity(0.5) : Colors.transparent)),
            onSelected: (_) => onToggle(opt),
          );
        }).toList(),
      )
    );
  }

  Widget _buildInputsRow(String title, String minLabel, String maxLabel, TextEditingController minCtrl, TextEditingController maxCtrl) {
    return _buildSectionCard(
      title,
      showReset: minCtrl.text.isNotEmpty || maxCtrl.text.isNotEmpty,
      onReset: () {
        setState(() {
          minCtrl.clear();
          maxCtrl.clear();
        });
        _triggerCountUpdate();
      },
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(minLabel, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 8),
                TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '0',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(maxLabel, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 8),
                TextField(
                  controller: maxCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'الكل',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                )
              ],
            ),
          ),
        ],
      )
    );
  }

  Widget _buildDynamicLocationSelector(
      String label,
      int? selectedId,
      List<Map<String, dynamic>> options,
      bool isLoading,
      Function(int?, String) onSelect, {
      IconData? icon,
      String hint = 'الكل',
      bool isMultiSelect = false,
      Set<int>? selectedIds,
      Function(Set<int>, List<String>)? onMultiSelect,
  }) {
    bool hasSelection = false;
    String displayText;
    if (isMultiSelect) {
      if (selectedIds != null && selectedIds.isNotEmpty) {
        hasSelection = true;
        if (selectedIds.length == 1) {
          final matchedOptions = options.where((e) => e['id'] == selectedIds.first);
          displayText = matchedOptions.isNotEmpty ? matchedOptions.first['name_ar'] as String : hint;
        } else {
          displayText = '${selectedIds.length} مناطق محددة';
        }
      } else {
        displayText = hint;
      }
    } else {
      final matchedOptions = options.where((e) => e['id'] == selectedId);
      final selectedOption = matchedOptions.isNotEmpty ? matchedOptions.first : <String, dynamic>{};
      hasSelection = selectedOption.isNotEmpty;
      displayText = selectedOption.isNotEmpty ? selectedOption['name_ar'] as String : hint;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: options.isEmpty
                ? null
                : () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (BuildContext context) {
                        String searchQuery = '';
                        return StatefulBuilder(
                          builder: (BuildContext context, StateSetter setStateSB) {
                            final List<Map<String, dynamic>> filteredOptions = options.map((opt) => Map<String, dynamic>.from(opt)).where((opt) => 
                                opt['name_ar'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
                            
                            if (searchQuery.isEmpty) {
                              filteredOptions.insert(0, {'id': null, 'name_ar': (label == 'المدينة' || label == 'المحافظة') ? 'كل الأردن' : 'الكل'});
                            }
                            
                            return Padding(
                              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.75,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4,
                                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                                      child: Text('تحديد $label', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                      child: TextField(
                                        onChanged: (val) { setStateSB(() { searchQuery = val; }); },
                                        decoration: InputDecoration(
                                          hintText: 'ابحث عن $label...',
                                          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                                          filled: true, fillColor: Colors.grey.shade100,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12), const Divider(height: 1),
                                    Expanded(
                                      child: filteredOptions.isEmpty
                                          ? Center(child: Text('لا توجد نتائج مطابقة', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)))
                                          : ListView.builder(
                                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                              itemCount: filteredOptions.length,
                                              itemBuilder: (context, index) {
                                                final opt = filteredOptions[index];
                                                final isSelected = isMultiSelect
                                                    ? (opt['id'] == null ? (selectedIds == null || selectedIds.isEmpty) : (selectedIds?.contains(opt['id']) ?? false))
                                                    : opt['id'] == selectedId;
                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 6),
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? widget.brandColor.withOpacity(0.05) : Colors.white,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: ListTile(
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    title: Text(
                                                      opt['name_ar'],
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: isSelected ? widget.brandColor : Colors.black87,
                                                      ),
                                                    ),
                                                    trailing: isSelected ? Icon(Icons.check_circle_rounded, color: widget.brandColor) : null,
                                                    onTap: () {
                                                      if (isMultiSelect) {
                                                        if (opt['id'] == null) {
                                                          setStateSB(() { selectedIds!.clear(); });
                                                          if (onMultiSelect != null) onMultiSelect(<int>{}, <String>[]);
                                                        } else {
                                                          setStateSB(() {
                                                            if (selectedIds!.contains(opt['id'])) {
                                                              selectedIds.remove(opt['id']);
                                                            } else {
                                                              selectedIds.add(opt['id']);
                                                            }
                                                          });
                                                          if (onMultiSelect != null) {
                                                            final names = selectedIds!.map((id) {
                                                              final o = options.where((e) => e['id'] == id);
                                                              return o.isNotEmpty ? o.first['name_ar'].toString() : '';
                                                            }).where((s) => s.isNotEmpty).toList();
                                                            onMultiSelect(selectedIds, names);
                                                          }
                                                        }
                                                      } else {
                                                        Navigator.pop(context);
                                                        onSelect(opt['id'], opt['name_ar']);
                                                      }
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        );
                      },
                    );
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: options.isEmpty ? Colors.grey.shade100 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: isLoading
                        ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : Text(
                            displayText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: hasSelection ? FontWeight.w600 : FontWeight.normal,
                              color: hasSelection ? Colors.black87 : Colors.black54,
                            ),
                          ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeArabic(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  void _showUnifiedLocationPickerBottomSheet(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    City? selectedCityForFilter;
    if (_selectedCityId != null) {
      selectedCityForFilter = appProvider.dbCities?.firstWhere((c) => c.id == _selectedCityId, orElse: () => appProvider.dbCities!.first);
    }
    Set<Region> selectedRegionsForFilter = {};
    if (selectedCityForFilter != null && _selectedRegionIds.isNotEmpty) {
      selectedRegionsForFilter = selectedCityForFilter.regions.where((r) => _selectedRegionIds.contains(r.id)).toSet();
    }
    String searchQuery = '';
    final TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final cities = appProvider.dbCities ?? [];
            final normalizedSearch = _normalizeArabic(searchQuery);
            final filteredCities = searchQuery.isEmpty
                ? cities
                : cities.where((c) => _normalizeArabic(c.nameAr).contains(normalizedSearch)).toList();

            final regions = selectedCityForFilter?.regions ?? [];
            final filteredRegions = searchQuery.isEmpty
                ? regions
                : regions.where((r) => _normalizeArabic(r.nameAr).contains(normalizedSearch)).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.only(top: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                   Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      children: [
                        if (selectedCityForFilter != null)
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
                            onPressed: () => setModalState(() {
                              selectedCityForFilter = null;
                              selectedRegionsForFilter.clear();
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
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.brandColor)
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
                        onChanged: (value) => setModalState(() => searchQuery = value),
                        decoration: InputDecoration(
                          hintText: selectedCityForFilter == null ? 'ابحث عن مدينة...' : 'ابحث عن منطقة...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15, fontWeight: FontWeight.normal),
                          prefixIcon: Icon(Icons.search_rounded, color: widget.brandColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        ),
                      )
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  if (selectedCityForFilter == null) ...[
                    // Cities
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
                                onTap: () {
                                  setState(() {
                                    _selectedCityId = null;
                                    _selectedRegionIds.clear();
                                  });
                                  _triggerCountUpdate();
                                  Navigator.pop(ctx);
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
                                setState(() {
                                  _selectedCityId = c.id;
                                  _selectedRegionIds.clear();
                                });
                                _triggerCountUpdate();
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
                    // Regions
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
                                onTap: () {
                                  setState(() {
                                    _selectedCityId = selectedCityForFilter!.id;
                                    _selectedRegionIds.clear();
                                  });
                                  _triggerCountUpdate();
                                  Navigator.pop(ctx);
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
                              activeColor: widget.brandColor,
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
                            backgroundColor: widget.brandColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedCityId = selectedCityForFilter!.id;
                              _selectedRegionIds = selectedRegionsForFilter.map((e) => e.id).toSet();
                            });
                            _triggerCountUpdate();
                            Navigator.pop(ctx);
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

  Widget _buildUnifiedLocationSelector() {
    String displayText = 'كل الأردن';
    if (_selectedCityId != null) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final city = appProvider.dbCities?.firstWhere((c) => c.id == _selectedCityId, orElse: () => appProvider.dbCities!.first);
      if (city != null) {
        if (_selectedRegionIds.isNotEmpty) {
           if (_selectedRegionIds.length == 1) {
             final region = city.regions.firstWhere((r) => r.id == _selectedRegionIds.first, orElse: () => city.regions.first);
             displayText = '${city.nameAr}، ${region.nameAr}';
           } else {
             displayText = '${city.nameAr}، ${_selectedRegionIds.length} مناطق محددة';
           }
        } else {
          displayText = city.nameAr;
        }
      }
    }

    return GestureDetector(
      onTap: () => _showUnifiedLocationPickerBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_rounded, color: widget.brandColor, size: 22),
                const SizedBox(width: 12),
                Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _selectedCityId != null ? FontWeight.w600 : FontWeight.normal,
                    color: _selectedCityId != null ? Colors.black87 : Colors.black54,
                  ),
                ),
              ],
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
