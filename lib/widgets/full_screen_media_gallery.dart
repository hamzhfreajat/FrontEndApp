import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/ad.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/chat/presentation/screens/premium_chat_screen.dart';
import 'premium_video_player.dart';
import 'premium_share_bottom_sheet.dart';
import 'premium_login_bottom_sheet.dart';

class FullScreenMediaGallery extends StatefulWidget {
  final Ad ad;
  final int initialIndex;
  final bool showDetailsButton;

  const FullScreenMediaGallery({
    Key? key,
    required this.ad,
    required this.initialIndex,
    this.showDetailsButton = true,
  }) : super(key: key);

  @override
  State<FullScreenMediaGallery> createState() => _FullScreenMediaGalleryState();
}

class _FullScreenMediaGalleryState extends State<FullScreenMediaGallery> {
  late PageController _pageController;
  late int _currentIndex;
  late List<String> _mediaItems;
  bool _hasVideo = false;
  late bool _isFavorite;
  bool _showUI = true;
  bool _showPhone = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _isFavorite = widget.ad.isSaved;
    
    _hasVideo = widget.ad.videoUrl != null;
    _mediaItems = [];
    if (_hasVideo) {
      _mediaItems.add(widget.ad.videoUrl!); // index 0 is video
    }
    _mediaItems.addAll(widget.ad.images);
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showUI = false);
    });
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
    if (_showUI) _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final currentUserId = context.read<AuthProvider>().userData?['sub']?.toString();
    if (currentUserId == null || currentUserId.isEmpty) {
      PremiumLoginBottomSheet.show(
        context, 
        subtitle: 'يرجى تسجيل الدخول لإضافة الإعلان للمفضلة',
        onLoginSuccess: () => _toggleFavorite(),
      );
      return;
    }

    final originalState = _isFavorite;
    setState(() => _isFavorite = !_isFavorite);

    try {
      final isNowSaved = await ApiService().toggleSaveAd(widget.ad.id);
      if (mounted) {
        setState(() => _isFavorite = isNowSaved);
        widget.ad.isSaved = isNowSaved;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFavorite = originalState);
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aDate = DateTime(date.year, date.month, date.day);
    
    final timeStr = DateFormat('h:mm a').format(date);
    if (aDate == today) {
      return 'Today $timeStr';
    } else if (aDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $timeStr';
    } else {
      return '${DateFormat('MMM d, yyyy').format(date)} $timeStr';
    }
  }

  Widget _buildThumbnail(int index, String url) {
    final bool isActive = index == _currentIndex;
    final bool isVideo = _hasVideo && index == 0;
    
    final String thumbnailUrl = isVideo 
        ? (widget.ad.images.isNotEmpty ? widget.ad.images.first : url) 
        : url;

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFF0075FF) : Colors.transparent,
            width: 2,
          ),
          color: Colors.grey[900],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!(isVideo && widget.ad.images.isEmpty))
                ApiService.networkImage(thumbnailUrl, fit: BoxFit.cover),
              if (isVideo)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: Icon(Icons.play_circle_fill, color: Colors.white, size: 24),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleUI,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: [
              // 1. Media Viewer
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _mediaItems.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                      _showUI = true;
                    });
                    _startHideTimer();
                  },
                  itemBuilder: (context, index) {
                    final isVideo = _hasVideo && index == 0;
                    
                    if (isVideo) {
                      return Center(
                        child: PremiumVideoPlayer(
                          videoUrl: _mediaItems[index],
                        ),
                      );
                    }
                    
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: Hero(
                          tag: 'ad_media_${widget.ad.id}_$index',
                          child: ApiService.networkImage(
                            _mediaItems[index],
                            fit: BoxFit.contain,
                            errorWidget: const Icon(Icons.broken_image, color: Colors.white54, size: 60),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // 2. Top Header Overlay
              AnimatedOpacity(
                opacity: _showUI ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: IgnorePointer(
                    ignoring: !_showUI,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.ad.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDate(widget.ad.createdAt),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '${_currentIndex + 1} / ${_mediaItems.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // 3. Bottom Controls (Thumbnails + Actions)
              AnimatedOpacity(
                opacity: _showUI ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    ignoring: !_showUI,
                    child: Container(
                      padding: const EdgeInsets.only(top: 24), // gradient fade start
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Thumbnails Strip
                          if (_mediaItems.length > 1)
                            SizedBox(
                              height: 60,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _mediaItems.length,
                                itemBuilder: (context, index) {
                                  return _buildThumbnail(index, _mediaItems[index]);
                                },
                              ),
                            ),
                            
                          const SizedBox(height: 24),
                          
                          // Bottom Action Bar
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildActionButton(Icons.share_outlined, () {
                                  PremiumShareBottomSheet.show(context, widget.ad);
                                }),
                                if (widget.showDetailsButton) _buildDetailsButton(),
                                _buildActionButton(
                                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                                  _toggleFavorite,
                                  color: _isFavorite ? Colors.red : Colors.white,
                                ),
                              ],
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
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(
      onTap: () {
        _startHideTimer(); // Reset timer on action
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildDetailsButton() {
    return GestureDetector(
      onTap: () {
        _startHideTimer();
        _showDetailsSheet();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('تفاصيل الإعلان', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  void _showDetailsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(widget.ad.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                  const SizedBox(height: 8),
                  Text('${widget.ad.price.toStringAsFixed(0)} JOD', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0075FF))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFF94A3B8), size: 16),
                      const SizedBox(width: 6),
                      Text(widget.ad.location, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('الوصف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: controller,
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.ad.description, style: const TextStyle(fontSize: 15, height: 1.8, color: Color(0xFF475569))),
                          
                          if (_getSpecs().isNotEmpty) ...[
                            const SizedBox(height: 32),
                            const Text('المواصفات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _getSpecs().map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 16, color: const Color(0xFF0075FF).withOpacity(0.8)),
                                    const SizedBox(width: 6),
                                    Text('${s.key}: ', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                    Text(s.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ],
                          
                          const SizedBox(height: 32),
                          _buildContactBar(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<MapEntry<String, String>> _getSpecs() {
    final List<MapEntry<String, String>> q = [];
    final dyn = <String, dynamic>{};
    if (widget.ad.attributes != null) {
      if (widget.ad.attributes!['dynamic_data'] != null) {
        dyn.addAll(Map<String, dynamic>.from(widget.ad.attributes!['dynamic_data']));
      }
      if (widget.ad.attributes!['furnished'] != null) dyn['furnishing'] = widget.ad.attributes!['furnished'];
      if (widget.ad.attributes!['floor'] != null) dyn['floor'] = widget.ad.attributes!['floor'];
      if (widget.ad.attributes!['building_age'] != null) dyn['age'] = widget.ad.attributes!['building_age'];
    }

    if (dyn.isNotEmpty) {
      final Map<String, String> qualityLabels = {
        'rooms': 'عدد الغرف', 'bedrooms': 'عدد الغرف', 'bathrooms': 'الحمامات', 
        'furnishing': 'مفروشة؟', 'furnished': 'مفروشة؟',
        'floor': 'الطابق', 'age': 'عمر البناء', 'building_age': 'عمر البناء', 'rent_duration': 'مدة الإيجار',
        'area': 'المساحة', 'zoning': 'التنظيم', 'zoning_classification': 'التصنيف/التنظيم', 'classification': 'التصنيف', 'qualification': 'التصنيف', 'land_classification': 'تصنيف الأرض', 'deed_type': 'نوع السند',
        'frontage': 'الواجهة', 'villa_type': 'تصنيف الفيلا', 'floors': 'عدد الطوابق',
        'commercial_sub': 'النوع', 'detailed_location': 'الموقع التفصيلي',
        'key_money': 'الخلو', 'key_money_value': 'قيمة الخلو', 'land_area': 'مساحة الأرض', 'license': 'الترخيص', 'finishing': 'التشطيب',
        'ownership_type': 'نوع الملكية', 'is_mortgaged': 'مرهونة؟', 'topography': 'طبيعة الأرض',
        'mortgage_details': 'تفاصيل الرهن', 'shares_number': 'عدد الحصص', 'plot_number': 'رقم القطعة',
        'topography_notes': 'ملاحظات طبيعة الأرض', 'build_area': 'مساحة البناء', 'building_ratio': 'نسبة البناء',
        'geometric_shape': 'الشكل الهندسي', 'length': 'الطول', 'width': 'العرض',
        'allowed_floors': 'الطوابق المسموحة', 'soil_type': 'نوع التربة', 'irrigation_water': 'مياه الري',
        'electricity_capacity': 'قدرة الكهرباء', 'is_subdivided': 'مفرزة؟', 'has_blueprint': 'مخطط متوفر؟',
        'street_type': 'نوع الشارع', 'street_facade': 'الواجهة', 'street_width': 'عرض الشارع',
        'duration': 'المدة', 'year': 'سنة الصنع', 'transmission': 'ناقل الحركة',
        'fuel': 'الوقود', 'mileage': 'المسافة المقطوعة', 'condition': 'الحالة',
        'brand': 'الماركة', 'model': 'الموديل', 'facade': 'الواجهة',
        'engine_capacity': 'سعة المحرك (CC)', 'previous_owners': 'عدد الملاك السابقين',
        'regional_specs': 'المصدر', 'rims_size': 'قياس الجنط',
        'body_type': 'نوع الهيكل', 'seats_count': 'عدد المقاعد',
        'exterior_color': 'اللون الخارجي', 'interior_color': 'اللون الداخلي',
        'insurance_status': 'التأمين', 'inspection_result': 'فحص السيارة',
        'vin_number': 'رقم الشاصي', 'cylinders': 'عدد الأسطوانات',
        'fuel_type': 'نوع الوقود', 'final_drive': 'نظام الدفع',
        'color': 'اللون', 'origin_country': 'بلد المنشأ', 'warranty': 'الضمان',
        'property_type': 'نوع العقار', 'usage_type': 'نوع الاستخدام', 'residential_type': 'النوع السكني'
      };

      for (var entry in dyn.entries) {
        final val = entry.value;
        if (val != null && val is! List) {
          String strVal = val.toString().trim();
          if (strVal.toLowerCase() == 'true') strVal = 'نعم';
          if (strVal.toLowerCase() == 'false') strVal = 'لا';
          if (strVal.isNotEmpty && strVal != 'null' && strVal != '0' && strVal != '0.0' && strVal != '0.00' && strVal != 'none' && strVal != 'غير محدد') {
            final translatedKey = qualityLabels[entry.key];
            if (translatedKey == null && RegExp(r'[a-zA-Z]').hasMatch(entry.key)) continue;
            final displayKey = translatedKey ?? entry.key;
            if (RegExp(r'[a-zA-Z]').hasMatch(strVal) && !strVal.contains(RegExp(r'[\u0600-\u06FF]'))) continue;
            if (!q.any((e) => e.key == displayKey)) {
               q.add(MapEntry(displayKey, strVal));
            }
          }
        }
      }
    }
    return q;
  }

  Widget _buildContactBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 8, bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Row(children: [
        // WhatsApp
        GestureDetector(
          onTap: () async {
            final phone = widget.ad.phoneNumber;
            if (phone == null || phone.isEmpty) return;
            String waPhone = phone;
            if (waPhone.startsWith('0')) waPhone = '962' + waPhone.substring(1);
            else if (waPhone.startsWith('+')) waPhone = waPhone.substring(1);
            final uri = Uri.parse('whatsapp://send?phone=$waPhone');
            final fallbackUri = Uri.parse('https://wa.me/$waPhone');
            try {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
              }
            } catch (e) {}
          },
          child: Container(
            height: 52, width: 52,
            decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: const Color(0xFF25D366).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
            child: const Icon(Icons.chat, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(width: 10),
        // Chat
        Expanded(
          child: GestureDetector(
            onTap: () {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final currentUserId = authProvider.userData?['sub']?.toString();
              if (currentUserId == null) return;
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => PremiumChatScreen(
                  adId: widget.ad.id.toString(),
                  adTitle: widget.ad.title,
                  adPrice: widget.ad.price.toStringAsFixed(0),
                  adImageUrl: widget.ad.images.isNotEmpty ? widget.ad.images.first : '',
                  isSeller: false,
                  currentUserId: currentUserId,
                  currentUserName: authProvider.userData?['full_name']?.toString() ?? authProvider.userData?['username']?.toString() ?? 'مستخدم',
                  currentUserPhone: authProvider.userData?['phone']?.toString(),
                  otherUserId: widget.ad.userId.toString(),
                  otherUserName: widget.ad.ownerName,
                  otherUserPhone: widget.ad.phoneNumber,
                )
              ));
            },
            child: Container(height: 52,
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF0075FF), width: 2), borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline, color: Color(0xFF0075FF), size: 20),
                SizedBox(width: 8),
                Text('دردشة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0075FF))),
              ]))),
          ),
        ),
        const SizedBox(width: 10),
        // Phone
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () async {
              final phone = widget.ad.phoneNumber;
              if (phone == null || phone.isEmpty) return;
              if (!_showPhone) {
                if (mounted) setState(() => _showPhone = true);
                return;
              }
              final telUri = Uri.parse('tel:$phone');
              try {
                if (await canLaunchUrl(telUri)) await launchUrl(telUri);
              } catch (e) {}
            },
            child: Container(height: 52,
              decoration: BoxDecoration(color: const Color(0xFF0075FF), borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: const Color(0xFF0075FF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
              child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.phone, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(_showPhone ? (widget.ad.phoneNumber ?? '') : 'إظهار الرقم', 
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white, letterSpacing: 0.5)),
              ]))),
          ),
        ),
      ]),
    );
  }
}
