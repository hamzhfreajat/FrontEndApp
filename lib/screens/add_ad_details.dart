import 'package:flutter/material.dart';
import '../widgets/support_action_button.dart';
import '../services/analytics_engine.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import 'add_ad_basic_info.dart';
import '../utils/arabic_numbers_formatter.dart';

class AddAdDetailsPage extends StatefulWidget {
  final Category selectedLeafCategory;
  final String transactionType;
  final List<XFile>? images;
  final XFile? reelVideo;
  final String selectedCity;
  final String selectedRegion;
  final String? mapLocation;
  final List<String>? selectedLandmarks;
  final Map<String, dynamic>? editingAdData;

  const AddAdDetailsPage({
    super.key,
    required this.selectedLeafCategory,
    required this.transactionType,
    required this.selectedCity,
    required this.selectedRegion,
    this.images,
    this.reelVideo,
    this.mapLocation,
    this.selectedLandmarks,
    this.editingAdData,
  });

  @override
  State<AddAdDetailsPage> createState() => _AddAdDetailsPageState();
}

class _AddAdDetailsPageState extends State<AddAdDetailsPage> {
  final Map<String, dynamic> _dynamicData = {};
  String? _commercialSubCategory;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _fieldKeys = {};
  final List<String> _errorKeys = [];

  GlobalKey _getGlobalKey(String fieldKey) {
    _fieldKeys[fieldKey] ??= GlobalKey();
    return _fieldKeys[fieldKey]!;
  }

  final _formKey = GlobalKey<FormState>();

  // OpenSooq Location Hierarchy State
  int? _selectedGovernorateId;
  int? _selectedDirectorateId;
  int? _selectedVillageId;
  int? _selectedBasinId;
  
  List<Map<String, dynamic>> _directorates = [];
  List<Map<String, dynamic>> _villages = [];
  List<Map<String, dynamic>> _basins = [];
  List<Map<String, dynamic>> _neighborhoods = [];
  
  bool _isLoadingLoc = false;

  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _pricePerMeterController = TextEditingController();
  final TextEditingController _totalPriceController = TextEditingController();

