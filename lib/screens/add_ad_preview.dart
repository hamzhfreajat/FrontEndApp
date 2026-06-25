import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/support_action_button.dart';
import '../services/analytics_engine.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ad.dart';
import '../models/category.dart';
import 'category_details_page.dart';
import 'ad_details_page.dart';
import '../widgets/premium_real_estate_card.dart';

import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
class AddAdPreviewPage extends StatefulWidget {
  final Map<String, dynamic> adData;
  final List<XFile>? images;
  final XFile? reelVideo;

  const AddAdPreviewPage({
    super.key,
    required this.adData,
    this.images,
    this.reelVideo,
  });

  @override
  State<AddAdPreviewPage> createState() => _AddAdPreviewPageState();
}

class _AddAdPreviewPageState extends State<AddAdPreviewPage> {
  bool _isLoadingAi = true;
  bool _isPublishing = false;
  int _adScore = 0;
  List<String> _adTips = [];
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: 'add_ad_preview');
    _fetchEvaluation();
  }

  Future<void> _fetchEvaluation() async {
    try {
      // Don't validate reelVideo/images size when sending to AI
      final result = await _apiService.fetchAdEvaluation(widget.adData);
      if (mounted) {
        setState(() {
          _adScore = result['score'];
          _adTips = (result['tips'] as List).cast<String>();
          _isLoadingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAi = false);
      }
    }
  }

  Ad _buildDummyAd() {
    // Generate an Ad object to pass to the preview widgets
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userData = authProvider.userData;
    
    String? ownerName;
    if (userData != null) {
      final fullName = userData['full_name']?.toString() ?? '';
      final firstName = userData['first_name']?.toString() ?? '';
      final lastName = userData['last_name']?.toString() ?? '';
      final username = userData['username']?.toString() ?? '';
      
      if (fullName.isNotEmpty) {
        ownerName = fullName;
      } else if (firstName.isNotEmpty) {
        ownerName = firstName;
        if (lastName.isNotEmpty) {
          ownerName += ' $lastName';
        }
      } else if (username.isNotEmpty) {
        ownerName = username;
      }
    }
    
    // Extract property details
    final attrs = widget.adData['attributes'] as Map<String, dynamic>;
    final dynamicData = attrs['dynamic_data'] as Map<String, dynamic>? ?? {};

    SharedRoomDetails? details;
    
    // For simplicity in preview, map the most common fields
    if (attrs['transaction_type']?.toString().contains('عقار') == true) {
      details = SharedRoomDetails(
        rooms: int.tryParse(dynamicData['bedrooms']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? ''),
        bathrooms: int.tryParse(dynamicData['bathrooms']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? ''),
        furnished: dynamicData['furnishing'],
        floor: dynamicData['floor'],
        buildingAge: dynamicData['age'],
        rentDuration: dynamicData['rent_duration'] is List ? (dynamicData['rent_duration'] as List).join('، ') : dynamicData['rent_duration']?.toString(),
        keyFeatures: (dynamicData['main_features'] as List?)?.cast<String>() ?? [],
        buildingFeatures: (dynamicData['extra_features'] as List?)?.cast<String>() ?? [],
        nearbyPlaces: (dynamicData['nearby'] as List?)?.cast<String>() ?? [],
        // other fields can be mapped as needed
      );
    }

    // Prepare tags
    List<String> tags = [attrs['leaf_category_name']?.toString() ?? 'إعلان جديد'];
    if (dynamicData['condition'] != null) tags.add(dynamicData['condition']);
    if (attrs['payment_method'] != null) tags.add(attrs['payment_method']);
    
    // Add AI generated tags
    if (widget.adData['linked_tags'] != null) {
      final aiTags = widget.adData['linked_tags'] as List<dynamic>;
      tags.addAll(aiTags.map((e) => e.toString()));
    }

    return Ad(
      id: 9999, // Fake Id
      title: widget.adData['title'] ?? 'بدون عنوان',
      description: widget.adData['description'] ?? 'بدون تفاصيل',
      price: double.tryParse(widget.adData['price']?.toString() ?? '0') ?? 0,
      location: '${widget.adData['region']}، ${widget.adData['location']}',
      categoryId: widget.adData['category_id'] ?? 1,
      images: (widget.images != null && widget.images!.isNotEmpty)
          ? widget.images!.map((m) => 'file://${m.path}').toList()
          : (widget.adData['image_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      imageUrl: (widget.images != null && widget.images!.isNotEmpty)
          ? 'file://${widget.images!.first.path}'
          : ((widget.adData['image_urls'] as List<dynamic>?)?.isNotEmpty == true 
              ? widget.adData['image_urls'][0].toString() 
              : widget.adData['image_url']?.toString()),
      createdAt: DateTime.now(),
      isHot: false,
      views: 0,
      tags: tags,
      phoneNumber: widget.adData['phone_number'],
      sharedRoomDetails: details,
      attributes: attrs,
      ownerName: ownerName,
    );
  }

  Future<void> _publishAd() async {
    if (_isPublishing) return;

    final existingImagesCount = (widget.adData['image_urls'] as List<dynamic>?)?.length ?? 0;
    final newImagesCount = widget.images?.length ?? 0;
    if (existingImagesCount + newImagesCount < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("U,OO\"O_ U.U+ OO OU?O_ 3 OU^O O1U,U% O U,OU,U, U,U+O'O O U,OO1U,O U+"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _isPublishing = true);
    }

    try {
      Ad newAd;
      final dataToSend = Map<String, dynamic>.from(widget.adData);
      dataToSend['is_published'] = true;

      final Object? incomingId = widget.adData['id'];
      if (incomingId != null) {
        final adIdInt = int.parse(incomingId.toString());
        newAd = await _apiService.updateAd(adIdInt, dataToSend, widget.images, widget.reelVideo);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تعديل الإعلان بنجاح! 🎉'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
          );
        }
      } else {
        newAd = await _apiService.publishAd(dataToSend, widget.images, widget.reelVideo);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفع الإعلان بنجاح! 🎉'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
          );
        }
      }
      
      if (mounted) {
        
        // Use cached categories from AppProvider instead of refetching
        final provider = Provider.of<AppProvider>(context, listen: false);
        final cachedCategories = provider.categories ?? [];
        final categoryId = widget.adData['category_id'] as int;
        
        // Try to find the leaf category from cached data
        Category? category;
        if (cachedCategories.isNotEmpty) {
          category = cachedCategories.cast<Category?>().firstWhere(
            (c) => c!.id == categoryId, 
            orElse: () => null,
          );
        }
        
        // If not cached, build a minimal category from ad data
        category ??= Category(
          id: categoryId,
          name: widget.adData['attributes']?['leaf_category_name'] ?? 'إعلان جديد',
          parentId: null,
        );
        
        if (mounted) {
          if (incomingId != null) {
            // If editing an existing ad, just return to the main dashboard
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else {
            // For a new ad, go to the category details to see it
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => CategoryDetailsPage(
                  category: category!,
                  allCategories: cachedCategories,
                  highlightedAd: newAd,
                )
              ),
              (route) => route.isFirst,
            );
          }
        }
        
        // Refresh categories in background (non-blocking)
        provider.refreshAll();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء نشر الإعلان: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = _buildDummyAd();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('معاينة الإعلان', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    'نظرة أخيرة قبل النشر 👀',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'هكذا سيظهر إعلانك للباحثين بعد نشره. تأكد من صحة كافة المعلومات والصور قبل التأكيد النهائي.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            
            // 3. AI Coach (Moved to top)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tips_and_updates_rounded, color: Color(0xFFF5A623)),
                      SizedBox(width: 8),
                      Text('تقييم الذكاء الاصطناعي للإعلان', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingAi)
                    const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator(color: Color(0xFF0075FF))))
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CircularProgressIndicator(
                                      value: _adScore / 100,
                                      strokeWidth: 8,
                                      backgroundColor: Colors.grey.shade200,
                                      color: _adScore >= 80 ? Colors.green : (_adScore >= 60 ? Colors.orange : Colors.red),
                                    ),
                                    Center(
                                      child: Text(
                                        '$_adScore/100',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _adScore >= 80 ? 'إعلانك ممتاز وجاهز للنشر!' : (_adScore >= 60 ? 'إعلان جيد، لكن يمكن تحسينه' : 'يحتاج إعلانك إلى تفاصيل أكثر'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'احرص على أخذ النصائح التالية بعين الاعتبار لزيادة فرص البيع.',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          ..._adTips.map((tip) => Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle, color: Color(0xFF0075FF), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(tip, style: const TextStyle(fontSize: 14))),
                                  ],
                                ),
                              )).toList(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            ),

            // 1. AD CARD PREVIEW (List View)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. شكل الإعلان في القوائم', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('هذا ما سيراه المستخدمون أثناء تصفح الأقسام.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 16),
                  
                  // Wrap in a card with shadow to simulate list background
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))
                      ],
                    ),
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: PremiumRealEstateCard(ad: ad, onTap: () {}, isPreview: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            // 2. AD DETAILS PREVIEW (Full Page)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2. تفاصيل الإعلان بالكامل', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('هكذا ستظهر تفاصيل ومواصفات إعلانك للمستخدمين.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 16),
                  AdDetailsPage(ad: ad, isPreview: true),
                ],
              ),
            ),
            const SizedBox(height: 120), // Spacer for sticky footer
          ],
        ),
      ),
      
      // Bottom Action Bar (Sticky Footer)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    side: BorderSide(color: Colors.grey.shade300, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('تعديل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isPublishing ? null : _publishAd,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: const Color(0xFF0075FF),
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isPublishing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      else ...[
                        const Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text('انشر الإعلان الآن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
