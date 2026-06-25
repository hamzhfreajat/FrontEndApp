import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/support_action_button.dart';
import '../services/analytics_engine.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'add_ad_reels.dart';

class AddAdImagesPage extends StatefulWidget {
  const AddAdImagesPage({super.key});

  @override
  State<AddAdImagesPage> createState() => _AddAdImagesPageState();
}

class _AddAdImagesPageState extends State<AddAdImagesPage> {

  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: 'add_ad_images');
  }

  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();

  bool _isAnalyzing = false;
  int _analyzedCount = 0;
  int _totalToAnalyze = 0;
  Set<String> _failedImages = {};
  Set<String> _successImages = {};
  String? _analysisError;
  String? _suggestedCategory;

  Future<void> _pickImages() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage();
      if (picked.isNotEmpty) {
        final wasEmpty = _images.isEmpty;
        setState(() {
          _images.addAll(picked);
          if (_images.length > 20) {
            _images.removeRange(20, _images.length);
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }



  Future<void> _analyzeFirstImage(XFile file) async {
    setState(() => _isAnalyzing = true);
    try {
      final result = await ApiService().analyzeImage(file.path);
      setState(() {
        _suggestedCategory = result['category_name'] as String?;
      });
      final quality = result['image_quality'] as String?;
      if (quality == 'blurry' || quality == 'dark') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('هذه الصورة تبدو ${quality == 'blurry' ? 'غير واضحة' : 'مظلمة'}. الصور الواضحة تباع أسرع بـ 3 أضعاف!'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to analyze image: $e');
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      final removed = _images.removeAt(index);
      _failedImages.remove(removed.path);
      _successImages.remove(removed.path);
    });
  }

  void _setAsMain(int index) {
    if (index == 0) return;
    setState(() {
      final selectedImage = _images.removeAt(index);
      _images.insert(0, selectedImage);
    });
  }

  Future<void> _nextStep() async {
    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
      _analyzedCount = 0;
      _totalToAnalyze = _images.length;
      _failedImages.clear();
      _successImages.clear();
    });
    try {
      final failedPaths = await ApiService().checkWatermarks(
        _images,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _analyzedCount = current;
              _totalToAnalyze = total;
            });
          }
        },
      );
      
      if (mounted) {
        setState(() {
          _failedImages = failedPaths.toSet();
          for (var img in _images) {
            if (!_failedImages.contains(img.path)) {
              _successImages.add(img.path);
            }
          }
        });
        
        if (_failedImages.isEmpty) {
          setState(() => _isAnalyzing = false);
          AnalyticsEngine().logButtonTapped(buttonName: 'next_step', location: 'add_ad_images');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddAdReelsPage(
                images: _images,
                suggestedCategory: _suggestedCategory,
              ),
            ),
          );
        } else {
          setState(() {
            _isAnalyzing = true; // Keep popup open
            _analysisError = 'عذراً، بعض الصور تحتوي على شعارات لتطبيقات أخرى أو نصوص إضافية تمنع نشرها.\n\nيرجى النقر على "حسناً" ثم إزالة الصور المظللة باللون الأحمر والمحاولة مرة أخرى.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إضافة صور', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    'ارفع صور إعلانك بتميز 📸',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'الصور الجيدة تزيد من سرعة البيع وتجذب اهتمام المزيد من العملاء المحتملين.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE94057).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE94057).withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2.0),
                          child: Icon(Icons.shield_outlined, color: Color(0xFFE94057), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: const Text(
                            'لضمان قبول إعلانك فوراً، يرجى التأكد من رفع صور خالية من شعارات التطبيقات الأخرى أو النصوص الإضافية.',
                            style: TextStyle(fontSize: 13, color: Color(0xFFD81B60), fontWeight: FontWeight.bold, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Upload Banner / Empty State
                  if (_images.isEmpty)
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0075FF).withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFF0075FF).withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0075FF).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add_photo_alternate_rounded, size: 36, color: Color(0xFF0075FF)),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'إضافة صور',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0075FF)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                        label: const Text('إضافة صور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF0075FF),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ]
                )
                  else ...[

                    if (_images.isNotEmpty) ...[
                      const Text('الصورة الرئيسية (الغلاف)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                    if (_suggestedCategory != null)
                       Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Color(0xFFE94057), size: 16),
                            const SizedBox(width: 6),
                            Text('تصنيف مقترح: $_suggestedCategory', style: const TextStyle(color: Color(0xFFE94057), fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    _buildFeaturedImageCard(),
                    
                    const SizedBox(height: 24),
                    
                    // Rest of Images Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontFamily: 'Cairo', color: Colors.black87), // Assuming Cairo or similar is default
                            children: [
                              const TextSpan(text: 'صور إضافية ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              TextSpan(
                                text: '(${_images.length - 1}/19)',
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        if (_images.length < 20)
                          TextButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                            label: const Text('المزيد', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0075FF),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              backgroundColor: const Color(0xFF0075FF).withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Masonry / Grid for remaining images
                    if (_images.length > 1)
                      GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                        itemCount: _images.length - 1,
                        itemBuilder: (context, index) {
                          return _buildThumbnailItem(index + 1);
                        },
                      ),
                      
                    if (_images.length < 3) ...[
                      if (_images.length > 1) const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, const Color(0xFFF0F7FF)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFF0075FF).withOpacity(0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0075FF).withOpacity(0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Color(0xFF0075FF), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'تحتاج إلى ${3 - _images.length} صورة إضافية',
                                  style: const TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.w900, 
                                    color: Color(0xFF0075FF),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'الإعلانات ذات الصور الكثيرة تجذب تفاعلاً أكبر وتزيد فرصة البيع بشكل مضاعف!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13, 
                                color: Colors.grey.shade700, 
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _pickImages,
                                icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                                label: const Text('إضافة صور جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(0xFF0075FF),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  shadowColor: const Color(0xFF0075FF).withOpacity(0.4),
                                ).copyWith(
                                  elevation: WidgetStateProperty.resolveWith<double>((states) {
                                    if (states.contains(WidgetState.pressed)) return 0;
                                    return 6;
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ], // Closes if (_images.length < 3) ...[
                    ], // Closes if (_images.isNotEmpty) ...[
                  ], // Closes else ...[
                ], // Closes children of Column
              ),
            ),
            const SizedBox(height: 120), // Padding for sticky bottom bar
          ],
        ),
      ),
      
      // Bottom Sticky Button (CTA)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _images.length >= 3 ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: _images.length >= 3 ? const Color(0xFF0075FF) : Colors.grey.shade300,
              ),
              child: Text(
                _images.length < 3
                    ? 'الرجاء إضافة 3 صور على الأقل' 
                    : 'متابعة لإضافة فيديو',
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w800, 
                  color: _images.length >= 3 ? Colors.white : Colors.grey.shade600
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    if (_isAnalyzing || _analysisError != null) _buildOverlayContent(),
  ],
);
  }

  Widget _buildOverlayContent() {
    final bool isError = _analysisError != null;
    
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          color: Colors.black.withOpacity(0.4),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: (isError ? Colors.red : const Color(0xFF0075FF)).withOpacity(0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon / Loader
                        if (isError)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0075FF).withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const CircularProgressIndicator(
                              color: Color(0xFF0075FF),
                              strokeWidth: 3.5,
                            ),
                          ),
                        const SizedBox(height: 24),
                        
                        // Title
                        Text(
                          isError ? 'خطأ في الصور' : 'جاري فحص الصور ($_analyzedCount/$_totalToAnalyze)',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isError ? Colors.red.shade800 : Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Message
                        Text(
                          isError 
                              ? _analysisError! 
                              : 'نحن نتأكد من جودة الصور ومطابقتها للشروط\nلحظات وتكتمل العملية 😊',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: isError ? Colors.red.shade900 : Colors.grey.shade700,
                            height: 1.6,
                            fontWeight: isError ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        
                        // Progress Bar (Only when loading)
                        if (!isError && _totalToAnalyze > 0) ...[
                          const SizedBox(height: 24),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: _analyzedCount / _totalToAnalyze,
                            ),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) {
                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${(value * 100).toInt()}%',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0075FF),
                                        ),
                                      ),
                                      const Text(
                                        'يرجى الانتظار...',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    height: 10,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0075FF).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.centerRight,
                                    child: FractionallySizedBox(
                                      widthFactor: value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF00C6FF),
                                              Color(0xFF0075FF),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0075FF).withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                        
                        // Dismiss Button (Only for error)
                        if (isError) ...[
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _analysisError = null;
                                  _isAnalyzing = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                foregroundColor: Colors.red.shade700,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'حسناً، فهمت',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildFeaturedImageCard() {
    bool isFailed = _images.isNotEmpty && _failedImages.contains(_images[0].path);
    bool isSuccess = _images.isNotEmpty && _successImages.contains(_images[0].path);
    
    return Stack(
      children: [
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: isFailed ? Border.all(color: Colors.red, width: 3) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
            image: DecorationImage(
              image: FileImage(File(_images[0].path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (isFailed)
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.red.withOpacity(0.4),
            ),
            child: const Center(
              child: Icon(Icons.error_outline_rounded, color: Colors.white, size: 48),
            ),
          ),
        if (isSuccess)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 24),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: () => _removeImage(0),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            ),
          ),
        ),
        const Positioned(
          bottom: 20,
          right: 20,
          child: Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Text(
                'الغلاف الأساسي للإعلان',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailItem(int index) {
    bool isFailed = _failedImages.contains(_images[index].path);
    bool isSuccess = _successImages.contains(_images[index].path);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isFailed ? Border.all(color: Colors.red, width: 3) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              )
            ],
            image: DecorationImage(
              image: FileImage(File(_images[index].path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (isFailed)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.red.withOpacity(0.4),
            ),
            child: const Center(
              child: Icon(Icons.error_outline_rounded, color: Colors.white, size: 32),
            ),
          ),
        if (isSuccess)
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
          ),
        Positioned(
          top: 6,
          left: 6,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.black87, size: 14),
            ),
          ),
        ),
        Positioned(
          bottom: 6,
          left: 6,
          right: 6,
          child: GestureDetector(
            onTap: () => _setAsMain(index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_outline_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('تعيين كرئيسية', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