  void _calculatePrice() {
    double? area = double.tryParse(_areaController.text);
    double? ppm = double.tryParse(_pricePerMeterController.text);
    if (area != null && ppm != null) {
      double total = area * ppm;
      _totalPriceController.text = total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 2);
      _dynamicData['total_price'] = _totalPriceController.text;
    }
  }

  void _calculatePpm() {
    double? area = double.tryParse(_areaController.text);
    double? total = double.tryParse(_totalPriceController.text);
    if (area != null && area > 0 && total != null) {
      double ppm = total / area;
      _pricePerMeterController.text = ppm.toStringAsFixed(ppm.truncateToDouble() == ppm ? 0 : 2);
      _dynamicData['price_per_meter'] = _pricePerMeterController.text;
    }
  }

  late Map<String, dynamic> _adData;

  @override
  void initState() {
    super.initState();
    _adData = widget.editingAdData ?? {};
    AnalyticsEngine().logScreenViewed(screenName: 'add_ad_details');
    if (_adData.containsKey('attributes')) {
      final existingDynamic = _adData['attributes']['dynamic_data'];
      if (existingDynamic != null && existingDynamic is Map) {
        existingDynamic.forEach((key, value) {
          if (value is List) {
            _dynamicData[key] = value.map((e) => e.toString()).toList();
          } else {
            _dynamicData[key] = value;
          }
          if (key == 'commercial_sub') _commercialSubCategory = value;
          if (key == 'area') _areaController.text = value.toString();
          if (key == 'price_per_meter') _pricePerMeterController.text = value.toString();
          if (key == 'total_price') _totalPriceController.text = value.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    if (_adData.containsKey('id')) {
      final attributes = {
        'transaction_type': widget.transactionType,
        'leaf_category_name': widget.selectedLeafCategory.name,
        'dynamic_data': _dynamicData,
        if (_commercialSubCategory != null) 'commercial_sub': _commercialSubCategory,
      };
      // Fire-and-forget update
      ApiService().updateDraft(_adData['id'], {'attributes': attributes}).catchError((_) => null);
      
      _adData['attributes'] ??= {};
      _adData['attributes'].addAll(attributes);
    }
    
    _areaController.dispose();
    _pricePerMeterController.dispose();
    _totalPriceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getFormType() {
    if (_adData.containsKey('attributes')) {
      final savedFormType = _adData['attributes']['form_type'];
      if (savedFormType != null && savedFormType.toString().isNotEmpty) {
        return savedFormType.toString();
      }
    }

    final name = widget.selectedLeafCategory.name;
    final parentName = widget.transactionType;

    const commercialKeywords = [
      'تجاري', 'مكتب', 'مكاتب', 'مخزن', 'مخازن', 'عياد', 'عيادات',
      'معرض', 'معارض', 'مستودع', 'صناعي', 'مبنى', 'مباني', 'مجمع',
      'محل', 'محلات', 'كراج', 'مطعم', 'مقهى', 'كافيه', 'سوبر ماركت',
      'صيدلية', 'مخبز'
    ];

    final combinedName = '$parentName $name';
    if (combinedName.contains('أراضي') || combinedName.contains('أرض ') || combinedName.endsWith(' أرض') || combinedName == 'أرض') return 'Land';

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      if (appProvider.categories != null) {
        int? currentId = widget.selectedLeafCategory.id;
        while (currentId != null) {
          if (currentId == 311 || currentId == 10311) return 'Commercial';
          
          final catList = appProvider.categories!.where((c) => c.id == currentId).toList();
          if (catList.isEmpty) break;
          final cat = catList.first;
          
          if (cat.name.contains('أراضي') || cat.name.contains('أرض ') || cat.name.endsWith(' أرض') || cat.name == 'أرض') return 'Land';
          if (commercialKeywords.any((kw) => cat.name.contains(kw))) return 'Commercial';
          if (cat.name.contains('دراج') || cat.name.contains('دباب')) return 'Motorcycle';
          if (cat.name.contains('قطع غيار') || cat.name.contains('إكسسوارات')) return 'AutoParts';
          if (cat.name.contains('لوحات') || cat.name.contains('أرقام سيارات')) return 'LicensePlates';
          if (cat.name.contains('حيوانات') || cat.name.contains('قطط') || cat.name.contains('كلاب') || cat.name.contains('طيور')) return 'Pets';
          
          if (currentId == 306) return 'Apartment';
          
          currentId = cat.parentId;
        }
      }
    } catch (e) {
      // Fallback
    }

    if (commercialKeywords.any((kw) => combinedName.contains(kw))) return 'Commercial';
    if (combinedName.contains('شقق')) return 'Apartment';
    if (combinedName.contains('مزارع') || combinedName.contains('شاليهات')) return 'Chalet';
    if (combinedName.contains('فلل') || combinedName.contains('قصور')) return 'Villa';
    
    if (parentName.contains('عقار')) return 'Apartment'; // Default for real estate
    if (combinedName.contains('دراج')) return 'Motorcycle';
    if (combinedName.contains('أرقام') || combinedName.contains('لوحات')) return 'LicensePlates';
    if (combinedName.contains('حيوانات') || combinedName.contains('قطط') || combinedName.contains('كلاب')) return 'Pets';
    if (combinedName.contains('قطع غيار') || combinedName.contains('إكسسوارات')) return 'AutoParts';
    if (combinedName.contains('سيارات') || combinedName.contains('مركبات')) return 'Car';
    if (combinedName.contains('إلكترونيات') || combinedName.contains('اجهزة') || combinedName.contains('أجهزة')) return 'Electronics';

    return 'Generic';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  bool _validateDynamicForm() {
    return true;
  }

  void _nextStep() async {
    _errorKeys.clear();
    bool isValid = _formKey.currentState!.validate();

    if (!isValid) {
      HapticFeedback.heavyImpact();
      _showError('الرجاء تعبئة الحقول المطلوبة بشكل صحيح');

      if (_errorKeys.isNotEmpty) {
        final firstErrorKey = _errorKeys.first;
        final targetContext = _fieldKeys[firstErrorKey]?.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.1, // slightly offset from top
          );
        }
      }
      return;
    }
    if (!_validateDynamicForm()) return;

    final attributes = {
      'transaction_type': widget.transactionType,
      'leaf_category_name': widget.selectedLeafCategory.name,
      'dynamic_data': _dynamicData,
      'form_type': _getFormType(),
      if (_commercialSubCategory != null)
        'commercial_sub': _commercialSubCategory,
    };

    if (_adData.containsKey('id')) {
      try {
        await ApiService().updateDraft(_adData['id'], {'attributes': attributes});
        _adData['attributes'] ??= {};
        _adData['attributes'].addAll(attributes);
      } catch (e) {
        debugPrint('Failed to update draft: $e');
      }
    }

    if (!mounted) return;

    AnalyticsEngine().logButtonTapped(buttonName: 'next_step', location: 'add_ad_details');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAdBasicInfoPage(
          selectedLeafCategory: widget.selectedLeafCategory,
          transactionType: widget.transactionType,
          selectedCity: widget.selectedCity,
          selectedRegion: widget.selectedRegion,
          attributes: Map<String, dynamic>.from(_adData['attributes'] ?? {}),
          images: widget.images,
          reelVideo: widget.reelVideo,
          mapLocation: widget.mapLocation,
          selectedLandmarks: widget.selectedLandmarks,
          editingAdData: _adData,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  // --- Premium UI Builders ---

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, top: 4.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0075FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF0075FF), size: 24),
            ),
            const SizedBox(width: 12),
          ] else ...[
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF0075FF),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  letterSpacing: -0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildTipBanner(
      {String title = 'نصيحة لبيع أسرع ⚡',
      String message =
          'المشترون يفضلون الإعلانات التي تحتوي على كافة التفاصيل بدقة ووضوح. خذ وقتك!',
      IconData icon = Icons.tips_and_updates_rounded}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0075FF).withValues(alpha: 0.12),
            const Color(0xFF0075FF).withValues(alpha: 0.04)
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: const Color(0xFF0075FF).withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF0075FF).withValues(alpha: 0.15),
                      blurRadius: 12)
                ]),
            child: Icon(icon, color: const Color(0xFF0075FF), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0056B3))),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF004085),
                      height: 1.6,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementField(String label, String key, String unit,
      {IconData? icon, TextEditingController? controller, void Function(String)? onChangedExt, bool isRequired = true}) {
    return Padding(
      key: _getGlobalKey(key),
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87)),
              ),
              if (!isRequired) ...[
                const SizedBox(width: 8),
                const Text('(اختياري)',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            initialValue: controller == null ? _dynamicData[key]?.toString() : null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [ArabicNumbersFormatter()],
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            validator: (val) {
              if (isRequired && (val == null || val.isEmpty)) {
                if (!_errorKeys.contains(key)) _errorKeys.add(key);
                return 'هذا الحقل مطلوب';
              }
              return null;
            },
            decoration: InputDecoration(
              suffixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Text(unit,
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w900,
                          fontSize: 13)),
                ),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF0075FF), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            onChanged: (val) {
              _dynamicData[key] = val;
              if (onChangedExt != null) onChangedExt(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String key,
      {TextInputType keyboardType = TextInputType.text,
      IconData? icon,
      bool isRequired = true}) {
    return Padding(
      key: _getGlobalKey(key),
      padding: const EdgeInsets.only(bottom: 24.0),
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87)),
              if (!isRequired) ...[
                const SizedBox(width: 8),
                const Text('(اختياري)',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _dynamicData[key]?.toString(),
            keyboardType: keyboardType,
            inputFormatters: (keyboardType == TextInputType.number || keyboardType == const TextInputType.numberWithOptions(decimal: true) || keyboardType == TextInputType.phone) ? [ArabicNumbersFormatter()] : null,
            textDirection: (keyboardType == TextInputType.number || keyboardType == const TextInputType.numberWithOptions(decimal: true)) ? TextDirection.ltr : null,
            textAlign: (keyboardType == TextInputType.number || keyboardType == const TextInputType.numberWithOptions(decimal: true)) ? TextAlign.center : TextAlign.start,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            validator: (val) {
              if (isRequired && (val == null || val.isEmpty)) {
                if (!_errorKeys.contains(key)) _errorKeys.add(key);
                return 'هذا الحقل مطلوب';
              }
              return null;
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF0075FF), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            onChanged: (val) => _dynamicData[key] = val,
          ),
        ],
      ),
    );
  }

  Widget _buildRadioChips(String label, String key, List<String> options,
      {IconData? icon, bool isRequired = true}) {
    if (_dynamicData[key] is List) {
      if ((_dynamicData[key] as List).isNotEmpty) {
        _dynamicData[key] = (_dynamicData[key] as List).first.toString();
      } else {
        _dynamicData[key] = null;
      }
    }
    return FormField<String>(
      validator: (val) {
        final selectedOption = _dynamicData[key] as String?;
        if (isRequired && (selectedOption == null || selectedOption.isEmpty)) {
          if (!_errorKeys.contains(key)) _errorKeys.add(key);
          return 'الرجاء اختيار أحد الخيارات لتتمكن من المتابعة';
        }
        return null;
      },
      builder: (state) {
        final selectedOption = _dynamicData[key] as String?;
        return Padding(
          key: _getGlobalKey(key),
          padding: const EdgeInsets.only(bottom: 32.0),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87)),
                  const SizedBox(width: 8),
                  if (isRequired)
                    const Text('*',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold))
                  else
                    const Text('(اختياري)',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: options.map((opt) {
                  final isSelected = opt == selectedOption;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (key == 'commercial_sub')
                          _commercialSubCategory = opt;
                        _dynamicData[key] = opt;
                      });
                    },
                    child: AnimatedContainer(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 64),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? const Color(0xFF0075FF) : Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0075FF)
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: const Color(0xFF0075FF)
                                        .withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4))
                              ]
                            : [],
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (state.hasError) ...[
                const SizedBox(height: 8),
                Text(state.errorText!,
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckboxGroup(String label, String key, List<String> options,
      {IconData? icon}) {
    if (_dynamicData[key] == null) {
      _dynamicData[key] = <String>[];
    } else if (_dynamicData[key] is String) {
      if ((_dynamicData[key] as String).isEmpty) {
        _dynamicData[key] = <String>[];
      } else {
        _dynamicData[key] = <String>[_dynamicData[key]];
      }
    } else if (_dynamicData[key] is List && _dynamicData[key] is! List<String>) {
      _dynamicData[key] = (_dynamicData[key] as List).map((e) => e.toString()).toList();
    }

    return Padding(
      key: _getGlobalKey(key),
      padding: const EdgeInsets.only(bottom: 32.0),
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87)),
              const SizedBox(width: 8),
              const Text('(اختياري)',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: options.map((opt) {
              final List<String> currentList = _dynamicData[key];
              final isChecked = currentList.contains(opt);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isChecked) {
                      currentList.remove(opt);
                    } else {
                      currentList.add(opt);
                    }
                  });
                },
                child: AnimatedContainer(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 64),
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isChecked
                        ? const Color(0xFF10B981).withValues(alpha: 0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isChecked
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isChecked
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: isChecked
                            ? const Color(0xFF10B981)
                            : Colors.grey.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          opt,
                          style: TextStyle(
                            color: isChecked
                                ? const Color(0xFF10B981)
                                : Colors.black87,
                            fontWeight:
                                isChecked ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
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

  Widget _buildDatePickerField(String label, String key,
      {IconData? icon, bool isRequired = true}) {
    final selectedDate = _dynamicData[key] as String?;

    return Padding(
      key: _getGlobalKey(key),
      padding: const EdgeInsets.only(bottom: 24.0),
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87)),
              const SizedBox(width: 8),
              if (isRequired)
                const Text('*',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold))
              else
                const Text('(اختياري)',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          FormField<String>(
            validator: (val) {
              final currentVal = _dynamicData[key] as String?;
              if (isRequired && (currentVal == null || currentVal.isEmpty)) {
                if (!_errorKeys.contains(key)) _errorKeys.add(key);
                return 'هذا الحقل مطلوب';
              }
              return null;
            },
            builder: (FormFieldState<String> state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final DateTime? picked =
                          await showModalBottomSheet<DateTime>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (BuildContext builder) {
                          DateTime tempPickedDate = DateTime.now();
                          return Container(
                            height: 320,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  topRight: Radius.circular(24)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(2)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('تحديد $label',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                                      ElevatedButton(
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          Navigator.of(context)
                                              .pop(tempPickedDate);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF0075FF),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 0),
                                        ),
                                        child: const Text('تأكيد',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(),
                                Expanded(
                                  child: StatefulBuilder(
                                      builder: (context, setSheetState) {
                                    int currentYearVal = tempPickedDate.year;
                                    int currentMonthVal = tempPickedDate.month;
                                    int currentDayVal = tempPickedDate.day;

                                    int daysInMonth = DateTime(currentYearVal,
                                            currentMonthVal + 1, 0)
                                        .day;
                                    if (currentDayVal > daysInMonth) {
                                      currentDayVal = daysInMonth;
                                      tempPickedDate = DateTime(currentYearVal,
                                          currentMonthVal, currentDayVal);
                                    }

                                    final textStyle = const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87);

                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // Day
                                        Expanded(
                                          child: CupertinoPicker(
                                            scrollController:
                                                FixedExtentScrollController(
                                                    initialItem:
                                                        currentDayVal - 1),
                                            itemExtent: 40,
                                            onSelectedItemChanged: (index) {
                                              setSheetState(() {
                                                tempPickedDate = DateTime(
                                                    currentYearVal,
                                                    currentMonthVal,
                                                    index + 1);
                                              });
                                              HapticFeedback.lightImpact();
                                            },
                                            children: List.generate(daysInMonth,
                                                (index) {
                                              return Center(
                                                  child: Text('${index + 1}',
                                                      style: textStyle));
                                            }),
                                          ),
                                        ),
                                        const Text('/',
                                            style: TextStyle(
                                                fontSize: 24,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w300)),
                                        // Month
                                        Expanded(
                                          child: CupertinoPicker(
                                            scrollController:
                                                FixedExtentScrollController(
                                                    initialItem:
                                                        currentMonthVal - 1),
                                            itemExtent: 40,
                                            onSelectedItemChanged: (index) {
                                              setSheetState(() {
                                                int newMonth = index + 1;
                                                int newMaxDays = DateTime(
                                                        currentYearVal,
                                                        newMonth + 1,
                                                        0)
                                                    .day;
                                                int newDay =
                                                    currentDayVal > newMaxDays
                                                        ? newMaxDays
                                                        : currentDayVal;
                                                tempPickedDate = DateTime(
                                                    currentYearVal,
                                                    newMonth,
                                                    newDay);
                                              });
                                              HapticFeedback.lightImpact();
                                            },
                                            children:
                                                List.generate(12, (index) {
                                              return Center(
                                                  child: Text('${index + 1}',
                                                      style: textStyle));
                                            }),
                                          ),
                                        ),
                                        const Text('/',
                                            style: TextStyle(
                                                fontSize: 24,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w300)),
                                        // Year
                                        Expanded(
                                          child: CupertinoPicker(
                                            scrollController:
                                                FixedExtentScrollController(
                                                    initialItem:
                                                        currentYearVal -
                                                            (DateTime.now()
                                                                    .year -
                                                                15)),
                                            itemExtent: 40,
                                            onSelectedItemChanged: (index) {
                                              setSheetState(() {
                                                int newYear =
                                                    (DateTime.now().year - 15) +
                                                        index;
                                                int newMaxDays = DateTime(
                                                        newYear,
                                                        currentMonthVal + 1,
                                                        0)
                                                    .day;
                                                int newDay =
                                                    currentDayVal > newMaxDays
                                                        ? newMaxDays
                                                        : currentDayVal;
                                                tempPickedDate = DateTime(
                                                    newYear,
                                                    currentMonthVal,
                                                    newDay);
                                              });
                                              HapticFeedback.lightImpact();
                                            },
                                            children:
                                                List.generate(16, (index) {
                                              return Center(
                                                  child: Text(
                                                      '${(DateTime.now().year - 15) + index}',
                                                      style: textStyle));
                                            }),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                      if (picked != null) {
                        final formattedDate =
                            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                        setState(() {
                          _dynamicData[key] = formattedDate;
                        });
                        state.didChange(formattedDate);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: state.hasError
                              ? Colors.red
                              : (selectedDate != null
                                  ? const Color(0xFF0075FF)
                                  : Colors.grey.shade200),
                          width: state.hasError || selectedDate != null
                              ? 2.0
                              : 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(selectedDate ?? 'تحديد التاريخ...',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: selectedDate != null
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: selectedDate != null
                                      ? Colors.black87
                                      : Colors.grey.shade500)),
                          const Icon(Icons.calendar_month_rounded,
                              color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  if (state.hasError) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(state.errorText!,
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    )
                  ]
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetSelector(
      String label, String key, List<String> options,
      {IconData? icon,
      bool isRequired = true,
      Widget Function(String)? leadingBuilder}) {
    return Padding(
      key: _getGlobalKey(key),
      padding: const EdgeInsets.only(bottom: 24.0),
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87)),
              const SizedBox(width: 8),
              if (isRequired)
                const Text('*',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold))
              else
                const Text('(اختياري)',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          FormField<String>(
            validator: (val) {
              final currentVal = _dynamicData[key] as String?;
              if (isRequired && (currentVal == null || currentVal.isEmpty)) {
                if (!_errorKeys.contains(key)) _errorKeys.add(key);
                return 'هذا الحقل مطلوب';
              }
              return null;
            },
            builder: (FormFieldState<String> state) {
              final selectedOption = _dynamicData[key] as String?;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) {
                          String sheetSearchQuery = '';
                          return StatefulBuilder(
                            builder: (BuildContext context,
                                StateSetter setSheetState) {
                              final filteredOptions = options
                                  .where((opt) => opt
                                      .toLowerCase()
                                      .contains(sheetSearchQuery.toLowerCase()))
                                  .toList();

                              return Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.7,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(24),
                                      topRight: Radius.circular(24)),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius:
                                              BorderRadius.circular(2)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 8),
                                      child: Text('اختر $label',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    if (options.length > 5)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 8),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: Colors.grey.shade200,
                                                width: 1.2),
                                          ),
                                          child: TextField(
                                            onChanged: (val) {
                                              setSheetState(
                                                  () => sheetSearchQuery = val);
                                            },
                                            decoration: InputDecoration(
                                              hintText: 'البحث عن $label...',
                                              hintStyle: TextStyle(
                                                  color: Colors.grey.shade400,
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.normal),
                                              prefixIcon: const Icon(
                                                  Icons.search,
                                                  color: Colors.grey,
                                                  size: 20),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 14),
                                            ),
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87),
                                          ),
                                        ),
                                      ),
                                    const Divider(),
                                    Expanded(
                                      child: filteredOptions.isEmpty
                                          ? Center(
                                              child: Text(
                                                  'لا يوجد نتائج متطابقة',
                                                  style: TextStyle(
                                                      color:
                                                          Colors.grey.shade500,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500)),
                                            )
                                          : ListView.builder(
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              itemCount: filteredOptions.length,
                                              itemBuilder: (context, index) {
                                                final opt =
                                                    filteredOptions[index];
                                                final isSubSelected =
                                                    opt == selectedOption;
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(
                                                          color: Colors
                                                              .grey.shade100,
                                                          width: 1.5),
                                                    ),
                                                  ),
                                                  child: ListTile(
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 24,
                                                            vertical: 4),
                                                    leading: leadingBuilder !=
                                                            null
                                                        ? leadingBuilder(opt)
                                                        : null,
                                                    onTap: () {
                                                      HapticFeedback
                                                          .lightImpact();
                                                      final scrollOffset = _scrollController.offset;
                                                      setState(() =>
                                                          _dynamicData[key] =
                                                              opt);
                                                      state.didChange(opt);
                                                      Navigator.pop(context);
                                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                                        if (_scrollController.hasClients) {
                                                          _scrollController.jumpTo(
                                                            scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
                                                          );
                                                        }
                                                      });
                                                    },
                                                    title: Text(opt,
                                                        style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                isSubSelected
                                                                    ? FontWeight
                                                                        .bold
                                                                    : FontWeight
                                                                        .w600,
                                                            color: isSubSelected
                                                                ? const Color(
                                                                    0xFF0075FF)
                                                                : Colors
                                                                    .black87)),
                                                    trailing: isSubSelected
                                                        ? const Icon(
                                                            Icons.check_circle,
                                                            color: Color(
                                                                0xFF0075FF),
                                                            size: 26)
                                                        : null,
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: state.hasError
                              ? Colors.red
                              : (selectedOption != null
                                  ? const Color(0xFF0075FF)
                                  : Colors.grey.shade200),
                          width: state.hasError || selectedOption != null
                              ? 2.0
                              : 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (leadingBuilder != null &&
                                  selectedOption != null) ...[
                                leadingBuilder(selectedOption),
                                const SizedBox(width: 12),
                              ],
                              Text(selectedOption ?? 'الرجاء الاختيار...',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: selectedOption != null
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: selectedOption != null
                                          ? Colors.black87
                                          : Colors.grey.shade500)),
                            ],
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  if (state.hasError) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(state.errorText!,
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    )
                  ]
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Specialized Form Sections ---

  Widget _buildRentalDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('الرسوم والتأمين',
                  icon: Icons.payments_rounded),
              _buildRadioChips('رسوم الخدمات/الحارس', 'building_fees_status',
                  ['يوجد رسوم', 'لا يوجد رسوم']),
              if (_dynamicData['building_fees_status'] == 'يوجد رسوم')
                _buildMeasurementField(
                    'قيمة الرسوم الشهرية', 'monthly_building_fee', 'دينار'),
              _buildRadioChips('مبلغ التأمين', 'security_deposit_type',
                  ['بدون تأمين', 'نصف شهر', 'شهر واحد', 'مبلغ آخر']),
              if (_dynamicData['security_deposit_type'] == 'مبلغ آخر')
                _buildMeasurementField(
                    'قيمة التأمين', 'custom_security_deposit', 'دينار'),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('الفئة المستهدفة وشروط التأجير',
                  icon: Icons.family_restroom_rounded),
              _buildCheckboxGroup('الفئة المستهدفة', 'target_tenants', [
                'الجميع / بدون شروط',
                'عائلات فقط',
                'يفضل عرسان جدد',
                'طالبات/موظفات',
                'عزاب',
                'أجانب/دبلوماسيين',
                'سكن شركات/موظفين',
              ]),
              _buildCheckboxGroup(
                  'شروط وإرشادات التأجير', 'property_restrictions', [
                'التزام بالهدوء / بيئة عائلية',
                'يمنع القطط نهائياً',
                'مسموح بالقطط فقط',
                'مسموح بالقطط والكلاب',
                'يمنع إقامة الحفلات الصاخبة',
                'يمنع التأجير اليومي / السياحي',
                'للسكن فقط',
                'التدخين على البلكونة فقط',
                'ممنوع التدخين داخل الشقة',
                'ممنوع الأرجيلة نهائياً',
                'يمنع الصعود إلى السطح',
                'الالتزام بموقف سيارة واحد فقط',
                'يمنع ثقب الجدران بدون إذن',
                'يمنع تغيير ألوان الدهان',
                'المستأجر مسؤول عن الصيانة البسيطة',
                'تسليم الشقة بنفس حالة الاستلام'
              ]),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('الخدمات التحتية والمرافق',
                  icon: Icons.maps_home_work_rounded),
              _buildCheckboxGroup('المياه', 'water_supply', [
                'بئر ماء مستقل',
                'بئر ماء مشترك',
                'مياه سلطة فقط',
                'مضخة ماء راكبة'
              ]),
              _buildCheckboxGroup('العدادات', 'meters_setup',
                  ['ساعة كهرباء مفصولة', 'ساعة ماء مفصولة', 'عدادات مشتركة']),
              _buildCheckboxGroup('التبريد', 'cooling_features',
                  ['مكيفات راكبة', 'تأسيس مكيفات']),
              _buildCheckboxGroup('التدفئة', 'heating_features', [
                'تدفئة مركزية - ديزل',
                'تدفئة مركزية - غاز',
                'تدفئة تحت البلاط'
              ]),
              _buildCheckboxGroup('تسخين المياه', 'water_heating_features',
                  ['سخان شمسي', 'كيزر كهرباء']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApartmentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('تفاصيل العقار',
                  icon: Icons.apartment_rounded),
              _buildMeasurementField('مساحة البناء', 'area', 'متر مربع',
                  icon: Icons.square_foot_rounded),
              if (widget.selectedLeafCategory.name.contains('مستقلة'))
                _buildMeasurementField('مساحة الأرض', 'land_area', 'متر مربع',
                    icon: Icons.landscape_rounded),
              _buildRadioChips('هل يوجد ترس؟', 'has_terrace', ['نعم', 'لا'],
                  icon: Icons.deck_rounded),
              if (_dynamicData['has_terrace'] == 'نعم')
                _buildMeasurementField('مساحة الترس', 'terrace_area', 'متر مربع',
                    icon: Icons.square_foot_rounded),
              if (!widget.selectedLeafCategory.name.contains('ستوديو') && !widget.selectedLeafCategory.name.contains('استوديو'))
                _buildRadioChips('عدد الغرف', 'bedrooms',
                    ['1', '2', '3', '4', '5', '+6'],
                    icon: Icons.bed_rounded),
              _buildRadioChips(
                  'عدد الحمامات', 'bathrooms', ['1', '2', '3', '4', '5', '+6'],
                  icon: Icons.bathtub_rounded),
              if (widget.transactionType == 'عقارات للإيجار') ...[
                _buildRadioChips('حالة الفرش', 'furnishing',
                    ['مفروشة', 'غير مفروشة', 'مفروش جزئياً'],
                    icon: Icons.chair_rounded),
                _buildCheckboxGroup('مدة الإيجار', 'rent_duration',
                    ['يومي', 'أسبوعي', 'شهري', 'كل 3 أشهر', 'كل أربع أشهر', 'كل 5 أشهر', 'كل 6 أشهر', 'سنوي'],
                    icon: Icons.calendar_month_rounded),
              ],
              _buildRadioChips(
                  'الطابق',
                  'floor',
                  [
                    'طابق التسوية',
                    'طابق شبه أرضي',
                    'الطابق الأرضي',
                    '1',
                    '2',
                    '3',
                    '4',
                    '5',
                    '6',
                    '7',
                    'طابق أخير',
                    'روف',
                    'طابق أخير مع روف',
                  ],
                  icon: Icons.layers_rounded),
              _buildRadioChips(
                  'عمر البناء',
                  'age',
                  [
                    '0 - 11 شهر',
                    '1 - 5 سنوات',
                    '6 - 9 سنوات',
                    '10 - 19 سنوات',
                    '+20 سنة'
                  ],
                  icon: Icons.date_range_rounded),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('المزايا والتفاصيل الإضافية',
                  icon: Icons.star_rounded),
              _buildCheckboxGroup('المزايا الرئيسية', 'main_features', [
                'تكييف مركزي',
                'تدفئة',
                'شرفة / بلكونة',
                'غرفة خادمة',
                'غرفة غسيل',
                'خزائن حائط',
                'مسبح خاص',
                'سخان شمسي',
                'زجاج شبابيك مزدوج',
                'مطبخ راكب',
                'صالون واسع',
                'تأسيس تكييف'
              ]),
              _buildCheckboxGroup(
                  'المزايا الإضافية والمرافق', 'extra_features', [
                'يوجد مصعد',
                'حديقة',
                'كراج',
                'حارس / أمن وحماية',
                'كراج تفك',
                'منطقة شواء',
                'نظام كهرباء احتياطي للطوارئ',
                'بركة سباحة',
                'انتركم'
              ]),
              _buildCheckboxGroup('مواقع قريبة', 'nearby', [
                'بنك / صراف آلي',
                'دراي كلين',
                'سوبر ماركت',
                'صالة رياضية / جيم',
                'صيدلية',
                'محطة باصات',
                'مدرسة',
                'مستشفى',
                'مسجد',
                'مطعم'
              ]),
              _buildRadioChips(
                  'الواجهة',
                  'facade',
                  [
                    'شقة طابقية',
                    'شمالية',
                    'جنوبية',
                    'شرقية',
                    'غربية',
                    'شمالية شرقية',
                    'شمالية غربية',
                    'جنوبية شرقية',
                    'جنوبية غربية'
                  ],
                  isRequired: false,
                  icon: Icons.explore_rounded),
            ],
          ),
        ),
        if (widget.transactionType == 'عقارات للإيجار')
          _buildRentalDetailsForm(),
      ],
    );
  }

  Widget _buildDynamicLocationSelector(
      String label,
      String key,
      int? selectedId,
      List<Map<String, dynamic>> options,
      bool isLoading,
      Function(int?, String) onSelect, {
      IconData? icon,
      String hint = 'إختر من القائمة',
  }) {
    final selectedOption = options.firstWhere((e) => e['id'] == selectedId, orElse: () => {});
    final displayText = selectedOption.isNotEmpty ? selectedOption['name_ar'] as String : hint;

    return Padding(
      key: _getGlobalKey(key),
      padding: const EdgeInsets.only(bottom: 24.0),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
              const SizedBox(width: 8),
              const Text('*', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: options.isEmpty
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (BuildContext context) {
                        String searchQuery = '';
                        return StatefulBuilder(
                          builder: (BuildContext context, StateSetter setStateSB) {
                            final filteredOptions = options.where((opt) => 
                                opt['name_ar'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
                            
                            return Padding(
                              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.75, // Increased height for keyboard
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(vertical: 12),
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(2)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                                      child: Text('تحديد $label',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    ),
                                    // Premium Search Bar
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                      child: TextField(
                                        onChanged: (val) {
                                          setStateSB(() {
                                            searchQuery = val;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'ابحث عن $label...',
                                          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                                          filled: true,
                                          fillColor: Colors.grey.shade100,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: filteredOptions.isEmpty
                                          ? Center(
                                              child: Text(
                                                'لا توجد نتائج مطابقة',
                                                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                              ),
                                            )
                                          : ListView.builder(
                                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                              itemCount: filteredOptions.length,
                                              itemBuilder: (context, index) {
                                                final opt = filteredOptions[index];
                                                final isSelected = opt['id'] == selectedId;
                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 6),
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? const Color(0xFF0075FF).withOpacity(0.05) : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: ListTile(
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    title: Text(
                                                      opt['name_ar'],
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                        color: isSelected ? const Color(0xFF0075FF) : Colors.black87,
                                                      ),
                                                    ),
                                                    trailing: isSelected
                                                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0075FF))
                                                        : null,
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      onSelect(opt['id'], opt['name_ar']);
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: options.isEmpty ? Colors.grey.shade100 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: selectedOption.isNotEmpty ? Colors.black87 : Colors.grey.shade500,
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

  Widget _buildLandForm() {
    final landType = _dynamicData['land_type'];
    final ownershipType = _dynamicData['ownership_type'];
    final isMortgaged = _dynamicData['is_mortgaged'];
    final zoningClassification = _dynamicData['zoning_classification'];
    final facade = _dynamicData['street_facade'];
    final availableServices = _dynamicData['available_services'] as List<String>? ?? [];
    final topography = _dynamicData['topography'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('معلومات الأرض الأساسية', icon: Icons.landscape_rounded),
              _buildMeasurementField('مساحة الأرض', 'area', 'متر مربع',
                  icon: Icons.square_foot_rounded,
                  controller: _areaController, onChangedExt: (_) => _calculatePrice()),
              Row(
                children: [
                  Expanded(child: _buildMeasurementField('الطول', 'length', 'متر')),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMeasurementField('العرض', 'width', 'متر', isRequired: false)),
                ],
              ),
              _buildRadioChips('الشكل الهندسي', 'geometric_shape', ['مستطيل', 'مربع', 'غير منتظم', 'زاوية / شارعَين']),


                
              _buildTextField('رقم القطعة', 'plot_number', keyboardType: TextInputType.number),
              _buildCheckboxGroup('الواجهة', 'facade', ['شمالية', 'جنوبية', 'شرقية', 'غربية', 'شمالية شرقية', 'شمالية غربية', 'جنوبية شرقية', 'جنوبية غربية']),

            ],
          ),
        ),
        


        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('الوضع القانوني والملكية', icon: Icons.gavel_rounded),
              _buildRadioChips('هل العقار مرهون؟', 'is_mortgaged', ['نعم', 'لا']),
              if (isMortgaged == 'نعم')
                _buildTextField('تفاصيل الرهن / إمكانية الفك', 'mortgage_details', isRequired: false),
              _buildRadioChips('نوع الملكية', 'ownership_type', ['طابو', 'حصة مشاع', 'إفراز', 'قسيمة', 'وكالة', 'أخرى']),
              if (ownershipType == 'حصة مشاع')
                _buildTextField('عدد الحصص من المجموع الكلي', 'shares_number', isRequired: true),
              if (ownershipType == 'وكالة')
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                  child: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('يرجى العلم بأن البيع بموجب وكالة يتطلب التأكد من صلاحية الوكالة لدى الجهات الرسمية.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)))]),
                ),
              _buildRadioChips('حالة الأوراق', 'papers_status', ['كاملة', 'ناقصة', 'تحت الإجراء', 'جاهزة للبيع']),
              _buildCheckboxGroup('تأكيدات إضافية', 'legal_status_checks', ['يوجد كفالة / تنظيم', 'توجد مخالفات', 'توجد خدمات تنظيمية', 'توجد رسوم متأخرة'], icon: Icons.checklist_rounded),
            ],
          ),
        ),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('التصنيف التنظيمي والمعماري', icon: Icons.architecture_rounded),
              _buildRadioChips('تصنيف الأرض (حالة التنظيم)', 'zoning_classification', ['داخل التنظيم', 'خارج التنظيم']),
              if (zoningClassification == 'داخل التنظيم')
                _buildRadioChips('فئة التنظيم', 'zoning_category', ['سكن أ', 'سكن ب', 'سكن ج', 'سكن د', 'أحكام خاصة']),
              
              if (landType != 'زراعية') ...[
                _buildMeasurementField('نصيب البناء', 'building_ratio', '٪', isRequired: false),
                _buildMeasurementField('الطوابق المسموح بها', 'allowed_floors', 'طوابق', isRequired: false),
              ] else ...[
                _buildTextField('نوع التربة', 'soil_type', isRequired: false),
                _buildRadioChips('توفر مياه ري', 'irrigation_water', ['نعم', 'لا'], isRequired: false),
              ],
              
              if (landType == 'صناعية')
                _buildRadioChips('قدرة تحمل الكهرباء', 'electricity_capacity', ['3 Phase متوفر', 'غير متوفر'], isRequired: false),

              _buildCheckboxGroup('الاستعمال المسموح', 'allowed_usage', ['سكن', 'عمارة', 'فيلا', 'محلات', 'مستودعات', 'مزرعة', 'مشروع استثماري']),
              _buildRadioChips('هل الأرض مفروزة؟', 'is_subdivided', ['نعم', 'لا']),
              _buildRadioChips('هل عليها مخطط؟', 'has_blueprint', ['نعم', 'لا']),
            ],
          ),
        ),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('الوصول والبنية التحتية', icon: Icons.add_road_rounded),
              _buildRadioChips('نوع الشارع', 'street_type', ['شارع رئيسي', 'شارع فرعي', 'شارع داخلي', 'شارع نافذ', 'زاوية / على شارعين']),
              _buildRadioChips('الواجهة على الشارع', 'street_facade', ['مباشرة', 'خلفية', 'زاوية', 'أكثر من واجهة']),
              
              if (facade == 'زاوية' || facade == 'أكثر من واجهة') ...[
                Row(
                  children: [
                    Expanded(child: _buildMeasurementField('عرض الشارع 1', 'street_width_1', 'متر', isRequired: false)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMeasurementField('عرض الشارع 2', 'street_width_2', 'متر', isRequired: false)),
                  ],
                )
              ] else ...[
                _buildMeasurementField('عرض الشارع', 'street_width', 'متر', isRequired: false),
              ],

              _buildCheckboxGroup('الخدمات المتوفرة', 'available_services', ['ماء', 'كهرباء', 'صرف صحي', 'هاتف / إنترنت', 'شارع معبد', 'إنارة', 'غير مخدومة']),
              if (availableServices.contains('غير مخدومة'))
                _buildMeasurementField('المسافة لأقرب نقطة خدمة', 'distance_to_service', 'متر', isRequired: false),

              _buildRadioChips('طبيعة الأرض', 'topography', ['مستوية', 'مائلة', 'مرتفعة', 'منخفضة', 'تحتاج تسوية']),
              if (topography == 'تحتاج تسوية')
                _buildTextField('ملاحظات عن الطبيعة (جرف/طمم..)', 'topography_notes', isRequired: false),
            ],
          ),
        ),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('ميزات إضافية', icon: Icons.star_rounded),
              _buildCheckboxGroup('تتضمن الميزات التالية', 'extra_features', [
                'الأرض مسورة',
                'فيها بناء قائم',
                'فيها أشجار / زراعة',
                'بئر ماء',
                'عداد كهرباء',
                'عداد ماء',
                'تصلح للبناء الفوري',
                'تصلح للاستثمار',
                'يوجد جار مباشر'
              ]),
              _buildCheckboxGroup('مواقع قريبة', 'nearby_locations', [
                'بنك / صراف آلي',
                'دراي كلين',
                'سوبر ماركت',
                'صالة رياضية / جيم',
                'صيدلية',
                'محطة باصات',
                'مدرسة',
                'مستشفى',
                'مسجد',
                'مطعم',
                'موقف سيارات',
                'مول / مركز تسوق'
              ]),
            ],
          ),
        ),



        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('معلومات احترافية إضافية', icon: Icons.more_rounded),
              _buildRadioChips('سبب البيع', 'sale_reason', ['سفر', 'سيولة', 'تغيير استثمار', 'تقسيم ميراث', 'ترقية', 'أخرى'], isRequired: false),
              _buildRadioChips('إمكانية التبادل', 'exchange_possible', ['نعم', 'لا'], isRequired: false),
              _buildRadioChips('إمكانية الشراكة', 'partnership_possible', ['نعم', 'لا'], isRequired: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVillaForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('تفاصيل الفيلا', icon: Icons.villa_rounded),
              _buildMeasurementField('مساحة الأرض', 'land_area', 'متر مربع',
                  icon: Icons.landscape_rounded),
              _buildMeasurementField('مساحة البناء', 'build_area', 'متر مربع',
                  icon: Icons.square_foot_rounded),
              _buildRadioChips('هل يوجد ترس؟', 'has_terrace', ['نعم', 'لا'],
                  icon: Icons.deck_rounded),
              if (_dynamicData['has_terrace'] == 'نعم')
                _buildMeasurementField('مساحة الترس', 'terrace_area', 'متر مربع',
                    icon: Icons.square_foot_rounded),
              _buildRadioChips('تصنيف الفيلا', 'villa_type',
                  ['متلاصقة', 'مستقلة', 'روف', 'تاون هاوس']),
              _buildRadioChips(
                  'عدد الطوابق', 'floors', ['طابق واحد', 'طابقين', 'ثلاثة+']),
              const SizedBox(height: 16),
              _buildCheckboxGroup('إضافات الفيلا', 'features', [
                'مسبح',
                'جاكوزي',
                'سينما منزلية',
                'نظام أمني',
                'بئر ماء',
                'طاقة شمسية'
              ]),
            ],
          ),
        ),
        if (widget.transactionType == 'عقارات للإيجار')
          _buildRentalDetailsForm(),
      ],
    );
  }

  Widget _buildCommercialForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('تفاصيل العقار',
                  icon: Icons.apartment_rounded),
              _buildMeasurementField('مساحة البناء', 'area', 'متر مربع',
                  icon: Icons.square_foot_rounded),
              _buildRadioChips('حالة الفرش', 'furnishing',
                  ['مفروشة', 'غير مفروشة', 'مفروش جزئياً'],
                  icon: Icons.chair_rounded),
              if (widget.transactionType == 'عقارات للإيجار')
                _buildCheckboxGroup('مدة الإيجار', 'rent_duration',
                    ['يومي', 'أسبوعي', 'شهري', 'كل 3 أشهر', 'كل أربع أشهر', 'كل 5 أشهر', 'كل 6 أشهر', 'سنوي'],
                    icon: Icons.calendar_month_rounded),
              _buildRadioChips(
                  'الطابق',
                  'floor',
                  [
                    'طابق التسوية',
                    'طابق شبه أرضي',
                    'الطابق الأرضي',
                    '1',
                    '2',
                    '3',
                    '4',
                    '5',
                    '6',
                    '7',
                    'طابق أخير',
                    'روف',
                    'طابق أخير مع روف',
                  ],
                  icon: Icons.layers_rounded),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('المزايا والتفاصيل الإضافية',
                  icon: Icons.star_rounded),
              _buildCheckboxGroup('التفاصيل الداخلية', 'interior_details', [
                'غرفة أساسية',
                'مطبخ',
                'حمام',
                'غرفة استقبال',
                'غرفة اجتماعات',
                'مستودع داخلي',
                'ديكورات',
                'تأسيس شبكات'
              ]),
              _buildCheckboxGroup('التفاصيل الخارجية', 'exterior_details', [
                'يوجد مواقف سيارات',
                'واجهة زجاجية',
                'مدخل مستقل',
                'لوحة إعلانية خارجية',
                'كاميرات مراقبة خارجية',
                'حراسة / أمن'
              ]),
              _buildCheckboxGroup('مواقع قريبة', 'nearby', [
                'بنك / صراف آلي',
                'دراي كلين',
                'سوبر ماركت',
                'صالة رياضية / جيم',
                'صيدلية',
                'محطة باصات',
                'مدرسة',
                'مستشفى',
                'مسجد',
                'مطعم'
              ]),
              if (widget.transactionType == 'عقارات للإيجار') ...[
                const SizedBox(height: 16),
                _buildRadioChips(
                    'الخلو', 'key_money', ['يوجد خلو', 'بدون خلو']),
                if (_dynamicData['key_money'] == 'يوجد خلو')
                  _buildMeasurementField('قيمة الخلو', 'key_money_value', 'دينار',
                      icon: Icons.payments_rounded),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChaletForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('تفاصيل الشاليه المزرعة',
                  icon: Icons.holiday_village_rounded),
              _buildRadioChips(
                  'المدة', 'duration', ['إيجار يومي (بدون مبيت)', 'مبيت']),
              const SizedBox(height: 16),
              _buildCheckboxGroup('المرافق', 'facilities', [
                'مسبح مفلطر',
                'مسبح مدفأ',
                'ألعاب أطفال',
                'مساحة شواء',
                'ملعب كرة قدم/طائرة',
                'جلسات خارجية'
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCarForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('1. المعلومات الأساسية',
                  icon: Icons.info_outline_rounded),
              _buildBottomSheetSelector(
                  'سنة الصنع',
                  'year',
                  List.generate(
                          40, (i) => (DateTime.now().year + 1 - i).toString())
                      .toList()
                    ..add('أقدم'),
                  icon: Icons.date_range_rounded),
              _buildRadioChips('الحالة', 'condition', ['جديد', 'مستعمل'],
                  icon: Icons.verified_rounded),
              if (_dynamicData['condition'] == 'مستعمل')
                _buildMeasurementField(
                    'المسافة المقطوعة (العداد)', 'mileage', 'كم\u200e',
                    icon: Icons.add_road_rounded),
              _buildBottomSheetSelector(
                  'سعة المحرك (CC)',
                  'engine_capacity',
                  [
                    '800',
                    '1000',
                    '1200',
                    '1300',
                    '1400',
                    '1500',
                    '1600',
                    '1800',
                    '2000',
                    '2200',
                    '2400',
                    '2500',
                    '2700',
                    '2800',
                    '3000',
                    '3200',
                    '3300',
                    '3500',
                    '3600',
                    '3800',
                    '4000',
                    '4400',
                    '4600',
                    '4800',
                    '5000',
                    '5700',
                    '6000',
                    'أكبر من 6000',
                    'غير محدد (كهربائي)'
                  ],
                  icon: Icons.speed_rounded,
                  isRequired: false),
              if (_dynamicData['condition'] != 'جديد')
                _buildBottomSheetSelector(
                    'عدد الملاك السابقين',
                    'previous_owners',
                    ['0 (أنا المالك الأول)', '1', '2', '3', '4 أو أكثر'],
                    icon: Icons.people_outline_rounded,
                    isRequired: false),
              _buildRadioChips('نوع ناقل الحركة', 'transmission',
                  ['اوتوماتيك', 'يدوي - عادي'],
                  icon: Icons.settings_rounded),
              _buildRadioChips(
                  'نوع الوقود',
                  'fuel',
                  [
                    'بنزين',
                    'ديزل',
                    'كهربائي',
                    'مايلد هايبرد',
                    'هايبرد',
                    'هايبرد - Plug-in'
                  ],
                  icon: Icons.local_gas_station_rounded),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('2. المواصفات الإقليمية',
                  icon: Icons.public_rounded),
              _buildRadioChips('المصدر', 'regional_specs', [
                'خليجية (GCC)',
                'أمريكية',
                'أوروبية',
                'يابانية',
                'كورية',
                'صينية',
                'مواصفات أخرى'
              ]),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('3. المواصفات الداخلية',
                  icon: Icons.airline_seat_recline_normal_rounded),
              _buildCheckboxGroup(
                  'أنظمة الراحة والمقاعد', 'interior_features_1', [
                'تكييف يدوي',
                'تكييف إلكتروني',
                'مقاعد جلد',
                'مقاعد مخمل',
                'تحكم مقاعد كهرباء',
                'ذاكرة مقاعد',
                'كراسي مدفأة',
                'مقاعد مبردة',
                'مقعد خلفي كهربائي',
                'تحكم مقود',
                'مقود مدفأ'
              ]),
              _buildCheckboxGroup(
                  'الزجاج والإكسسوارات الداخلية', 'interior_features_2', [
                'زجاج كهربائي',
                'سنترلوك',
                'نظام إنذار',
                'فتحة سقف',
                'فتحة بانوراما',
                'نظام صوتي (AUX / USB / CD)'
              ]),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('4. المواصفات الخارجية',
                  icon: Icons.directions_car_rounded),
              _buildCheckboxGroup('الإنارة والرؤية', 'exterior_lighting', [
                'أنوار نهارية (DRL)',
                'مصابيح ليد (LED)',
                'مصابيح زينون',
                'كشافات ضباب'
              ]),
              _buildCheckboxGroup(
                  'الهيكل والإضافات الخارجية', 'exterior_addons', [
                'حساسات أمامية',
                'حساسات خلفية',
                'دخول بدون مفتاح (بصمة)',
                'مرايا كهربائية',
                'مرايا قابلة للطي كهربائياً',
                'إطار احتياطي',
                'نسخة رياضية (Body Kit)',
                'هوك خلفي (للسحب)'
              ]),
              _buildBottomSheetSelector('قياس الجنط', 'rims_size',
                  ['12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', 'أخرى'],
                  icon: Icons.adjust_rounded, isRequired: false),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('5. المواصفات التقنية وأنظمة المساعدة',
                  icon: Icons.memory_rounded),
              _buildCheckboxGroup('الترفيه والاتصال', 'tech_entertainment', [
                'شاشة لمس',
                'شاشة وسائط',
                'أبل كار بلاي',
                'أندرويد أوتو',
                'بلوتوث',
                'أوامر صوتية'
              ]),
              _buildCheckboxGroup('القيادة والتحكم', 'tech_driving', [
                'مثبت سرعة',
                'رادار',
                'تشغيل عن بعد',
                'نظام ملاحة (GPS)',
                'دفلوك (Diff-lock)',
                'نظام تعليق رياضي'
              ]),
              _buildCheckboxGroup('الأمان والسلامة', 'tech_safety', [
                'أكياس هوائية',
                'فرامل ABS',
                'مانع انزلاق',
                'حساس ضغط الاطارات',
                'قفل الباب تلقائي'
              ]),
              _buildCheckboxGroup('الرؤية والأنظمة المتقدمة', 'tech_advanced', [
                'كاميرا خلفية',
                'كاميرا 360 درجة',
                'تنبيه الاصطدام الأمامي',
                'تنبيه النقاط العمياء',
                'تنبيه مغادرة المسار',
                'مساعد الاصطفاف',
                'بروجكتر (HUD)'
              ]),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('6. الهيكل والشكل',
                  icon: Icons.invert_colors_rounded),
              _buildRadioChips('نوع الهيكل', 'body_type', [
                'اس يو في',
                'صالون - سيدان',
                'بيك اب',
                'هاتشباك',
                'كوبيه',
                'كشف',
                'باص - فان',
                'شاحنة'
              ]),
              _buildRadioChips('عدد المقاعد', 'seats_count',
                  ['2', '4', '5', '7', '8', 'أخرى']),
              (() {
                final colorsMap = {
                  'أبيض': Colors.white,
                  'أحمر': Colors.red,
                  'أخضر': Colors.green,
                  'أزرق': Colors.blue,
                  'أزرق فاتح': Colors.lightBlue.shade300,
                  'أسمنتي': const Color(0xFF888A85),
                  'أسود': Colors.black,
                  'أصفر': Colors.yellow,
                  'بترولي': const Color(0xFF005F69),
                  'برتقالي': Colors.orange,
                  'برونزي': const Color(0xFFCD7F32),
                  'بنفسجي': Colors.purple,
                  'بني': Colors.brown,
                  'بيج': const Color(0xFFF5F5DC),
                  'تان': const Color(0xFFD2B48C),
                  'تركواز': const Color(0xFF40E0D0),
                  'خمري': const Color(0xFF800020),
                  'ذهبي': const Color(0xFFFFD700),
                  'رمادي': Colors.grey,
                  'زهري': Colors.pink.shade300,
                  'زيتي': const Color(0xFF556B2F),
                  'فضي': const Color(0xFFC0C0C0),
                  'فيراني': const Color(0xFF708090),
                  'كحلي': const Color(0xFF000080),
                };

                Widget colorBuilder(String name) {
                  final color = colorsMap[name] ?? Colors.transparent;
                  return Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.grey.shade300, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    _buildBottomSheetSelector('اللون الخارجي', 'exterior_color',
                        colorsMap.keys.toList(),
                        icon: Icons.format_paint_rounded,
                        leadingBuilder: colorBuilder),
                    _buildBottomSheetSelector('اللون الداخلي', 'interior_color',
                        colorsMap.keys.toList(),
                        icon: Icons.format_color_fill_rounded,
                        leadingBuilder: colorBuilder),
                  ],
                );
              })(),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('7. الوضع القانوني والإداري',
                  icon: Icons.gavel_rounded),
              _buildRadioChips(
                  'الجمرك', 'customs_status', ['مجمركة', 'غير مجمركة']),
              _buildRadioChips(
                  'الترخيص', 'registration_status', ['مرخصة', 'غير مرخصة']),
              _buildRadioChips('التأمين', 'insurance_status',
                  ['تأمين إلزامي', 'تأمين شامل', 'غير مؤمّنة']),
              _buildBottomSheetSelector(
                  'فحص السيارة',
                  'inspection_result',
                  [
                    '4 جيد (فحص كامل)',
                    '3 جيد',
                    '2 جيد',
                    '1 جيد',
                    'قصعات / دقات',
                    'خالي قص قلبان',
                    'مضروب',
                    'غير مفحوصة'
                  ],
                  icon: Icons.fact_check_outlined,
                  isRequired: false),
              _buildDatePickerField('تاريخ فحص السيارة', 'inspection_date',
                  icon: Icons.assignment_turned_in_rounded, isRequired: false),
              _buildTextField('نتيجة وتقييم AutoScore', 'autoscore_result',
                  icon: Icons.workspace_premium_rounded, isRequired: false),
              _buildDatePickerField('تاريخ تقييم AutoScore', 'autoscore_date',
                  icon: Icons.assignment_turned_in_rounded, isRequired: false),
              _buildTextField('رقم الشاصي (VIN)', 'vin_number',
                  icon: Icons.pin_rounded, isRequired: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMotorcycleForm() {
    final currentYear = DateTime.now().year;
    final yearsList = List.generate(currentYear - 1970 + 1, (index) => (currentYear - index).toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('المواصفات الفنية', icon: Icons.engineering_rounded),
              _buildBottomSheetSelector('سنة الصنع', 'year', yearsList, 
                icon: Icons.calendar_today_rounded, 
                leadingBuilder: (val) => Icon(Icons.history_rounded, color: Colors.grey.shade400, size: 20)
              ),
              _buildRadioChips('سعة المحرك (CC)', 'engine_capacity', [
                'أقل من 50', '50 - 125', '150 - 250', '300 - 450', '500 - 750', '800 - 1000', 'أكثر من 1000'
              ], icon: Icons.speed_rounded),
              _buildRadioChips('ناقل الحركة', 'transmission', [
                'عادي (Manual)', 'أوتوماتيك (Automatic)', 'شبه أوتوماتيك (Semi-Auto)'
              ], icon: Icons.settings_rounded),
              _buildRadioChips('عدد الأسطوانات', 'cylinders', [
                '1 (Singe Cylinder)', '2 (Twin)', '3 (Triple)', '4 (Inline 4/V4)', '6 فأكثر'
              ], icon: Icons.straighten_rounded),
              _buildRadioChips('نظام التبريد', 'cooling_system', [
                'تبريد هواء', 'تبريد ماء (رديتر)', 'تبريد زيت', 'مختلط'
              ], icon: Icons.ac_unit_rounded),
              _buildRadioChips('نوع الوقود', 'fuel_type', [
                'بنزين', 'كهرباء', 'هجين'
              ], icon: Icons.local_gas_station_rounded),
              _buildRadioChips('نظام الدفع', 'final_drive', [
                'جنزير (Chain)', 'قشاط (Belt)', 'شفت (Shaft)'
              ], icon: Icons.swap_calls_rounded),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('حالة الدراجة والمسافة', icon: Icons.motorcycle_rounded),
              _buildRadioChips('الحالة', 'condition', ['جديد', 'مستعمل'], icon: Icons.stars_rounded),
              if (_dynamicData['condition'] == 'مستعمل')
                _buildMeasurementField('المسافة المقطوعة', 'mileage', 'كم', icon: Icons.add_road_rounded),
              (() {
                final colorsMap = {
                  'أبيض': Colors.white,
                  'أسود': Colors.black,
                  'أحمر': Colors.red,
                  'أزرق': Colors.blue,
                  'أخضر': Colors.green,
                  'أصفر': Colors.yellow,
                  'برتقالي': Colors.orange,
                  'بنفسجي': Colors.purple,
                  'بني': Colors.brown,
                  'بيج': const Color(0xFFF5F5DC),
                  'تان': const Color(0xFFD2B48C),
                  'تركواز': const Color(0xFF40E0D0),
                  'خمري': const Color(0xFF800020),
                  'ذهبي': const Color(0xFFFFD700),
                  'رمادي': Colors.grey,
                  'زهري': Colors.pink.shade300,
                  'زيتي': const Color(0xFF556B2F),
                  'فضي': const Color(0xFFC0C0C0),
                  'فيراني': const Color(0xFF708090),
                  'كحلي': const Color(0xFF000080),
                  'ألوان متعددة': Colors.transparent,
                };

                Widget colorBuilder(String name) {
                  final color = colorsMap[name] ?? Colors.transparent;
                  return Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.grey.shade300, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                  );
                }

                return _buildBottomSheetSelector('اللون', 'color',
                    colorsMap.keys.toList(),
                    icon: Icons.color_lens_rounded,
                    leadingBuilder: colorBuilder);
              })(),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('الفحص الفني والجمالي', icon: Icons.health_and_safety_rounded),
              _buildRadioChips('حالة المحرك', 'engine_condition', [
                'ممتاز', 'جيد', 'يحتاج صيانة', 'لا يعمل'
              ], icon: Icons.build_circle_rounded),
              _buildRadioChips('حالة الهيكل (الشاصي/الفريم)', 'frame_condition', [
                'ممتاز (سليم تماماً)', 'جيد (خدوش بسيطة)', 'يوجد أضرار خفيفة (لحام بسيط)', 'يوجد أضرار قوية (قص أو ضربة شاصي)'
              ], icon: Icons.architecture_rounded),
              _buildRadioChips('حالة الطلاء', 'paint_condition', [
                'أصلي (وكالة)', 'معاد رش (تجميلي)', 'بحاجة دهان'
              ], icon: Icons.format_paint_rounded),
              _buildRadioChips('حالة الإطارات', 'tires_condition', [
                'جديدة', 'جيدة', 'بحاجة تغيير'
              ], icon: Icons.tire_repair_rounded),
              _buildRadioChips('حالة البطارية', 'battery_condition', [
                'جديدة', 'جيدة', 'ضعيفة'
              ], icon: Icons.battery_charging_full_rounded),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('الأمان والإضافات', icon: Icons.shield_rounded),
              _buildRadioChips('نظام الفرامل', 'brakes_system', [
                'عادي', 'ABS (نظام منع انغلاق المكابح)', 'CBS (نظام الفرامل الموحد)'
              ], icon: Icons.car_crash_rounded),
              _buildCheckboxGroup('الإضافات المتوفرة', 'accessories', [
                'نظام حماية (Crash Bars)', 'صناديق خلفية/جانبية (Panniers/Top Box)', 'نظام تدفئة مقابض', 'شاشة معلومات', 'تعديلات أداء (Exhaust/Power Commander)'
              ], icon: Icons.add_circle_outline_rounded),
            ],
          ),
        ),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('الوضع القانوني والملكية', icon: Icons.gavel_rounded),
              _buildRadioChips('حالة الترخيص', 'license_status', [
                'مرخصة', 'منتهية', 'غير مرخصة (جمرك جديد)'
              ], icon: Icons.verified_user_rounded),
              _buildDatePickerField('تاريخ انتهاء الترخيص', 'license_expiry', icon: Icons.event_available_rounded, isRequired: false),
              if (_dynamicData['condition'] == 'مستعمل')
                _buildBottomSheetSelector('عدد الملاك السابقين', 'previous_owners', [
                  '0 (المالك الأول)', '1', '2', '3', '4', '5 فأكثر'
                ], icon: Icons.people_alt_rounded),
              _buildRadioChips('حالة الحوادث', 'accident_history', [
                'خالية من الحوادث', 'حادث بسيط (تزليق/سقوط واقفه)', 'حادث متوسط', 'حادث قوي'
              ], icon: Icons.warning_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutoPartsForm() {
    final catId = widget.selectedLeafCategory.id?.toString() ?? '';
    
    // Group detection handling exact lengths to avoid collisions like 1041 vs 10410
    bool isEngine = catId == '1041' || (catId.startsWith('1041') && catId.length == 6);
    bool isCooling = catId == '10410' || (catId.startsWith('10410') && catId.length == 7);
    bool isFuel = catId == '10411' || (catId.startsWith('10411') && catId.length == 7);
    bool isGroup1EngineFuelCooling = isEngine || isCooling || isFuel;

    bool isTransmission = catId == '1042' || catId.startsWith('1042');
    bool isBodyExterior = catId == '1045' || catId.startsWith('1045') || catId == '1048' || catId.startsWith('1048') || catId == '10417' || catId.startsWith('10417');
    bool isElectrical = catId == '1046' || catId.startsWith('1046') || catId == '10412' || catId.startsWith('10412');
    bool isTiresRims = catId == '10415' || catId.startsWith('10415');
    bool isOilsFluids = catId == '10413' || catId.startsWith('10413');
    bool isInterior = catId == '1049' || catId.startsWith('1049') || catId == '10416' || catId.startsWith('10416');
    bool isPerformanceSafety = catId == '10414' || catId.startsWith('10414') || catId == '10418' || catId.startsWith('10418') || catId == '10419' || catId.startsWith('10419');

    // Generating Years List dynamically like the cars section
    final currentYear = DateTime.now().year;
    final yearsList = List.generate(currentYear - 1970 + 1, (index) => (currentYear - index).toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Mandatory General Section
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('المعلومات الأساسية', icon: Icons.settings_rounded),
              _buildRadioChips('الحالة', 'condition', [
                'جديد (وكالة)', 'مستعمل (نظيف)', 'مستعمل (يحتاج صيانة)', 'مجدد (Refurbished)', 'قطع / سكراب'
              ]),
              _buildBottomSheetSelector('نوع القطعة', 'part_type', [
                'أصلية (OEM)', 'تجاري نخب أول', 'تجاري عادي', 'مقلد (Copy)', 'معدلة / Performance'
              ], icon: Icons.category_rounded),
              _buildTextField('رقم القطعة (OEM/Serial)', 'part_number', icon: Icons.numbers_rounded, isRequired: false),
              _buildBottomSheetSelector('بلد المنشأ', 'origin_country', [
                'اليابان', 'ألمانيا', 'أمريكا', 'كوريا', 'الصين', 'أوروبا', 'أخرى'
              ], icon: Icons.public_rounded),
              _buildBottomSheetSelector('الضمان', 'warranty', [
                'بدون ضمان', 'تجربة (Check)', 'أسبوع', 'شهر', '3 أشهر', '6 أشهر', 'سنة', 'أكثر'
              ], icon: Icons.verified_user_rounded),
              _buildTextField('الكمية المتوفرة', 'quantity', keyboardType: TextInputType.number, icon: Icons.inventory_2_rounded, isRequired: false),
              _buildRadioChips('حالة التغليف', 'packaging', ['مغلف', 'بدون تغليف']),
            ],
          ),
        ),

        // 2. Compatibility Section
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('التوافقية (السيارات المطابقة)', icon: Icons.directions_car_rounded),
              _buildTextField('ماركة السيارة المتوافقة', 'compatible_brand', icon: Icons.directions_car_filled_rounded),
              _buildTextField('موديل السيارة المتوافقة', 'compatible_model', icon: Icons.model_training_rounded),
              _buildBottomSheetSelector('سنوات التوافق (من - إلى)', 'compatible_years', yearsList, icon: Icons.calendar_month_rounded),
              _buildTextField('جيل السيارة (اختياري)', 'compatible_generation', icon: Icons.format_list_numbered_rounded, isRequired: false),
            ],
          ),
        ),

        // Subcategory Specifics
        if (isGroup1EngineFuelCooling)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('المحرك والوقود والتبريد', icon: Icons.engineering_rounded),
                _buildBottomSheetSelector('سعة المحرك المطابقة (cc)', 'engine_capacity_comp', [
                  'أقل من 1000', '1000 - 1500', '1600 - 2000', '2100 - 3000', '3100 - 4000', '4100 - 5000', 'أكثر من 5000'
                ], icon: Icons.local_gas_station_rounded),
                _buildRadioChips('نوع الوقود', 'fuel_type_comp', ['بنزين', 'ديزل', 'هايبرد', 'كهرباء']),
                _buildBottomSheetSelector('عدد الأسطوانات', 'cylinders_comp', [
                  '1', '2', '3', '4', '6', '8', '10', '12'
                ], icon: Icons.format_list_numbered_rounded),
                _buildTextField('كود المحرك', 'engine_code', icon: Icons.code_rounded, isRequired: false),
                _buildRadioChips('نوع السحب', 'aspiration', ['طبيعي', 'تيربو', 'سوبر تشارج']),
                _buildRadioChips('المادة', 'block_material', ['ألمنيوم', 'حديد', 'خليط']),
                _buildRadioChips('نوع التبريد', 'cooling_type', ['ماء', 'هواء', 'زيت']),
              ],
            ),
          ),

        if (isTransmission)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('ناقل الحركة والدفع', icon: Icons.account_tree_rounded),
                _buildBottomSheetSelector('نوع القير', 'gearbox_type', [
                  'عادي', 'أوتوماتيك', 'CVT', 'DSG', 'Tiptronic'
                ], icon: Icons.settings_rounded),
                _buildBottomSheetSelector('عدد الغيارات', 'gear_count', [
                  '4', '5', '6', '7', '8', '9', '10'
                ], icon: Icons.format_list_numbered_rounded),
                _buildRadioChips('نظام الدفع', 'drivetrain', ['FWD', 'RWD', 'AWD', '4WD']),
                _buildRadioChips('نوع القابض', 'clutch_type', ['جاف', 'رطب']),
                _buildTextField('كود القير', 'gearbox_code', icon: Icons.code_rounded, isRequired: false),
              ],
            ),
          ),

        if (isBodyExterior)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('هيكل وخارجي', icon: Icons.car_repair_rounded),
                _buildBottomSheetSelector('الإتجاه / الجهة', 'part_position', [
                  'أمامي', 'خلفي', 'يمين', 'يسار', 'علوي', 'سفلي'
                ], icon: Icons.compare_arrows_rounded),
                _buildTextField('اللون', 'part_color', icon: Icons.color_lens_rounded, isRequired: false),
                _buildBottomSheetSelector('مادة الصنع', 'part_material', [
                  'معدن', 'بلاستيك', 'كربون فايبر', 'فايبر جلاس', 'ألمنيوم'
                ], icon: Icons.category_rounded),
                _buildRadioChips('الحالة المظهرية', 'visual_condition', [
                  'وكالة', 'مخدوش', 'مصبوغ', 'بحاجة إصلاح'
                ]),
                _buildCheckboxGroup('ميزات إضافية', 'exterior_features', [
                  'كهرباء', 'طي كهربائي', 'تدفئة', 'إشارة', 'Blind Spot', 'LED', 'Xenon'
                ], icon: Icons.add_circle_outline_rounded),
              ],
            ),
          ),

        if (isElectrical)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('الكهرباء والإلكترونيات', icon: Icons.electrical_services_rounded),
                _buildRadioChips('الجهد الكهربائي', 'voltage', ['12V', '24V']),
                _buildRadioChips('نوع النظام', 'system_type', ['Analog', 'Digital']),
                _buildBottomSheetSelector('نظام التشغيل (للشاشات)', 'screen_os', [
                  'Android', 'Apple CarPlay', 'Android Auto', 'نظام وكالة'
                ], icon: Icons.system_update_rounded),
                _buildBottomSheetSelector('حجم الشاشة (إنش)', 'screen_size', [
                  '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15'
                ], icon: Icons.tv_rounded),
                _buildTextField('القدرة (Watt/Ampere)', 'electrical_power', icon: Icons.bolt_rounded, isRequired: false),
                _buildRadioChips('نوع التوصيل', 'connection_type', ['سلكي', 'لاسلكي']),
              ],
            ),
          ),

        if (isTiresRims)
          _buildCard(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 _buildSectionHeader('الإطارات والجنطات', icon: Icons.tire_repair_rounded),
                 _buildBottomSheetSelector('مقاس القطر (إنش)', 'rim_diameter', [
                   '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '24', '26'
                 ], icon: Icons.pie_chart_rounded),
                 _buildTextField('عرض الإطار', 'tire_width', keyboardType: TextInputType.number, icon: Icons.settings_ethernet_rounded, isRequired: false),
                 _buildTextField('نسبة الارتفاع', 'tire_aspect_ratio', keyboardType: TextInputType.number, icon: Icons.height_rounded, isRequired: false),
                 _buildTextField('سنة التصنيع والتاريخ (DOT)', 'dot_date', icon: Icons.date_range_rounded, isRequired: false),
                 _buildBottomSheetSelector('عدد البراغي (PCD)', 'pcd', [
                   '4x100', '4x114.3', '5x100', '5x112', '5x114.3', '5x120', '5x127', '5x139.7', '6x139.7', 'أخرى'
                 ], icon: Icons.settings_overscan_rounded),
                 _buildBottomSheetSelector('نوع الإطار', 'tire_type', [
                   'صيفي', 'شتوي', 'جميع الفصول', 'رياضي', 'طرق وعرة'
                 ], icon: Icons.category_rounded),
                 _buildRadioChips('حالة المسنن (للمستعمل)', 'tread_condition', [
                   'جديد', 'شبه جديد', 'مستعمل'
                 ]),
               ],
             ),
          ),

        if (isOilsFluids)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('الزيوت والكيماويات', icon: Icons.oil_barrel_rounded),
                _buildBottomSheetSelector('اللزوجة', 'oil_viscosity', [
                  '0W-20', '5W-20', '5W-30', '5W-40', '10W-30', '10W-40', '15W-40', '20W-50', 'أخرى'
                ], icon: Icons.water_drop_rounded),
                _buildBottomSheetSelector('النوع', 'oil_type', [
                  'تخليقي كامل', 'نصف تخليقي', 'معدني'
                ], icon: Icons.opacity_rounded),
                _buildBottomSheetSelector('الحجم', 'volume', [
                  '1 لتر', '4 لتر', '5 لتر', '20 لتر', 'برميل'
                ], icon: Icons.scale_rounded),
                _buildBottomSheetSelector('معيار الجودة', 'oil_standard', [
                   'API', 'ACEA', 'DOT3', 'DOT4', 'DOT5', 'تصنيف وكالة'
                ], icon: Icons.verified_user_rounded),
              ],
            ),
          ),

        if (isInterior)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 _buildSectionHeader('الداخلية والإكسسوارات', icon: Icons.airline_seat_recline_normal_rounded),
                 _buildBottomSheetSelector('المادة الخام', 'interior_material', [
                   'جلد', 'قماش', 'مخمل', 'الكانتارا', 'بلاستيك', 'كربون فايبر', 'خشب'
                 ], icon: Icons.category_rounded),
                 _buildTextField('اللون الداخلي', 'interior_part_color', icon: Icons.color_lens_rounded, isRequired: false),
                 _buildRadioChips('التوافقية', 'surface_compatibility', ['عالمي (Universal)', 'مخصص']),
                 _buildTextField('عدد القطع', 'pieces_count', keyboardType: TextInputType.number, icon: Icons.format_list_numbered_rounded, isRequired: false),
              ],
            ),
          ),

        if (isPerformanceSafety)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 _buildSectionHeader('الأداء، السلامة، والصيانة', icon: Icons.speed_rounded),
                 _buildCheckboxGroup('الشهادات / الاعتمادات', 'certification', [
                   'ISO', 'CE', 'OEM Approved'
                 ], icon: Icons.verified_rounded),
                 _buildBottomSheetSelector('نوع الطاقة (للمعدات)', 'power_source', [
                   'يدوي', 'كهرباء', 'بطارية', 'هواء'
                 ], icon: Icons.power_rounded),
                 _buildRadioChips('نطاق الاستخدام', 'usage_scale', ['منزلي', 'ورش', 'صناعي']),
                 _buildBottomSheetSelector('مرحلة الأداء', 'stage_rating', [
                   'Stage 1', 'Stage 2', 'Stage 3'
                 ], icon: Icons.trending_up_rounded),
                 _buildRadioChips('درجة الأمان', 'security_grade', ['عالي', 'متوسط', 'أساسي']),
                 _buildCheckboxGroup('توافق الأنظمة', 'system_compatibility', [
                   'ABS', 'ESP', 'Airbag', 'OBD2'
                 ], icon: Icons.check_circle_outline_rounded),
              ],
            ),
          ),

        // Global Extras (Always present for Auto Parts)
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('تفاصيل إضافية احترافية', icon: Icons.more_horiz_rounded),
              _buildRadioChips('الحالة التشغيلية', 'functioning_status', [
                'تعمل بالكامل', 'تعمل جزئياً', 'لا تعمل'
              ]),
              _buildBottomSheetSelector('مدة الاستخدام السابق', 'usage_duration', [
                'لم تستخدم', 'أقل من شهر', '1 - 6 أشهر', '6 أشهر - سنة', 'أكثر من سنة'
              ], icon: Icons.timer_rounded),
              _buildTextField('سبب البيع', 'reason_for_sale', icon: Icons.info_outline_rounded, isRequired: false),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Divider(),
              ),

              _buildRadioChips('توفر خدمة التركيب', 'installation_available', ['متوفر', 'غير متوفر']),
              if (_dynamicData['installation_available'] == 'متوفر')
                _buildTextField('تكلفة التركيب التقريبية', 'installation_cost', keyboardType: TextInputType.number, icon: Icons.attach_money_rounded, isRequired: false),
                
              const SizedBox(height: 16),
              _buildRadioChips('توفر خدمة الشحن', 'shipping_available', ['داخل المدينة', 'داخل الدولة', 'غير متوفر']),
              if (_dynamicData['shipping_available'] != null && _dynamicData['shipping_available'] != 'غير متوفر')
                _buildTextField('المدة المتوقعة للشحن', 'shipping_duration', icon: Icons.local_shipping_rounded, isRequired: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLicensePlatesForm() {
    final catId = widget.selectedLeafCategory.id?.toString() ?? '';
    final isMotorcycle = catId == '1062' || _dynamicData['vehicle_type'] == 'دراجة نارية';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('المعلومات الأساسية', icon: Icons.looks_one_rounded),
              _buildTextField('الرقم', 'plate_number', keyboardType: TextInputType.text, icon: Icons.tag_rounded),
              _buildTextField('الترميز / الفئة', 'plate_code', keyboardType: TextInputType.text, icon: Icons.api_rounded),
              _buildBottomSheetSelector('نوع المركبة', 'vehicle_type', [
                'سيارة خصوصي', 'دراجة نارية', 'شحن / نقل', 'عمومي', 'حكومي', 'دبلوماسي', 'مؤقت'
              ], icon: Icons.directions_car_rounded),
              _buildRadioChips('عدد الخانات', 'digits_count', [
                '1 خانة', '2 خانات', '3 خانات', '4 خانات', '5 خانات', '6 خانات', 'أكثر'
              ]),
            ],
          ),
        ),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildSectionHeader('الأنماط الحسابية والتميز', icon: Icons.calculate_rounded),
               _buildBottomSheetSelector('نوع التسلسل', 'sequence_type', [
                 'متزايد (1234)', 'متناقص (4321)', 'زوجي (2468)', 'فردي (1357)'
               ], icon: Icons.sort_rounded, isRequired: false),
               _buildBottomSheetSelector('نمط التكرار', 'repetition_pattern', [
                 'تكرار كامل (1111)', 'تكرار مزدوج (1122)', 'تكرار ثلاثي (111)', 'تكرار جزئي'
               ], icon: Icons.repeat_rounded, isRequired: false),
               _buildBottomSheetSelector('التناظر', 'symmetry_type', [
                 'متناظر كامل (1221)', 'أطراف متشابهة (50005)', 'انعكاسي'
               ], icon: Icons.flip_rounded, isRequired: false),
               _buildBottomSheetSelector('أنماط إضافية', 'additional_patterns', [
                 'مرايا (1212)', 'دبل (5566)', 'أرقام متقاربة (1235)', 'أرقام متباعدة'
               ], icon: Icons.star_border_rounded, isRequired: false),
            ],
          ),
        ),

        if (isMotorcycle)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('لوحات الدراجات النارية', icon: Icons.two_wheeler_rounded),
                _buildBottomSheetSelector('نمط التميز', 'special_pattern', [
                  'ثنائي', 'ثلاثي', 'متسلسل', 'مكرر', 'مميز', 'نادر'
                ], icon: Icons.stars_rounded, isRequired: false),
              ],
            ),
          ),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('حالة اللوحة والمخالفات', icon: Icons.gavel_rounded),
              _buildRadioChips('حالة اللوحة', 'plate_condition', [
                'جديدة', 'مستخدمة', 'بحالة ممتازة', 'مخدوشة'
              ]),
              _buildRadioChips('وجود مخالفات', 'fines_exist', ['لا يوجد', 'يوجد']),
              if (_dynamicData['fines_exist'] == 'يوجد')
                _buildTextField('قيمة المخالفات', 'fines_value', keyboardType: TextInputType.number, icon: Icons.attach_money_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPetsForm() {
    final catId = widget.selectedLeafCategory.id?.toString() ?? '';
    
    // Living pet typically falls into 1001, 1002, 1003, 1005, 1006. Or just check if not 1004, 1007, 1008, 1009, 1010.
    final isLivingPet = catId.startsWith('1001') || catId.startsWith('1002') || catId.startsWith('1003') || catId.startsWith('1005') || catId.startsWith('1006') || catId == '10';
    final isCat = catId.startsWith('1002');
    final isBird = catId.startsWith('1003');
    final isFish = catId.startsWith('1004');
    final isFood = catId.startsWith('1007');
    final isCare = catId.startsWith('1008') || catId.startsWith('1009') || catId.startsWith('1010');

    final condition = _dynamicData['condition'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('المعلومات الأساسية', icon: Icons.info_outline_rounded),
              _buildRadioChips('الغرض من الإعلان', 'ad_purpose', [
                'للبيع (For Sale)', 'للتبني - بدون مقابل', 'للتزاوج (Stud Service)', 'مطلوب (Wanted)'
              ]),
              _buildRadioChips('نوع المعلن', 'seller_type', ['فرد', 'محل / مزرعة']),
              if (!isLivingPet)
                _buildRadioChips('الحالة', 'condition', ['جديد', 'مستعمل']),
            ],
          ),
        ),

        if (isLivingPet)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 _buildSectionHeader('البيانات الحيوية (Living Pet)', icon: Icons.pets_rounded),
                 if (catId.startsWith('1001'))
                   _buildBottomSheetSelector('السلالة', 'pet_breed', const [
                     'آيسلند شيبدوغ - Icelandic Sheepdog', 'أزواخ (إفريقي) - Azawakh', 'أفينبينشر (كلب القرد) - Affenpinscher',
                     'أكيتا أمريكي - American Akita', 'أكيتا إينو (ياباني) - Akita Inu', 'ألاباي (راعي وسط آسيا) - Alabai',
                     'أميركان إسكيمو - American Eskimo Dog', 'أميركان إنجلش كونهاوند - American English Coonhound', 'أميركان بولي - American Bully',
                     'أميركان بيتبول تيرير - American Pit Bull', 'أميركان ستافوردشاير - American Staffordshire', 'أميركان ستافوردشاير - American Staffordshire Terrier',
                     'أميركان فوكس هاوند - American Foxhound', 'أميركان هيرلس - American Hairless Terrier', 'أنابوليان شيبيرد - Anatolian Shepherd',
                     'أوتر هاوند - Otterhound', 'أوسي دودل - Aussiedoodle', 'أولد إنغلش شيبدوغ - Old English Sheepdog',
                     'أيرديل تيرير - Airedale Terrier', 'أيرلش ولف هاوند - Irish Wolfhound', 'إستريلا ماونتن دوغ - Estrela Mountain Dog',
                     'إنجلش توي سبانيل - English Toy Spaniel', 'إنجلش فوكس هاوند - English Foxhound', 'الراعي البولندي - Polish Lowland Sheepdog',
                     'الفهد الكاتاهولي - Catahoula Leopard Dog', 'الكلب الأفغاني - Afghan Hound', 'الكلب الروسي الصغير - Russian Toy',
                     'بابيلون - Papillon', 'باج - Pug', 'بارسون راسل تيرير - Parson Russell Terrier',
                     'باست هاوند - Basset Hound', 'باسينجي - Basenji', 'بافاريان ماونتن هاوند - Bavarian Mountain Hound',
                     'باندوغ - Bandog', 'برنيدودل - Bernedoodle', 'بروسيل جريفون - Brussels Griffon',
                     'بروهولمر - Broholmer', 'بريارد - Briard', 'بريتاني - Brittany',
                     'بريزا كناريو - Presa Canario', 'بكينيز - Pekingese', 'بكينيز إمبراطوري - Imperial Pekingese',
                     'بلاد هاوند - Bloodhound', 'بلاك أند تان كونهاوند - Black and Tan Coonhound', 'بلاك روسيان تيرير - Black Russian Terrier',
                     'بلجيكي تيرفورين - Belgian Tervuren', 'بلو تيك كونهاوند - Bluetick Coonhound', 'بلوت هاوند - Plott Hound',
                     'بوجل - Puggle (Pug + Beagle)', 'بودل (توي) - Poodle (Toy)', 'بودينغو برتغالي - Portuguese Podengo Pequeno',
                     'بوربويل - Boerboel', 'بوردر كولي - Border Collie', 'بوردير تيرير - Border Terrier',
                     'بورزوي - Borzoi', 'بوسطن تيرير - Boston Terrier', 'بوسيرون - Beauceron',
                     'بوغ-بو - Pug-poo', 'بوكسر - Boxer', 'بول تيرير - Bull Terrier',
                     'بول تيرير مصغر - Miniature Bull Terrier', 'بول ماستيف - Bullmastiff', 'بولدوج إنجليزي - Bulldog',
                     'بولدوج إنجليزي - English Bulldog', 'بولدوج فرنسي - French Bulldog', 'بولونيز - Bolognese',
                     'بولي - Puli', 'بوم-تشي - Pom-chi (بوميرانيان + شيواوا)', 'بومسكي - Pomsky (Pomeranian + Husky)',
                     'بومي (هنغاري) - Pumi', 'بوميرانيان - Pomeranian', 'بويكين سبانيل - Boykin Spaniel',
                     'بوينتر - Pointer', 'بوينتر إنجليزي - English Pointer', 'بيت بول (أميركان بيتبول) - Pit Bull',
                     'بيجل - Beagle', 'بيدلينجتون تيرير - Bedlington Terrier', 'بيرجاماسكو شيبدوغ - Bergamasco Sheepdog',
                     'بيرجر بيكارد - Berger Picard', 'بيردد كولي - Bearded Collie', 'بيرنيز ماونتن - Bernese Mountain Dog',
                     'بيرينيه شيبيرد - Pyrenean Shepherd', 'بيشون فريز - Bichon Frise', 'بيمبروك ويلش كورجي - Pembroke Welsh Corgi',
                     'بِيغليير - Beaglier', 'تاي ريدجباك - Thai Ridgeback', 'تريينغ ووكر كونهاوند - Treeing Walker Coonhound',
                     'تشاو تشاو - Chow Chow', 'تشاينيز كريستد - Chinese Crested', 'تشوركي - Chorkie (شيواوا + يوركشاير)',
                     'تشيسابيك باي ريتريفر - Chesapeake Bay Retriever', 'تشيوي - Chiweenie (Chihuahua + Dachshund)', 'توسا إينو - Tosa Inu',
                     'توي فوكس تيرير - Toy Fox Terrier', 'توي مانشستر تيرير - Manchester Terrier (Toy)', 'تيبتان تيرير - Tibetan Terrier',
                     'تيبتان سبانيل - Tibetan Spaniel', 'تيرير أسترالي - Australian Terrier', 'تيرير أيرلندي - Irish Terrier',
                     'جاك راسل تيرير - Jack Russell Terrier', 'جري هاوند - Greyhound', 'جري هاوند إيطالي - Italian Greyhound',
                     'جريت دان - Great Dane', 'جريتر سويس ماونتن - Greater Swiss Mountain Dog', 'جوردون سيتر - Gordon Setter',
                     'جولدن دودل - Goldendoodle (Golden Retriever + Poodle)', 'جولدن ريتريفر - Golden Retriever', 'جيرمن بينشر - German Pinscher',
                     'جيرمن شورتهير بوينتر - German Shorthaired Pointer', 'جيرمن واير هير بوينتر - German Wirehaired Pointer', 'داتش هوند (سجق) - Dachshund',
                     'دالميشن - Dalmatian', 'داندي دينمونت - Dandie Dinmont Terrier', 'دوبرمان بينشر - Doberman Pinscher',
                     'دوج دو بوردو - Dogue de Bordeaux', 'دوجو أرجنتينو - Dogo Argentino', 'رات تيرير - Rat Terrier',
                     'راسل تيرير - Russell Terrier', 'راعي أسترالي - Australian Shepherd', 'راعي ألماني - German Shepherd',
                     'راعي بلجيكي - Belgian Sheepdog', 'راعي قوقازي - Caucasian Shepherd', 'راعي وسط آسيا - Central Asian Shepherd',
                     'روت وايلر - Rottweiler', 'روديسيان ريدجباك - Rhodesian Ridgeback', 'ريد بون كونهاوند - Redbone Coonhound',
                     'زولويتزكوينتلي (الكلب المكسيكي عديم الشعر) - Xoloitzcuintli', 'سامويد - Samoyed', 'سانت برنارد - Saint Bernard',
                     'سبرينجر سبانيل - Springer Spaniel', 'سبرينجر سبانيل إنجليزي - English Springer Spaniel', 'سبيوني إيطاليانو - Spinone Italiano',
                     'ستافوردشاير بول تيرير - Staffordshire Bull', 'ستافوردشاير بول تيرير - Staffordshire Bull Terrier (English)', 'سكاي تيرير - Skye Terrier',
                     'سكوتش تيرير - Scottish Terrier', 'سكوتش دير هاوند - Scottish Deerhound', 'سلوغي (المغربي) - Sloughi',
                     'سلوقي عربي - Saluki', 'سوسكس سبانيل - Sussex Spaniel', 'سوفت كوتيد ويتن - Soft Coated Wheaten Terrier',
                     'سويديش فالهوند - Swedish Vallhund', 'سيبيريان هاسكي - Siberian Husky', 'سيتير أيرلندي - Irish Setter',
                     'سيتير إنجليزي - English Setter', 'سيسكي تيرير - Cesky Terrier', 'سيلكي تيرير - Silky Terrier',
                     'سيلي هام تيرير - Sealyham Terrier', 'شاربي - Chinese Shar-Pei', 'شاربي - Shar Pei',
                     'شنوزر عملاق - Giant Schnauzer', 'شنوزر قياسي - Standard Schnauzer', 'شنوزر مصغر - Miniature Schnauzer',
                     'شيبا إينو - Shiba Inu', 'شيبا-بو - Shiba-poo', 'شيبيركي - Schipperke',
                     'شيتلاند شيبدوغ (شيلتي) - Shetland Sheepdog', 'شيه تزو - Shih Tzu', 'شيواوا - Chihuahua',
                     'غلين أوف إيمال تيرير - Glen of Imaal Terrier', 'فايزمارانر - Weimaraner', 'فلات كوتيد ريتريفر - Flat-Coated Retriever',
                     'فنلند لافهوند - Finnish Lapphund', 'فوكس تيرير - Fox Terrier', 'فيزلا - Vizsla',
                     'فيلد سبانيل - Field Spaniel', 'فينش سبيتز - Finnish Spitz', 'قصب كورسو - Cane Corso',
                     'كاردينال ويلش كورجي - Cardigan Welsh Corgi', 'كافابو - Cavapoo (Cavalier + Poodle)', 'كافاليير كينغ تشارلز - Cavalier King Charles',
                     'كافاليير كينغ تشارلز - Cavalier King Charles Spaniel', 'كانغال تركي - Kangal', 'كاي كين - Kai Ken',
                     'كلب الراعي التيبتي - Tibetan Mastiff', 'كلب الفراعنة - Pharaoh Hound', 'كلب الماء الإسباني - Spanish Water Dog',
                     'كلب الماء البرتغالي - Portuguese Water Dog', 'كلب الماشية الأسترالي - Australian Cattle Dog', 'كلب الماشية البرتغالي - Rafeiro do Alentejo',
                     'كلب الماشية السويسري - Appenzeller Sennenhund', 'كلب الماشية الفلاندري - Bouvier des Flandres', 'كلب تايواني - Taiwan Dog',
                     'كلب تشيرنيكو ديل إتنا - Cirneco dell\'Etna', 'كلب تشين الصيني - Japanese Chin', 'كلب جبل إنتلبوخر - Entlebucher Mountain Dog',
                     'كلب جبل البرانس - Great Pyrenees', 'كلب جيندو الكوري - Jindo', 'كلب شينوك - Chinook',
                     'كلب كانغال التركي - Kangal Shepherd', 'كلب كنعاني - Canaan Dog (مشهور في منطقة بلاد الشام)', 'كلب مديتيرنيان - Ibizan Hound',
                     'كلوبر سبانيل - Clumber Spaniel', 'كو كابو - Cockapoo (Cocker Spaniel + Poodle)', 'كوتون دي تولير - Coton de Tulear',
                     'كوفاز - Kuvasz', 'كوكر سبانيل أمريكي - American Cocker Spaniel', 'كوكر سبانيل أمريكي - Cocker Spaniel',
                     'كوكر سبانيل إنجليزي - English Cocker Spaniel', 'كولي (ناعم/خشن) - Collie', 'كولي خشن - Rough Collie',
                     'كولي ناعم - Smooth Collie', 'كوموندور - Komondor', 'كويكرهوند - Nederlandse Kooikerhondje',
                     'كيرلي كوتيد ريتريفر - Curly-Coated Retriever', 'كيرن تيرير - Cairn Terrier', 'كيري بلو تيرير - Kerry Blue Terrier',
                     'كيسهوند - Keeshond', 'كيشو كين - Kishu Ken', 'لابرا دودل - Labradoodle (Labrador + Poodle)',
                     'لابرادور ريتريفر - Labrador Retriever', 'لاسي آبسو - Lhasa Apso', 'لاغوتو رومانولو - Lagotto Romagnolo',
                     'لاندسير - Landseer', 'لوكين (كلب الأسد الصغير) - Lowchen', 'ليون بيرجر - Leonberger',
                     'لِيك لاند تيرير - Lakeland Terrier', 'ماستيف إسباني - Spanish Mastiff', 'ماستيف إنجليزي - English Mastiff',
                     'ماستيف إنجليزي - Mastiff', 'مالاموت ألاسكا - Alaskan Malamute', 'مالتيبو - Maltipoo (Maltese + Poodle)',
                     'مالطي - Maltese', 'مالينوا بلجيكي - Belgian Malinois', 'مودي (هنغاري) - Mudi',
                     'ميني أسترالي شيبيرد - Miniature American Shepherd', 'ميني بوبيون - Miniature Papillon', 'ميني بينشر - Miniature Pinscher',
                     'نابوليتان ماستيف - Neapolitan Mastiff', 'نورفولك تيرير - Norfolk Terrier', 'نورويجيان الكهوند - Norwegian Elkhound',
                     'نورويجيان بوهوند - Norwegian Buhund', 'نوريش تيرير - Norwich Terrier', 'نوفا سكوشا ريتريفر - Nova Scotia Duck Tolling Retriever',
                     'نوفا سكوشا ريتريفر - Nova Scotia Retriever', 'نيوفاوندلاند - Newfoundland', 'هارير - Harrier',
                     'هافا-بيو - Hava-poo', 'هافانيز - Havanese', 'هوفاوارت - Hovawart',
                     'واير هيرد بوينتر - Wirehaired Pointing Griffon', 'وبيت - Whippet', 'وتر سبانيل أيرلندي - Irish Water Spaniel',
                     'ووتر سبانيل أمريكي - American Water Spaniel', 'ويست هايلاند وايت (ويستي) - West Highland White Terrier', 'ويست هايلاند وايت تيرير - Westie',
                     'ويلش تيرير - Welsh Terrier', 'ويلش سبرينجر سبانيل - Welsh Springer Spaniel', 'ويلش كورجي بيمبروك - Welsh Corgi Pembroke',
                     'ويلش كورجي كارديجان - Welsh Corgi Cardigan', 'يوركشاير تيرير - Yorkshire Terrier', 'يوركي بو - Yorkipoo (Yorkshire + Poodle)',
                     'يوركي-بو - Yorkie-poo', 'أخرى - Other', 'بلدي / هجين - Mixed Breed',
                     'بلدي / هجين - Mixed Breed / Local Baladi',
                   ], icon: Icons.category_rounded)
                 else
                   _buildTextField('السلالة', 'pet_breed', icon: Icons.category_rounded),
                 _buildRadioChips('الجنس', 'pet_gender', ['ذكر', 'أنثى', 'غير محدد']),
                 _buildBottomSheetSelector('العمر', 'pet_age', [
                   'أقل من شهرين', '2-6 أشهر', '6-12 شهر', '1-3 سنوات', '3-7 سنوات', '+7 سنوات'
                 ], icon: Icons.calendar_month_rounded),
                 _buildBottomSheetSelector('اللون', 'dominant_color', [
                   'أبيض', 'أسود', 'فضي', 'رمادي', 'أحمر', 'أزرق', 'ذهبي', 'بني', 'بيج', 'أخضر',
                   'أصفر', 'برتقالي', 'بنفسجي', 'مشمشي', 'كريمي', 'مرقط', 'مخطط', 'متعدد الألوان', 'أخرى'
                 ], icon: Icons.color_lens_rounded),

                 if (isCat)
                   _buildRadioChips('مدربة على الليتر بوكس', 'litter_trained', ['نعم', 'لا']),
                 if (isBird)
                   _buildRadioChips('يغرد / منتج', 'sings_breeds', ['نعم', 'لا']),

                 const Divider(height: 32),
                 _buildSectionHeader('الملف الصحي', icon: Icons.medical_services_rounded),
                 _buildRadioChips('التطعيمات', 'health_vaccinations', ['غير محصن', 'محصن جزئي', 'محصن بالكامل']),
                 _buildRadioChips('التعقيم', 'health_sterilization', ['معقم', 'غير معقم']),
                 _buildRadioChips('المايكروتشيب', 'microchip', ['يوجد', 'لا يوجد']),
                 _buildCheckboxGroup('الوثائق', 'documents', ['جواز سفر', 'شهادة صحية', 'سجل تطعيمات']),

                 const Divider(height: 32),
                 _buildSectionHeader('السلوك والبيئة', icon: Icons.nature_people_rounded),
                 _buildBottomSheetSelector('مستوى التدريب', 'training_level', [
                   'غير مدرب', 'تدريب أساسي', 'مدرب باحتراف'
                 ], icon: Icons.model_training_rounded),
                 _buildBottomSheetSelector('التربية الحالية', 'current_housing', [
                   'داخل المنزل', 'خارج المنزل/حديقة', 'مزرعة'
                 ], icon: Icons.home_rounded),
                 _buildBottomSheetSelector('الطبع', 'temperament', [
                   'هادئ', 'لعوب', 'اجتماعي', 'خجول', 'شرس/حراسة'
                 ], icon: Icons.mood_rounded),
              ],
            ),
          ),

        if (isFish)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('الحياة المائية (Aquatic Life)', icon: Icons.water_drop_rounded),
                if (catId == '1004' || catId == '100401') ...[
                  _buildRadioChips('نوع المياه', 'water_type', ['مياه عذبة', 'مياه مالحة']),
                  _buildBottomSheetSelector('النمط', 'fish_type', [
                    'أسماك زينة', 'سمك مفترس', 'أسماك ذهبية', 'قشريات/روبيان'
                  ], icon: Icons.category_rounded),
                ],
                if (catId == '1004' || catId == '100402') ...[
                  _buildRadioChips('مادة الحوض', 'aquarium_material', ['زجاج', 'أكريليك']),
                  _buildMeasurementField('السعة', 'aquarium_capacity', 'L', icon: Icons.waves_rounded),
                  _buildTextField('أبعاد الحوض (ط/ع/ا)', 'aquarium_dimensions', icon: Icons.aspect_ratio_rounded, isRequired: false),
                ],
                if (catId == '1004' || catId == '100403' || catId == '100404') ...[
                  _buildRadioChips('نوع الإضاءة', 'lighting_type', ['LED', 'UV', 'RGB']),
                  _buildTextField('قوة الفلترة', 'filter_power', icon: Icons.power_rounded, isRequired: false),
                ]
              ],
            ),
          ),

        if (isFood)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 _buildSectionHeader('الطعام والتغذية (Nutrition)', icon: Icons.restaurant_rounded),
                 _buildRadioChips('تصنيف الغذاء', 'food_classification', ['طعام جاف', 'طعام رطب', 'طعام طبيعي', 'مكملات وفيتامينات']),
                 _buildTextField('العلامة التجارية', 'brand_name', icon: Icons.branding_watermark_rounded),
                 _buildTextField('الحجم / الوزن', 'item_size_weight', icon: Icons.monitor_weight_rounded),
                 _buildTextField('تاريخ الانتهاء', 'expiration_date', icon: Icons.date_range_rounded),
              ],
            ),
          ),

        if (isCare)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('مستلزمات العناية والسكن', icon: Icons.home_repair_service_rounded),
                _buildBottomSheetSelector('نوع المنتج', 'product_category', [
                  'شامبو/تنظيف', 'رمل (Litter)', 'سرير', 'قفص', 'حقيبة نقل', 'طوق', 'أدوات تدريب'
                ], icon: Icons.category_rounded),
                _buildBottomSheetSelector('المادة المصنعة', 'manufacturing_material', [
                  'بلاستيك', 'معدن', 'خشب', 'قماش'
                ], icon: Icons.texture_rounded),
                _buildRadioChips('المقاس', 'item_size', ['Small', 'Medium', 'Large', 'XL']),
                _buildCheckboxGroup('الميزات', 'item_features', ['قابل للطي', 'مقاوم للماء', 'مزود بتهوية']),
              ],
            ),
          ),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildSectionHeader('إضافات احترافية ومصدر', icon: Icons.verified_user_rounded),
               if (!isLivingPet) ...[
                 _buildRadioChips('مصدر', 'origin_source', ['مستورد', 'محلي']),
                 _buildRadioChips('خيارات التوصيل', 'delivery_options', ['توصيل متاح', 'شحن متاح', 'الاستلام من الموقع فقط']),
                 if (condition != 'جديد')
                   _buildTextField('سبب البيع', 'reason_for_sale', icon: Icons.help_outline_rounded, isRequired: false),
               ],
               
               _buildCheckboxGroup('ملحقات مجانية متضمنة', 'free_accessories', ['قفص / حوض', 'حقيبة تنقل', 'طعام', 'طوق / مقود', 'ألعاب', 'أدوات تنظيف / رمل']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildElectronicsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('مواصفات الجهاز',
                  icon: Icons.devices_rounded),
              _buildRadioChips('الحالة', 'condition',
                  ['مستعمل أخو الجديد', 'مستعمل', 'جديد بكرتونته']),
              _buildTextField('الماركة', 'brand',
                  icon: Icons.branding_watermark_rounded),
              _buildTextField('الموديل', 'model',
                  icon: Icons.model_training_rounded),
              const SizedBox(height: 16),
              _buildCheckboxGroup('يتوفر مع', 'accessories',
                  ['الشاحن الأصلي', 'الكرتونة', 'سماعات', 'كفالة سارية']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenericForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('تفاصيل أخرى',
                  icon: Icons.more_horiz_rounded),
              _buildRadioChips('الحالة', 'condition', ['جديد', 'مستعمل']),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final formType = _getFormType();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('تفاصيل إضافية',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: const [SupportActionButton()],
      ),
      backgroundColor: Colors.grey.shade50,
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
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
                        top: MediaQuery.of(context).padding.top + 100),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0075FF).withValues(alpha: 0.05),
                          Colors.white
                        ],
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
                          'أخبرنا المزيد عن ${widget.selectedLeafCategory.name}',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: -0.5,
                              height: 1.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'التفاصيل الدقيقة تزيد من فرصتك في البيع أو التأجير بنسبة 70% 🚀',
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                              height: 1.5,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (formType == 'Car')
                          _buildTipBanner(
                            title: 'نصيحة الخبير لبيع أسرع ⚡',
                            message:
                                'يُفضل دائماً إضافة "سعة المحرك (CC)" و "تاريخ فحص السيارة" و "عدد الملاك السابقين" في التدفق التالي، فهي تعطي المشتري ثقة 100%.',
                            icon: Icons.workspace_premium_rounded,
                          )
                        else
                          _buildTipBanner(),

                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('صفة المعلن', icon: Icons.person_pin_circle_rounded),
                              _buildRadioChips('نوع المعلن', 'advertiser_type', ['من المالك مباشرة', 'وسيط']),
                            ],
                          ),
                        ),

                        if (formType == 'Apartment') _buildApartmentForm(),
                        if (formType == 'Land') _buildLandForm(),
                        if (formType == 'Villa') _buildVillaForm(),
                        if (formType == 'Commercial') _buildCommercialForm(),
                        if (formType == 'Chalet') _buildChaletForm(),
                        if (formType == 'Car') _buildCarForm(),
                        if (formType == 'Motorcycle') _buildMotorcycleForm(),
                        if (formType == 'AutoParts') _buildAutoPartsForm(),
                        if (formType == 'LicensePlates') _buildLicensePlatesForm(),
                        if (formType == 'Pets') _buildPetsForm(),
                        if (formType == 'Electronics') _buildElectronicsForm(),
                        if (formType == 'Generic') _buildGenericForm(),

                        const SizedBox(height: 32),
                        
                        // Action Button at the end
                        SafeArea(
                          top: false,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _nextStep,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                backgroundColor: const Color(0xFF0075FF),
                              ),
                              child: const Text(
                                'متابعة للمعلومات الأساسية 👉',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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
}
