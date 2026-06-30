import 'package:flutter/material.dart';
import '../widgets/support_action_button.dart';
import '../services/analytics_engine.dart';
import 'package:image_picker/image_picker.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import 'add_ad_preview.dart';
import '../utils/form_analytics_tracker.dart';
import '../utils/arabic_numbers_formatter.dart';

class AddAdBasicInfoPage extends StatefulWidget {
  final Category selectedLeafCategory;
  final String transactionType;
  final List<XFile>? images;
  final XFile? reelVideo;
  final String selectedCity;
  final String selectedRegion;
  final String? mapLocation;
  final Map<String, dynamic> attributes;
  final List<String>? selectedLandmarks;
  final Map<String, dynamic>? editingAdData;

  const AddAdBasicInfoPage({
    super.key,
    required this.selectedLeafCategory,
    required this.transactionType,
    required this.selectedCity,
    required this.selectedRegion,
    required this.attributes,
    this.images,
    this.reelVideo,
    this.mapLocation,
    this.selectedLandmarks,
    this.editingAdData,
  });

  @override
  State<AddAdBasicInfoPage> createState() => _AddAdBasicInfoPageState();
}

class _AddAdBasicInfoPageState extends State<AddAdBasicInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _downPaymentController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final FocusNode _titleFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();
  final FocusNode _priceFocus = FocusNode();
  final FocusNode _downPaymentFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  late final FormAnalyticsTracker _formTracker;
  
  String? _paymentMethod = 'كاش';
  
  bool _isGeneratingAi = false;
  List<String> _smartTags = [];
  List<String> _selectedSmartTags = [];
  
  
  final ApiService _apiService = ApiService();

  late Map<String, dynamic> _adData;

  @override
  void dispose() {
    if (_adData.containsKey('id')) {
      final attributes = {
        ...widget.attributes,
        'payment_method': _paymentMethod,
        'phone_number': _phoneController.text.trim(),
        if (_downPaymentController.text.isNotEmpty) 'down_payment': _downPaymentController.text,
      };
      
      final updateData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'attributes': attributes,
        'phone_number': _phoneController.text.trim(),
      };
      
      if (_priceController.text.isNotEmpty) {
        updateData['price'] = double.tryParse(_priceController.text) ?? 0.0;
      }
      
      // Fire-and-forget update
      ApiService().updateDraft(_adData['id'], updateData).catchError((_) => null);
      
      _adData.addAll(updateData);
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _downPaymentController.dispose();
    _phoneController.dispose();
    _formTracker.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    _priceFocus.dispose();
    _downPaymentFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: 'add_ad_basic_info');
    
    _formTracker = FormAnalyticsTracker(
      formName: 'add_ad_basic_info',
      fields: {
        'title': _titleFocus,
        'description': _descriptionFocus,
        'price': _priceFocus,
        'down_payment': _downPaymentFocus,
        'phone_number': _phoneFocus,
      },
    );

    _adData = widget.editingAdData ?? {};

    final sourceData = _adData;
    if (sourceData != null && sourceData.isNotEmpty) {
      if (sourceData['title'] != null) _titleController.text = sourceData['title'].toString();
      if (sourceData['description'] != null) _descriptionController.text = sourceData['description'].toString();
      if (sourceData['price'] != null && sourceData['price'].toString() != '0.0') _priceController.text = sourceData['price'].toString();
      
      final dynamicData = sourceData['attributes']?['dynamic_data'];
      if (dynamicData != null && dynamicData['down_payment'] != null) {
         _downPaymentController.text = dynamicData['down_payment'].toString();
      }
      if (sourceData['attributes']?['payment_method'] != null) {
        _paymentMethod = sourceData['attributes']!['payment_method'];
      }
      if (sourceData['phone_number'] != null) {
        _phoneController.text = sourceData['phone_number'].toString();
      } else if (sourceData['attributes']?['phone_number'] != null) {
        _phoneController.text = sourceData['attributes']['phone_number'].toString();
      }
    }
    
    // Removed auto-fetch for AI suggestions
  }

  Future<void> _generateAiContent() async {
    setState(() => _isGeneratingAi = true);
    try {
      final contextData = {
        'category': widget.selectedLeafCategory.name,
        'transaction_type': widget.transactionType,
        'city': widget.selectedCity,
        'region': widget.selectedRegion,
        'attributes': widget.attributes,
      };

      final response = await _apiService.generateAdSuggestions(contextData);
      
      if (mounted) {
        setState(() {
          final suggestions = (response['suggestions'] as List).map((e) => (e as Map).cast<String, String>()).toList();
          if (suggestions.isNotEmpty) {
            final sug = suggestions.first;
            _titleController.text = sug['title'] ?? '';
            _descriptionController.text = sug['description'] ?? '';
          }
          
          _smartTags = (response['smart_tags'] as List).cast<String>();
          _selectedSmartTags = List<String>.from(_smartTags); // Auto-select all by default
          _isGeneratingAi = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating AI content: $e');
      if (mounted) {
        setState(() {
          _isGeneratingAi = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء التوليد. الرجاء المحاولة مرة أخرى.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool get _isAdoption {
    if (widget.attributes.containsKey('ad_purpose')) {
       return widget.attributes['ad_purpose'].toString().contains('للتبني');
    }
    return false;
  }

  void _submitAd() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_isAdoption && _paymentMethod == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار طريقة الدفع'), backgroundColor: Colors.red),
      );
      return;
    }

    final finalAdData = {
      if (_adData.containsKey('id'))
        'id': _adData['id'],
      if (_adData.containsKey('image_urls'))
        'image_urls': _adData['image_urls'],
      'title': _titleController.text.isNotEmpty 
          ? _titleController.text 
          : '${widget.selectedLeafCategory.name} - ${widget.transactionType}',
      'description': _descriptionController.text,
      'price': _isAdoption ? 0 : ((_paymentMethod == 'أقساط') ? 0 : (double.tryParse(_priceController.text) ?? 0)),
      'location': widget.selectedCity,
      'region': widget.selectedRegion,
      if (widget.mapLocation != null) 'map_coordinates': widget.mapLocation,
      'category_id': widget.selectedLeafCategory.id,
      'linked_tags': _selectedSmartTags,
      'attributes': {
        ...widget.attributes,
        'payment_method': _paymentMethod,
        'city': widget.selectedCity,
        'region': widget.selectedRegion,
        'phone_number': _phoneController.text.trim(),
        if (_paymentMethod == 'أقساط' || _paymentMethod == 'كاش أو أقساط')
          'down_payment': double.tryParse(_downPaymentController.text) ?? 0,
        if (widget.selectedLandmarks != null && widget.selectedLandmarks!.isNotEmpty)
          'nearby_landmarks': widget.selectedLandmarks,
      },
      'phone_number': _phoneController.text.trim(),
    };

    if (_adData.containsKey('id')) {
      try {
        await ApiService().updateDraft(_adData['id'], finalAdData);
      } catch (e) {
        debugPrint('Failed to update draft: $e');
      }
    }

    if (!mounted) return;

    debugPrint('Gathered Data for Preview: $finalAdData');
    
    _formTracker.markSubmitted();
    AnalyticsEngine().logButtonTapped(buttonName: 'next_step', location: 'add_ad_basic_info');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAdPreviewPage(
          adData: finalAdData,
          images: widget.images,
          reelVideo: widget.reelVideo,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('المعلومات الأساسية', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: const [SupportActionButton()],
      ),
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
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
                top: MediaQuery.of(context).padding.top + 80
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0075FF).withValues(alpha: 0.05), Colors.white],
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
                  const Text(
                    'تفاصيل إعلانك الأساسية 📝',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'أضف عنواناً جذاباً، وصفاً واضحاً وسعراً مناسباً لإعلانك.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Manual Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isAdoption) ...[
                           Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                              child: Row(
                                children: [
                                  Icon(Icons.favorite_rounded, color: Colors.green.shade600),
                                  const SizedBox(width: 12),
                                  Text('هذا الإعلان بغرض التبني ومجاني بالكامل ✅', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade800)),
                                ]
                              )
                           ),
                           const SizedBox(height: 24),
                        ],

                        if (!_isAdoption && widget.transactionType != 'عقارات للايجار' && widget.transactionType != 'عقارات للإيجار') ...[
                          const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: ['كاش', 'أقساط', 'كاش أو أقساط'].map((opt) {
                            final isSelected = opt == _paymentMethod;
                            return GestureDetector(
                              onTap: () => setState(() => _paymentMethod = opt),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0075FF).withValues(alpha: 0.08) : Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0075FF) : Colors.grey.shade300,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                  boxShadow: isSelected ? [] : [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                                  ],
                                ),
                                child: Text(
                                  opt,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF0075FF) : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        ],
                        const SizedBox(height: 24),

                        if (!_isAdoption && _paymentMethod != 'أقساط') ...[
                          const Text('السعر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _priceController,
                            focusNode: _priceFocus,
                            keyboardType: TextInputType.number,
                            inputFormatters: [ArabicNumbersFormatter()],
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.center,
                            validator: (val) => val == null || val.isEmpty ? 'مطلوب إدخال السعر' : null,
                            decoration: InputDecoration(
                              suffixText: 'دينار',
                              suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                              hintText: '0',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0075FF), width: 1.5)),
                            ),
                          ),

                            const SizedBox(height: 24),
                        ],
                        
                        if (!_isAdoption && (_paymentMethod == 'أقساط' || _paymentMethod == 'كاش أو أقساط')) ...[
                          const Text('دفعة أولى', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _downPaymentController,
                            focusNode: _downPaymentFocus,
                            keyboardType: TextInputType.number,
                            inputFormatters: [ArabicNumbersFormatter()],
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.center,
                            validator: (val) => val == null || val.isEmpty ? 'مطلوب إدخال الدفعة الأولى' : null,
                            decoration: InputDecoration(
                              suffixText: 'دينار',
                              suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                              hintText: '0',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0075FF), width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Color(0xFFEEEEEE), thickness: 1.5)),

                        // AI Generation Button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE94057).withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isGeneratingAi ? null : _generateAiContent,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                child: _isGeneratingAi
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                          SizedBox(width: 12),
                                          Flexible(child: Text('جاري توليد المحتوى...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                                        ],
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                                          SizedBox(width: 12),
                                          Flexible(child: Text('كتابة تفاصيل الإعلان بالذكاء الاصطناعي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center)),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const Text('عنوان الإعلان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _titleController,
                          focusNode: _titleFocus,
                          validator: (val) => val == null || val.trim().length < 10 ? 'أدخل عنواناً لا يقل عن 10 أحرف' : null,
                          minLines: 1,
                          maxLines: null,
                          scrollPhysics: const NeverScrollableScrollPhysics(),
                          decoration: InputDecoration(
                            hintText: 'مثال: ${widget.selectedLeafCategory.name} مميزة...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0075FF), width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text('تفاصيل الإعلان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          focusNode: _descriptionFocus,
                          validator: (val) => val == null || val.trim().length < 20 ? 'أدخل تفاصيل لا تقل عن 20 حرفاً' : null,
                          minLines: 5,
                          maxLines: null,
                          scrollPhysics: const NeverScrollableScrollPhysics(),
                          decoration: InputDecoration(
                            hintText: 'اكتب تفاصيل إعلانك هنا لجذب المهتمين...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0075FF), width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text('رقم الموبايل للتواصل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          focusNode: _phoneFocus,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [ArabicNumbersFormatter()],
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'مطلوب إدخال رقم الموبايل';
                            }
                            final regex = RegExp(r'^07[789]\d{7}$');
                            if (!regex.hasMatch(val.trim())) {
                              return 'يجب أن يكون رقماً أردنياً صحيحاً (مثال: 0791234567)';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: '079XXXXXXX',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0075FF), width: 1.5)),
                            prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Smart Tags UI (Moved to Bottom)
                        if (!_isGeneratingAi && _smartTags.isNotEmpty) ...[
                          const Text('كلمات مفتاحية ذكية (Smart Tags)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _smartTags.map((tag) {
                              final isSelected = _selectedSmartTags.contains(tag);
                              return FilterChip(
                                label: Text(tag, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12)),
                                selected: isSelected,
                                selectedColor: const Color(0xFFE94057),
                                backgroundColor: Colors.white,
                                shape: StadiumBorder(side: BorderSide(color: isSelected ? const Color(0xFFE94057) : Colors.grey.shade300)),
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedSmartTags.add(tag);
                                    } else {
                                      _selectedSmartTags.remove(tag);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom Non-Sticky Button (CTA)
            Container(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 48, top: 24),
              width: double.infinity,
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: _submitAd,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: const Color(0xFF0075FF),
                  ),
                  child: const Text('متابعة للمعاينة 👁️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
