import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/premium_login_bottom_sheet.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../models/ad.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_loading.dart';
import '../features/chat/presentation/screens/premium_chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/share_helper.dart';
import '../widgets/premium_share_bottom_sheet.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium_video_player.dart';
import '../widgets/full_screen_media_gallery.dart';
import '../services/analytics_engine.dart';

import '../features/profile/presentation/screens/public_profile_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/profile/presentation/bloc/profile_bloc.dart';
import '../features/profile/data/repositories/api_profile_repository.dart';

class AdDetailsPage extends StatefulWidget {
  final Ad ad;
  final bool isPreview;
  const AdDetailsPage({super.key, required this.ad, this.isPreview = false});

  @override
  State<AdDetailsPage> createState() => _AdDetailsPageState();
}

class _AdDetailsPageState extends State<AdDetailsPage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  List<Ad> _relatedAds = [];
  bool _isLoadingAds = true;
  bool _isLoadingMore = false;
  bool _hasMoreAds = true;
  int _skip = 0;
  final int _limit = 10;
  int _currentImageIndex = 0;
  bool _showAllQualities = false;
  bool _descExpanded = false;
  bool _isFavorited = false;
  bool _showPhone = false;
  bool _isPageTransitioning = true;

  late final Ad ad = widget.ad;
  late AnimationController _favController;
  late Animation<double> _favScale;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (!widget.isPreview) {
      _fetchRelatedAds();
    } else {
      _isLoadingAds = false;
      _isPageTransitioning = false;
    }
    _pageController = PageController();

    Future.microtask(() {
      if (mounted && !widget.isPreview) {
        Provider.of<AppProvider>(context, listen: false).addToRecentlyViewed(widget.ad);
        AnalyticsEngine().logScreenViewed(screenName: 'ad_details');
        AnalyticsEngine().logPropertyViewed(
          propertyId: widget.ad.id.toString(),
          price: widget.ad.price,
          propertyType: widget.ad.categoryId.toString(),
        );
      }
    });

    _favController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _favScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _favController, curve: Curves.elasticOut),
    );

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    
    final appProvider = context.read<AppProvider>();
    if (appProvider.locallySavedAdIds.contains(widget.ad.id)) {
      _isFavorited = true;
    } else if (appProvider.locallyUnsavedAdIds.contains(widget.ad.id)) {
      _isFavorited = false;
    } else {
      _isFavorited = widget.ad.isSaved;
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isPageTransitioning = false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _favController.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.isPreview) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingAds && !_isLoadingMore && _hasMoreAds) {
      _loadMoreAds();
    }
  }

  List<String>? _getLocations() {
    final city = widget.ad.attributes?['city']?.toString();
    if (city != null && city.isNotEmpty) return [city];
    if (widget.ad.location != 'غير محدد') return [widget.ad.location];
    return null;
  }

  List<String>? _getStructuredTags() {
    if (widget.ad.tags.isEmpty) return null;
    final allowedPrefixes = [
      'bedrooms:', 'bathrooms:', 'furnished:', 'rent_duration:', 
      'land_type:', 'zoning_classification:', 'ownership_type:', 'floor:'
    ];
    final filtered = widget.ad.tags.where((tag) {
      for (final prefix in allowedPrefixes) {
        if (tag.startsWith(prefix)) return true;
      }
      return false;
    }).toList();
    return filtered.isNotEmpty ? filtered : null;
  }

  Future<void> _fetchRelatedAds() async {
    if (!mounted) return;
    setState(() { _isLoadingAds = true; _skip = 0; _hasMoreAds = true; _relatedAds.clear(); });
    try {
      final fetched = await _apiService.fetchAds(
        categoryId: widget.ad.categoryId,
        locations: _getLocations(),
        tags: _getStructuredTags(),
        skip: _skip, 
        limit: _limit
      );
      if (!mounted) return;
      setState(() {
        _relatedAds = fetched.where((a) => a.id != widget.ad.id).toList();
        _skip += _limit;
        _hasMoreAds = fetched.length == _limit;
        _isLoadingAds = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingAds = false);
    }
  }

  Future<void> _loadMoreAds() async {
    if (!mounted) return;
    setState(() => _isLoadingMore = true);
    try {
      final fetched = await _apiService.fetchAds(
        categoryId: widget.ad.categoryId,
        locations: _getLocations(),
        tags: _getStructuredTags(),
        skip: _skip, 
        limit: _limit
      );
      if (!mounted) return;
      setState(() {
        _relatedAds.addAll(fetched.where((a) => a.id != widget.ad.id));
        _skip += _limit;
        _hasMoreAds = fetched.length == _limit;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  String _timeAgo() {
    if (ad.createdAt == null) return '';
    final diff = DateTime.now().difference(ad.createdAt!);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
    return 'منذ ${(diff.inDays / 30).floor()} شهر';
  }

  Future<void> _toggleFavorite() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      PremiumLoginBottomSheet.show(
        context,
        title: 'أضف للمفضلة',
        subtitle: 'سجل الدخول لإضافة هذا الإعلان إلى مفضلتك والرجوع إليه لاحقاً',
        onLoginSuccess: () => _toggleFavorite(), // Retry after login
      );
      return;
    }
    
    if (widget.isPreview) {
      _snack('هذه الميزة غير متاحة في وضع المعاينة');
      return;
    }
    final originalState = _isFavorited;
    setState(() => _isFavorited = !_isFavorited);
    
    if (_isFavorited) {
      _favController.forward().then((_) => _favController.reverse());
    }

    try {
      final isNowSaved = await _apiService.toggleSaveAd(widget.ad.id);
      if (mounted) {
        setState(() => _isFavorited = isNowSaved);
        context.read<AppProvider>().toggleFavoriteCount(isNowSaved, adId: widget.ad.id);
        if (isNowSaved) {
          _snack('تم حفظ الإعلان في المفضلة ❤️');
        } else {
          _snack('تم إزالة الإعلان من المفضلة');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFavorited = originalState);
        if (e.toString().contains('Unauthorized')) {
          _snack('يرجى تسجيل الدخول أولاً.');
        } else {
          _snack('حدث خطأ أثناء حفظ الإعلان.');
        }
      }
    }
  }

  void _copyLink() {
    if (widget.isPreview) {
      _snack('هذه الميزة غير متاحة في وضع المعاينة');
      return;
    }
    PremiumShareBottomSheet.show(context, widget.ad);
  }

  void _submitReport(String reason, {String? comments}) async {
    if (widget.isPreview) {
      _snack('هذه الميزة غير متاحة في وضع المعاينة');
      return;
    }
    try {
      await _apiService.reportAd(widget.ad.id, reason, comments: comments);
      if (mounted) _snack('تم إرسال البلاغ، شكراً لك 🙏');
    } catch (e) {
      if (mounted) _snack('حدث خطأ أثناء إرسال البلاغ');
    }
  }

  void _showOtherReportDialog() {
    final TextEditingController _commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.red, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('سبب البلاغ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              const Text('يرجى توضيح سبب الإبلاغ بدقة لمساعدتنا في مراجعة الإعلان بأسرع وقت ممكن.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5)),
              const SizedBox(height: 24),
              TextField(
                controller: _commentController,
                maxLines: 4,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'اكتب تفاصيل البلاغ هنا...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('إلغاء', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_commentController.text.trim().isEmpty) {
                          _snack('يرجى كتابة السبب');
                          return;
                        }
                        Navigator.pop(context);
                        _submitReport('أخرى', comments: _commentController.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('إرسال البلاغ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3))),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.flag_rounded, color: Colors.red.shade600, size: 24),
                ),
                const SizedBox(width: 16),
                const Text('الإبلاغ عن الإعلان', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Color(0xFF1E293B))),
              ],
            ),
            const SizedBox(height: 8),
            const Text('لماذا تريد الإبلاغ عن هذا الإعلان؟ ستظل هويتك سرية.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            ...['محتوى غير لائق أو مسيء', 'الإعلان مكرر', 'معلومات مضللة أو غير صحيحة', 'احتيال، نصب، أو بريد مزعج', 'أخرى'].map((reason) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    if (reason == 'أخرى') {
                      _showOtherReportDialog();
                    } else {
                      _submitReport(reason);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(reason, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF334155))),
                        const Icon(Icons.chevron_left_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  void _openFullScreenGallery(int startIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FullScreenMediaGallery(ad: ad, initialIndex: startIndex, showDetailsButton: false)
    ));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xFF2D2D2D),
      duration: const Duration(seconds: 2),
    ));
  }

  // ─── Brand Colors ───
  static const _accent = Color(0xFF1A73E8);
  static const _accentDark = Color(0xFF1557B0);
  static const _bg = Color(0xFFF4F6FA);
  static const _card = Colors.white;
  static const _green = Color(0xFF25D366); // WhatsApp

  @override
  Widget build(BuildContext context) {
    if (_isPageTransitioning) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F9),
        body: SafeArea(child: ShimmerHomeScreen()),
      );
    }
    
    final customScroll = CustomScrollView(
      shrinkWrap: widget.isPreview,
      physics: widget.isPreview ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      slivers: [
        _buildImageHeader(context),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.isPreview ? 20 : 130),
            child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPriceCard(),
                        const SizedBox(height: 10),
                        _buildQuickActions(),
                        const SizedBox(height: 10),
                        _buildSellerCard(),
                        const SizedBox(height: 10),
                        if (_hasSpecs()) _buildSpecsRow(),
                        if (_hasSpecs()) const SizedBox(height: 10),
                        _buildDescriptionCard(),
                        const SizedBox(height: 10),
                        _buildQualitiesCard(),
                        const SizedBox(height: 10),
                        _buildAmenitiesCard(),
                        const SizedBox(height: 10),
                        _buildTagsSection(),
                        const SizedBox(height: 10),
                        // _buildLocationCard(),
                        // const SizedBox(height: 10),
                        _buildAdInfoCard(),
                        const SizedBox(height: 10),
                        _buildSafetyTips(),
                        const SizedBox(height: 20),
                        if (!widget.isPreview) _buildRelatedAds(),
                      ],
                    ),
                  ),
                ),
              ],
    );

    if (widget.isPreview) {
      return Container(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: customScroll,
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            customScroll,
            Positioned(left: 0, right: 0, bottom: 0, child: _buildContactBar(context)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 1. IMAGE HEADER with fullscreen tap
  // ═══════════════════════════════════════════════
  Widget _buildImageHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 340, pinned: true, stretch: true,
      backgroundColor: _card, elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(fit: StackFit.expand, children: [
          if (ad.images.isNotEmpty || ad.videoUrl != null)
            PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              dragStartBehavior: DragStartBehavior.down,
              itemCount: ad.images.length + (ad.videoUrl != null ? 1 : 0),
              onPageChanged: (i) => setState(() => _currentImageIndex = i),
              itemBuilder: (_, i) {
                final hasVideo = ad.videoUrl != null;
                
                // Clicking either video or image opens the unified gallery
                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => FullScreenMediaGallery(ad: ad, initialIndex: i)
                    ));
                  },
                  behavior: HitTestBehavior.opaque,
                  child: hasVideo && i == 0 
                      ? PremiumVideoPlayer(
                          videoUrl: ad.videoUrl!,
                          thumbnailUrl: ad.images.isNotEmpty ? ad.images.first : null,
                          isPreviewOnly: true,
                        )
                      : Hero(
                          tag: 'ad_image_${ad.id}_${hasVideo ? i - 1 : i}',
                          child: ApiService.networkImage(
                            ad.images[hasVideo ? i - 1 : i], 
                            fit: BoxFit.cover,
                            errorWidget: _placeholder()
                          ),
                        ),
                );
              },
            )
          else if (ad.imageUrl != null)
            ApiService.networkImage(ad.imageUrl!, fit: BoxFit.cover, errorWidget: _placeholder())
          else _placeholder(),

          // Right Navigation Arrow (Main Slider) - Points Right, goes to Previous (in RTL)
          if ((ad.images.length + (ad.videoUrl != null ? 1 : 0)) > 1 && _currentImageIndex > 0)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),

          // Left Navigation Arrow (Main Slider) - Points Left, goes to Next (in RTL)
          if ((ad.images.length + (ad.videoUrl != null ? 1 : 0)) > 1 && _currentImageIndex < (ad.images.length + (ad.videoUrl != null ? 1 : 0)) - 1)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),

          // Gradient (IgnorePointer so user can swipe over it!)
          Positioned(bottom: 0, left: 0, right: 0, height: 120,
            child: IgnorePointer(
              child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
              ))),
            )
          ),

          // Dots (IgnorePointer)
          if ((ad.images.length + (ad.videoUrl != null ? 1 : 0)) > 1)
            Positioned(bottom: 16, left: 0, right: 0,
              child: IgnorePointer(
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(ad.images.length + (ad.videoUrl != null ? 1 : 0), (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentImageIndex ? 24 : 8, height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentImageIndex ? Colors.white : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ))),
              )),

          // Counter (IgnorePointer)
          if (ad.images.isNotEmpty)
            Positioned(bottom: 16, left: 16, child: IgnorePointer(child: _badge('${_currentImageIndex + 1}/${ad.images.length}', Icons.photo_library_outlined))),

          // Expand Icon Button (Bottom Right)
          if (ad.images.isNotEmpty)
            Positioned(
              bottom: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _openFullScreenGallery(_currentImageIndex),
                child: Container(
                  padding: const EdgeInsets.all(10), // Increased padding
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65), // Darker background
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 26), // Bigger icon
                ),
              ),
            ),

          // Top Badges (Hot & Verified)
          Positioned(
            top: 90,
            right: 16,
            child: IgnorePointer(
              child: Wrap(
                direction: Axis.vertical,
                spacing: 8,
                children: [
                  if (ad.isHot)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('لقطة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
      leading: _glassBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
      actions: [
        _glassBtn(Icons.ios_share, _copyLink),
        ScaleTransition(
          scale: _favScale,
          child: _glassBtn(
            _isFavorited ? Icons.favorite : Icons.favorite_border,
            _toggleFavorite,
            color: _isFavorited ? Colors.red : Colors.white,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _badge(String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
    child: Row(children: [
      Icon(icon, color: Colors.white, size: 14), const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    ]),
  );

  Widget _glassBtn(IconData icon, VoidCallback onTap, {Color color = Colors.white}) => Padding(
    padding: const EdgeInsets.all(8),
    child: ClipRRect(borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(color: Colors.black.withOpacity(0.4),
          child: IconButton(icon: Icon(icon, color: color, size: 20), onPressed: onTap)))),
  );

  Widget _placeholder() => Container(color: Colors.grey.shade200,
      child: Center(child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey.shade400)));

  // ═══════════════════════════════════════════════
  // 2. PRICE CARD
  // ═══════════════════════════════════════════════
  Widget _buildPriceCard() {
    final paymentMethod = ad.attributes?['payment_method']?.toString() ?? 'كاش';
    final double downPayment = (ad.attributes?['down_payment'] as num?)?.toDouble() ?? 0;
    
    final lowerDesc = ad.description.toLowerCase();
    final bool _negotiable = ad.tags.any((t) => t.contains('تفاوض') || t.contains('negotiable')) || 
                  lowerDesc.contains('قابل للتفاوض') || lowerDesc.contains('تفاوض');
    final bool _mortgage = ad.tags.any((t) => t.contains('تقسيط') || t.contains('اقساط') || t.contains('installment')) || 
                lowerDesc.contains('تقسيط') || lowerDesc.contains('اقساط') || paymentMethod == 'أقساط' || paymentMethod == 'كاش أو أقساط';

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: _card,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 1. Stats Row (Time, Views, Saves, Hot Badge)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ad.createdAt != null) ...[
                  Icon(Icons.access_time_filled, size: 14, color: Colors.blueGrey.shade300),
                  const SizedBox(width: 4),
                  Text(_timeAgo(), style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 14),
                ],
                if (ad.views >= 10) ...[
                  Icon(Icons.visibility_rounded, size: 14, color: Colors.blueGrey.shade300),
                  const SizedBox(width: 4),
                  Text('${ad.views}', style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 14),
                ],
                if (ad.favoritesCount >= 10) ...[
                  Icon(Icons.bookmark_rounded, size: 14, color: Colors.blueGrey.shade300),
                  const SizedBox(width: 4),
                  Text('${ad.favoritesCount}', style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
                ]
              ],
            ),
            if (ad.isHot) 
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                 child: Row(children: const [Icon(Icons.local_fire_department, size: 13, color: Colors.orange), SizedBox(width: 4), Text('لقطة', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w900))]),
               )
          ]
        ),
        
        const SizedBox(height: 14),

        // 2. Title 
        Text(ad.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, height: 1.3, letterSpacing: -0.5, color: Color(0xFF1E293B))),
        
        const SizedBox(height: 12),

        // 3. Location
        Row(children: [
          Container(
             padding: const EdgeInsets.all(7),
             decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
             child: Icon(Icons.location_on_rounded, size: 18, color: Colors.blue.shade600),
          ),
          const SizedBox(width: 12),
          Flexible(child: Builder(
            builder: (context) {
              final city = ad.attributes?['city']?.toString();
              final region = ad.attributes?['region']?.toString();
              String locationText;
              if (city != null && city.isNotEmpty && region != null && region.isNotEmpty) {
                locationText = '$region، $city';
              } else if (region != null && region.isNotEmpty) {
                locationText = region;
              } else {
                locationText = ad.location;
              }
              return Text(locationText, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4));
            },
          )),
        ]),

        const SizedBox(height: 18),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 18),

        // 4. Price & Payment Methods
        Row(
           crossAxisAlignment: CrossAxisAlignment.end,
           children: [
              Text('${ad.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Roboto', fontSize: 32, letterSpacing: -1, color: Color(0xFF0075FF), height: 1)),
              const SizedBox(width: 6),
              const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('دينار', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0075FF)))),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  runSpacing: 4,
                  children: [
                    if (_negotiable)
                      Container(
                        margin: const EdgeInsets.only(bottom: 5, left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                        child: const Text('قابل للتفاوض 💸', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    if (_mortgage) 
                       Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBFDBFE))),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_balance, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  (paymentMethod == 'أقساط' || paymentMethod == 'كاش أو أقساط') && downPayment > 0 
                                    ? 'دفعة ${downPayment.toStringAsFixed(0)} د.أ🏦' 
                                    : 'متاح تقسيط🏦', 
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w900),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                       ),
                  ],
                ),
              ),
           ]
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  // 3. QUICK ACTIONS
  // ═══════════════════════════════════════════════
  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _actionBtn(Icons.share_outlined, 'مشاركة', _copyLink),
        _divider(),
        _actionBtn(Icons.flag_outlined, 'إبلاغ', _showReportDialog, color: Colors.red.shade400),
        _divider(),
        _actionBtn(
          _isFavorited ? Icons.favorite : Icons.favorite_border,
          _isFavorited ? 'تم الحفظ' : 'حفظ',
          _toggleFavorite,
          color: _isFavorited ? Colors.red : null,
        ),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: color ?? Colors.grey.shade600),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color ?? Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w700)),
        ])),
    );
  }

  Widget _divider() => Container(width: 1, height: 30, color: Colors.grey.shade200);

  // ═══════════════════════════════════════════════
  // 4. SPECS ROW
  // ═══════════════════════════════════════════════
  bool _hasSpecs() {
    final d = ad.sharedRoomDetails;
    if (d != null && (d.rooms != null || d.bathrooms != null || d.furnished != null || d.floor != null || d.buildingAge != null || d.rentDuration != null)) return true;
    if (ad.attributes != null) {
      final dyn = ad.attributes!['dynamic_data'] as Map<String, dynamic>? ?? {};
      if (ad.attributes!['rooms'] != null || dyn['bedrooms'] != null) return true;
      if (ad.attributes!['bathrooms'] != null || dyn['bathrooms'] != null) return true;
      if (ad.attributes!['floor'] != null || dyn['floor'] != null) return true;
      if (ad.attributes!['area'] != null || dyn['area'] != null) return true;
      if (ad.attributes!['furnished'] != null || dyn['furnishing'] != null) return true;
    }
    return false;
  }

  Widget _buildSpecsRow() {
    final specs = <_Spec>[];
    
    int? beds;
    int? baths;
    String? furnishedStatus;
    String? floor;
    String? buildingAge;
    String? rentDuration;
    String? area;

    final d = ad.sharedRoomDetails;
    if (d != null) {
      beds = d.rooms; baths = d.bathrooms; furnishedStatus = d.furnished;
      floor = d.floor; buildingAge = d.buildingAge; rentDuration = d.rentDuration;
    }
    
    if (ad.attributes != null) {
      final dyn = ad.attributes!['dynamic_data'] as Map<String, dynamic>? ?? {};
      
      var bedsR = ad.attributes!['rooms'] ?? dyn['bedrooms'];
      if (beds == null && bedsR != null) beds = int.tryParse(bedsR.toString().replaceAll(RegExp(r'[^0-9]'), ''));
      
      var bathsR = ad.attributes!['bathrooms'] ?? dyn['bathrooms'];
      if (baths == null && bathsR != null) baths = int.tryParse(bathsR.toString().replaceAll(RegExp(r'[^0-9]'), ''));
      
      var fStatusR = ad.attributes!['furnished'] ?? dyn['furnishing'];
      if (furnishedStatus == null && fStatusR != null) furnishedStatus = fStatusR.toString();
      
      var floorR = ad.attributes!['floor'] ?? dyn['floor'];
      if (floor == null && floorR != null) floor = floorR.toString();
      
      var ageR = ad.attributes!['building_age'] ?? dyn['age'];
      if (buildingAge == null && ageR != null) buildingAge = ageR.toString();
      
      var durR = ad.attributes!['rent_duration'] ?? dyn['rent_duration'];
      if (rentDuration == null && durR != null) {
        if (durR is List) {
          rentDuration = durR.isEmpty ? null : durR.join('، ');
        } else {
          rentDuration = durR.toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "").trim();
          if (rentDuration!.isEmpty) rentDuration = null;
        }
      }
      
      var areaR = ad.attributes!['area'] ?? dyn['area'];
      if (areaR != null) area = areaR.toString().replaceAll(RegExp(r'[^0-9]'), '');
    }

    if (furnishedStatus != null) {
      if (furnishedStatus == 'مفروش' || furnishedStatus == 'Yes' || furnishedStatus == 'نعم') furnishedStatus = 'مفروشة';
      if (furnishedStatus == 'غير مفروش' || furnishedStatus == 'No' || furnishedStatus == 'لا') furnishedStatus = 'غير مفروشة';
    }

    if (beds != null && beds > 0) specs.add(_Spec(Icons.bed_outlined, '$beds غرف'));
    if (baths != null && baths > 0) specs.add(_Spec(Icons.bathtub_outlined, '$baths حمام'));
    if (furnishedStatus != null && furnishedStatus!.trim().isNotEmpty) specs.add(_Spec(Icons.chair_outlined, furnishedStatus!));
    if (area != null && area!.trim().isNotEmpty && area != '0') specs.add(_Spec(Icons.square_foot, '$area م٢'));
    if (floor != null && floor!.trim().isNotEmpty && floor != '0') specs.add(_Spec(Icons.stairs_outlined, floor!));
    if (buildingAge != null && buildingAge!.trim().isNotEmpty && buildingAge != '0') specs.add(_Spec(Icons.calendar_today_outlined, buildingAge!));
    if (rentDuration != null && rentDuration!.trim().isNotEmpty && rentDuration != 'غير محدد') specs.add(_Spec(Icons.access_time, rentDuration!));

    return SizedBox(
      height: 44,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: specs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(specs[i].icon, size: 16, color: _accent),
            const SizedBox(width: 8),
            Text(specs[i].label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black87)),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 5. DESCRIPTION
  // ═══════════════════════════════════════════════
  Widget _buildDescriptionCard() {
    final isLong = ad.description.length > 200;
    return _sectionCard(Icons.description_outlined, 'الوصف',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedCrossFade(
          firstChild: Text(ad.description, maxLines: 5, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, height: 1.8, fontWeight: FontWeight.w500, color: Color(0xFF334155), letterSpacing: 0.2)),
          secondChild: Text(ad.description, style: const TextStyle(fontSize: 15, height: 1.8, fontWeight: FontWeight.w500, color: Color(0xFF334155), letterSpacing: 0.2)),
          crossFadeState: _descExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        if (isLong) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _descExpanded = !_descExpanded),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_descExpanded ? 'عرض أقل' : 'قراءة المزيد',
                  style: const TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 13)),
              Icon(_descExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: _accent, size: 18),
            ]),
          ),
        ],
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  // 6. QUALITIES TABLE
  // ═══════════════════════════════════════════════
  Widget _buildQualitiesCard() {
    final q = <MapEntry<String, String>>[];
    
    String _clean(String? val) {
      if (val == null) return '';
      return val.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "").trim();
    }

    final d = ad.sharedRoomDetails;
    if (d != null) {
      final rentDur = _clean(d.rentDuration);
      if (rentDur.isNotEmpty && rentDur != 'غير محدد') q.add(MapEntry('مدة الإيجار', rentDur));
      final floorStr = _clean(d.floor);
      if (floorStr.isNotEmpty && floorStr != '0') q.add(MapEntry('الطابق', floorStr));
      final ageStr = _clean(d.buildingAge);
      if (ageStr.isNotEmpty && ageStr != '0') q.add(MapEntry('عمر البناء', ageStr));
      if (d.rooms != null && d.rooms! > 0) q.add(MapEntry('عدد الغرف', '${d.rooms}'));
      if (d.bathrooms != null && d.bathrooms! > 0) q.add(MapEntry('عدد الحمامات', '${d.bathrooms}'));
      final furnishedStr = _clean(d.furnished);
      if (furnishedStr.isNotEmpty) q.add(MapEntry('مفروشة؟', furnishedStr));
      final roomTypeStr = _clean(d.roomType);
      if (roomTypeStr.isNotEmpty) q.add(MapEntry('نوع السكن', roomTypeStr));
      final roomCapStr = _clean(d.roomCapacity);
      if (roomCapStr.isNotEmpty && roomCapStr != '0') q.add(MapEntry('السعة', roomCapStr));
      if (d.currentOccupants != null && d.currentOccupants! > 0) q.add(MapEntry('عدد السكان', '${d.currentOccupants} أشخاص'));
      final bathroomTypeStr = _clean(d.bathroomType);
      if (bathroomTypeStr.isNotEmpty) q.add(MapEntry('نوع الحمام', bathroomTypeStr));
      final paymentFreqStr = _clean(d.paymentFrequency);
      if (paymentFreqStr.isNotEmpty && paymentFreqStr != 'غير محدد') q.add(MapEntry('طريقة الدفع', paymentFreqStr));
      if (d.insuranceRequired != null) q.add(MapEntry('التأمين', d.insuranceRequired! ? 'مطلوب' : 'غير مطلوب'));
      final smokingStr = _clean(d.smokingRules);
      if (smokingStr.isNotEmpty) q.add(MapEntry('التدخين', smokingStr));
      final quietStr = _clean(d.quietnessRules);
      if (quietStr.isNotEmpty) q.add(MapEntry('الهدوء', quietStr));
      final guestsStr = _clean(d.guestsRules);
      if (guestsStr.isNotEmpty) q.add(MapEntry('الزوار', guestsStr));
      final petsStr = _clean(d.petsRules);
      if (petsStr.isNotEmpty) q.add(MapEntry('الحيوانات الأليفة', petsStr));
      final cleanStr = _clean(d.cleaningRules);
      if (cleanStr.isNotEmpty) q.add(MapEntry('النظافة', cleanStr));
    }

    if (ad.attributes != null) {
      if (ad.attributes!['payment_method'] != null) {
         q.add(MapEntry('طريقة الدفع', ad.attributes!['payment_method'].toString()));
      }
      if (ad.attributes!['down_payment'] != null && ad.attributes!['down_payment'].toString() != '0.0' && ad.attributes!['down_payment'].toString() != '0') {
         q.add(MapEntry('الدفعة الأولى', ad.attributes!['down_payment'].toString() + ' دينار'));
      }
      
      final Map<String, dynamic> dyn = {};
      if (ad.attributes!['dynamic_data'] is Map) {
         dyn.addAll(Map<String, dynamic>.from(ad.attributes!['dynamic_data']));
      }
      if (ad.attributes!['area'] != null) dyn['area'] = ad.attributes!['area'].toString() + ' م٢';
      if (ad.attributes!['rooms'] != null) dyn['bedrooms'] = ad.attributes!['rooms'];
      if (ad.attributes!['bathrooms'] != null) dyn['bathrooms'] = ad.attributes!['bathrooms'];
      if (ad.attributes!['furnished'] != null) dyn['furnishing'] = ad.attributes!['furnished'];
      if (ad.attributes!['floor'] != null) dyn['floor'] = ad.attributes!['floor'];
      if (ad.attributes!['building_age'] != null) dyn['age'] = ad.attributes!['building_age'];
      if (ad.attributes!['rent_duration'] != null) dyn['rent_duration'] = ad.attributes!['rent_duration'];

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
              'street_width_1': 'عرض الشارع 1', 'street_width_2': 'عرض الشارع 2', 'distance_to_service': 'مسافة الخدمات',
              'duration': 'المدة', 'year': 'سنة الصنع', 'transmission': 'ناقل الحركة',
              'fuel': 'الوقود', 'mileage': 'المسافة المقطوعة', 'condition': 'الحالة',
              'brand': 'الماركة', 'model': 'الموديل', 'facade': 'الواجهة',
              'monthly_building_fee': 'رسوم الخدمات المتوقعة', 'custom_security_deposit': 'قيمة التأمين',
              'security_deposit_type': 'مبلغ التأمين',
              'engine_capacity': 'سعة المحرك (CC)', 'previous_owners': 'عدد الملاك السابقين',
              'regional_specs': 'المصدر', 'rims_size': 'قياس الجنط',
              'body_type': 'نوع الهيكل', 'seats_count': 'عدد المقاعد',
              'exterior_color': 'اللون الخارجي', 'interior_color': 'اللون الداخلي',
              'insurance_status': 'التأمين', 'inspection_date': 'تاريخ فحص السيارة',
              'insurance_required': 'تأمين مطلوب',
              'inspection_result': 'فحص السيارة', 'autoscore_result': 'تقييم AutoScore', 
              'autoscore_date': 'تاريخ تقييم AutoScore', 'vin_number': 'رقم الشاصي',
              'cylinders': 'عدد الأسطوانات', 'cooling_system': 'نظام التبريد',
              'fuel_type': 'نوع الوقود', 'final_drive': 'نظام الدفع',
              'engine_condition': 'حالة المحرك', 'frame_condition': 'حالة الهيكل',
              'paint_condition': 'حالة الطلاء', 'tires_condition': 'حالة الإطارات',
              'battery_condition': 'حالة البطارية', 'brakes_system': 'نظام الفرامل',
              'license_status': 'حالة الترخيص', 'license_expiry': 'تاريخ انتهاء الترخيص',
              'accident_history': 'حالة الحوادث', 'color': 'اللون',
              'part_type': 'نوع القطعة', 'origin_country': 'بلد المنشأ', 'part_number': 'رقم القطعة',
              'warranty': 'الضمان', 'quantity': 'الكمية المتوفرة', 'packaging': 'حالة التغليف',
              'compatible_brand': 'ماركة السيارة المتوافقة', 'compatible_model': 'موديل السيارة',
              'compatible_years': 'سنوات التوافق', 'compatible_generation': 'جيل السيارة',
              'engine_capacity_comp': 'سعة المحرك المطابقة (cc)', 'fuel_type_comp': 'نوع الوقود',
              'cylinders_comp': 'عدد الأسطوانات', 'engine_code': 'كود المحرك', 'aspiration': 'نوع السحب',
              'block_material': 'المادة', 'cooling_type': 'نوع التبريد',
              'gearbox_type': 'نوع القير', 'gear_count': 'عدد الغيارات', 'drivetrain': 'نظام الدفع',
              'clutch_type': 'نوع القابض', 'gearbox_code': 'كود القير',
              'part_position': 'الإتجاه', 'part_color': 'اللون', 'part_material': 'مادة الصنع',
              'visual_condition': 'الحالة المظهرية',
              'voltage': 'الجهد الكهربائي', 'system_type': 'نوع النظام', 'screen_os': 'نظام التشغيل',
              'screen_size': 'حجم الشاشة (إنش)', 'electrical_power': 'القدرة', 'connection_type': 'نوع التوصيل',
              'rim_diameter': 'مقاس القطر (إنش)', 'tire_width': 'عرض الإطار', 'tire_aspect_ratio': 'نسبة الارتفاع',
              'dot_date': 'سنة التصنيع (DOT)', 'pcd': 'عدد البراغي (PCD)', 'tire_type': 'نوع الإطار',
              'tread_condition': 'حالة المسنن',
              'oil_viscosity': 'اللزوجة', 'oil_type': 'نوع الزيت', 'volume': 'الحجم', 'oil_standard': 'معيار الجودة',
              'interior_material': 'المادة الخام', 'interior_part_color': 'اللون الداخلي',
              'surface_compatibility': 'التوافقية', 'pieces_count': 'عدد القطع',
              'certification': 'الشهادة', 'power_source': 'نوع الطاقة', 'usage_scale': 'نطاق الاستخدام',
              'stage_rating': 'مرحلة الأداء', 'security_grade': 'درجة الأمان',
              'functioning_status': 'القدرة التشغيلية', 'usage_duration': 'مدة الاستخدام السابق',
              'reason_for_sale': 'سبب البيع', 'installation_available': 'خدمة التركيب',
              'installation_cost': 'تكلفة التركيب', 'shipping_available': 'خدمة الشحن',
              'shipping_duration': 'مدة الشحن',
              'plate_number': 'الرقم', 'plate_code': 'الترميز / الفئة', 'vehicle_type': 'نوع المركبة',
              'digits_count': 'عدد الخانات', 'sequence_type': 'نوع التسلسل', 'repetition_pattern': 'نمط التكرار',
              'symmetry_type': 'التناظر', 'additional_patterns': 'أنماط إضافية', 'special_pattern': 'نمط التميز',
              'plate_condition': 'حالة اللوحة', 'fines_exist': 'وجود مخالفات', 'fines_value': 'قيمة المخالفات',
              'ad_purpose': 'الغرض من الإعلان', 'seller_type': 'نوع المعلن', 'pet_breed': 'السلالة',
              'pet_gender': 'الجنس', 'pet_age': 'العمر', 'dominant_color': 'اللون',
              'litter_trained': 'مدربة على ليتر بوكس', 'sings_breeds': 'يغرد / منتج',
              'health_vaccinations': 'التطعيمات', 'health_sterilization': 'التعقيم', 'microchip': 'المايكروتشيب',
              'training_level': 'مستوى التدريب', 'current_housing': 'التربية الحالية', 'temperament': 'الطبع',
              'water_type': 'نوع المياه', 'fish_type': 'النمط', 'aquarium_material': 'مادة الحوض',
              'aquarium_capacity': 'السعة (لتر)', 'aquarium_dimensions': 'الأبعاد', 'lighting_type': 'نوع الإضاءة',
              'filter_power': 'قوة الفلترة', 'food_classification': 'تصنيف الغذاء', 'brand_name': 'العلامة التجارية',
              'item_size_weight': 'الحجم/الوزن', 'expiration_date': 'تاريخ الانتهاء', 'product_category': 'نوع المنتج',
              'manufacturing_material': 'المادة المصنعة', 'item_size': 'المقاس', 'origin_source': 'مصدر الحيوان',
              'delivery_options': 'خيارات التوصيل', 'free_accessories': 'ملحقات مجانية',
            };

        // Extra fallbacks for lands/real estate just in case
        qualityLabels.putIfAbsent('property_type', () => 'نوع العقار');
        qualityLabels.putIfAbsent('usage_type', () => 'نوع الاستخدام');
        qualityLabels.putIfAbsent('residential_type', () => 'النوع السكني');

        for (var entry in dyn.entries) {
          final val = entry.value;
          if (val != null) {
            String strVal;
            if (val is List) {
              if (val.isEmpty) continue;
              strVal = val.join('، ');
            } else {
              strVal = val.toString();
            }
            strVal = strVal.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "").trim();
            if (strVal.toLowerCase() == 'true') strVal = 'نعم';
            if (strVal.toLowerCase() == 'false') strVal = 'لا';
            if (strVal.isNotEmpty && strVal != 'null' && strVal != '0' && strVal != '0.0' && strVal != '0.00' && strVal != 'none' && strVal != 'غير محدد') {
              
              final translatedKey = qualityLabels[entry.key];
              
              // If the key is not in the translation map and contains english letters, hide it completely.
              if (translatedKey == null && RegExp(r'[a-zA-Z]').hasMatch(entry.key)) {
                continue;
              }
              
              final displayKey = translatedKey ?? entry.key;

              // If the value contains english letters AND does not contain Arabic letters, hide it completely.
              if (RegExp(r'[a-zA-Z]').hasMatch(strVal) && !strVal.contains(RegExp(r'[\u0600-\u06FF]'))) {
                continue;
              }

              if (!q.any((e) => e.key == displayKey)) {
                 q.add(MapEntry(displayKey, strVal));
              }
            }
          }
        }
      }
    }

    if (q.isEmpty) return const SizedBox.shrink();

    final visible = _showAllQualities ? q.length : (q.length > 5 ? 5 : q.length);
    final hasMore = q.length > 5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        _sectionHdr(Icons.list_alt_rounded, 'المواصفات'),
        ...List.generate(visible, (i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: i.isEven ? Colors.transparent : const Color(0xFFF8F9FD),
          child: Row(children: [
            Expanded(flex: 2, child: Text(q[i].key, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey.shade500))),
            Expanded(flex: 3, child: Text(q[i].value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87))),
          ]),
        )),
        if (hasMore)
          InkWell(
            onTap: () => setState(() => _showAllQualities = !_showAllQualities),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_showAllQualities ? 'عرض أقل' : 'شاهد المزيد',
                    style: const TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(width: 4),
                Icon(_showAllQualities ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: _accent, size: 20),
              ]),
            ),
          ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  // 7. AMENITIES — FULLY DYNAMIC
  // ═══════════════════════════════════════════════
  Widget _buildAmenitiesCard() {
    final groups = <String, List<String>>{};
    final d = ad.sharedRoomDetails;
    if (d != null) {
      if (d.keyFeatures.isNotEmpty) groups['المميزات الرئيسية'] = d.keyFeatures;
      if (d.roomFeatures.isNotEmpty) groups['مزايا الغرفة'] = d.roomFeatures;
      if (d.roomContents.isNotEmpty) groups['محتويات الغرفة'] = d.roomContents;
      if (d.sharedSpaces.isNotEmpty) groups['المساحات المشتركة'] = d.sharedSpaces;
      if (d.kitchenAppliances.isNotEmpty) groups['تجهيزات المطبخ'] = d.kitchenAppliances;
      if (d.laundryAppliances.isNotEmpty) groups['تجهيزات الغسيل'] = d.laundryAppliances;
      if (d.buildingFeatures.isNotEmpty) groups['مزايا المبنى'] = d.buildingFeatures;
      if (d.targetAudience.isNotEmpty) groups['الفئة المستهدفة'] = d.targetAudience;
      if (d.rentIncludes.isNotEmpty) groups['الإيجار يشمل'] = d.rentIncludes;
      if (d.nearbyPlaces.isNotEmpty) groups['قريب من'] = d.nearbyPlaces;
    }
    
    if (ad.attributes != null) {
      if (ad.attributes!['nearby_landmarks'] != null && ad.attributes!['nearby_landmarks'] is List) {
         groups['معالم قريبة ومجاورة'] = (ad.attributes!['nearby_landmarks'] as List).cast<String>();
      }

      final dyn = ad.attributes!['dynamic_data'] as Map<String, dynamic>?;
      if (dyn != null) {
        final Map<String, String> amenityLabels = {
          'main_features': 'المزايا الرئيسية', 'extra_features': 'المزايا الإضافية والمرافق',
          'interior_details': 'التفاصيل الداخلية', 'exterior_details': 'التفاصيل الخارجية',
          'nearby': 'مواقع قريبة', 'features': 'المميزات والإضافات',
          'services': 'الخدمات الواصلة', 'facilities': 'المرافق',
          'accessories': 'يتوفر مع', 'building_fees_status': 'رسوم الخدمات',
          'target_tenants': 'الفئة المستهدفة', 'property_restrictions': 'شروط إضافية',
          'available_services': 'الخدمات المتوفرة', 'extra_features': 'معلومات احترافية اضافية',
          'allowed_usage': 'الاستعمالات المسموحة',
          'legal_status_checks': 'الوضع القانوني', 'nearby_locations': 'معالم قريبة ومجاورة',
          'documents': 'الوثائق', 'exterior_features': 'الميزات الخارجية',
          'system_compatibility': 'توافق النظام', 'item_features': 'ميزات السلعة',
          'facade': 'الواجهة',
          'water_supply': 'مصادر المياه', 'meters_setup': 'العدادات',
          'cooling_features': 'التبريد', 'heating_features': 'التدفئة',
          'water_heating_features': 'تسخين المياه',
          'interior_features_1': 'أنظمة الراحة والمقاعد', 'interior_features_2': 'الزجاج والإكسسوارات',
          'exterior_lighting': 'الإنارة والرؤية', 'exterior_addons': 'الهيكل والإضافات',
          'tech_entertainment': 'الترفيه والاتصال', 'tech_driving': 'القيادة والتحكم',
          'tech_safety': 'الأمان والسلامة', 'tech_advanced': 'الأنظمة المتقدمة',
          // Facebook Scraper extracted keys:
          'key_features': 'المميزات الرئيسية', 'room_features': 'مزايا الغرفة',
          'room_contents': 'محتويات الغرفة', 'shared_spaces': 'المساحات المشتركة',
          'kitchen_appliances': 'تجهيزات المطبخ', 'laundry_appliances': 'تجهيزات الغسيل',
          'building_features': 'مزايا المبنى', 'target_audience': 'الفئة المستهدفة',
          'rent_includes': 'الإيجار يشمل', 'nearby_places': 'قريب من',
          'available_services': 'الخدمات المتوفرة', 'suggested_tags': 'كلمات مفتاحية',
        };
        for (var entry in dyn.entries) {
          if (entry.value is List && (entry.value as List).isNotEmpty) {
            groups[amenityLabels[entry.key] ?? entry.key] = (entry.value as List).cast<String>();
          }
        }
      }
    }

    if (groups.isEmpty) return const SizedBox.shrink();

    final iconMap = {
      'المميزات الرئيسية': Icons.star_outline, 'مزايا الغرفة': Icons.bedroom_child_outlined,
      'محتويات الغرفة': Icons.inventory_2_outlined, 'المساحات المشتركة': Icons.weekend_outlined,
      'تجهيزات المطبخ': Icons.kitchen_outlined, 'تجهيزات الغسيل': Icons.local_laundry_service_outlined,
      'مزايا المبنى': Icons.apartment_outlined, 'الفئة المستهدفة': Icons.group_outlined,
      'الإيجار يشمل': Icons.receipt_long_outlined, 'قريب من': Icons.place_outlined,
      'التفاصيل الداخلية': Icons.meeting_room_outlined, 'التفاصيل الخارجية': Icons.storefront_outlined,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHdr(Icons.verified_outlined, 'التفاصيل والمزايا'),
        ...groups.entries.map((e) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(iconMap[e.key] ?? Icons.info_outline, size: 16, color: _accent),
              const SizedBox(width: 8),
              Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: e.value.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_accent.withOpacity(0.06), _accent.withOpacity(0.02)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accent.withOpacity(0.15)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, size: 14, color: _accent.withOpacity(0.7)),
                const SizedBox(width: 6),
                Flexible(child: Text(item, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87))),
              ]),
            )).toList()),
          ]),
        )),
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  // 8. TAGS SECTION
  // ═══════════════════════════════════════════════
  Widget _buildTagsSection() {
    if (ad.tags.isEmpty) return const SizedBox.shrink();
    return _sectionCard(Icons.label_outline, 'التصنيفات',
      child: Wrap(spacing: 8, runSpacing: 8, children: ad.tags.map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accent.withOpacity(0.2)),
        ),
        child: Text(tag, style: const TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 12)),
      )).toList()),
    );
  }

  // ═══════════════════════════════════════════════
  // 9. LOCATION
  // ═══════════════════════════════════════════════
  Widget _buildLocationCard() {
    return _sectionCard(Icons.location_on_outlined, 'الموقع',
      child: Container(
        height: 140,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
        child: Stack(children: [
          Center(child: Icon(Icons.map_outlined, size: 50, color: Colors.grey.shade300)),
          Positioned(bottom: 12, right: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
              child: Row(children: [
                Icon(Icons.location_on, color: Colors.red.shade400, size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text(ad.location, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              ]),
            )),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 10. AD INFO
  // ═══════════════════════════════════════════════
  Widget _buildAdInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
      child: Column(children: [
        _infoLine('رقم الإعلان', '#${ad.id}'),
        Divider(color: Colors.grey.shade100, height: 20),
        _infoLine('تاريخ النشر', ad.createdAt != null
            ? '${ad.createdAt!.day}/${ad.createdAt!.month}/${ad.createdAt!.year}'
            : 'غير محدد'),
        Divider(color: Colors.grey.shade100, height: 20),
        _infoLine('المشاهدات', '${ad.views}'),
        if (ad.tags.isNotEmpty) ...[
          Divider(color: Colors.grey.shade100, height: 20),
          _infoLine('التصنيف', ad.tags.first),
        ],
      ]),
    );
  }

  Widget _infoLine(String label, String value) => Row(children: [
    Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade500))),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black87)),
  ]);

  // ═══════════════════════════════════════════════
  // 11. SAFETY TIPS
  // ═══════════════════════════════════════════════
  Widget _buildSafetyTips() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.shield_outlined, color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 8),
          Text('نصائح الأمان', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.amber.shade800)),
        ]),
        const SizedBox(height: 12),
        _safetyRow('لا تدفع مبالغ مالية قبل معاينة العقار'),
        const SizedBox(height: 6),
        _safetyRow('تأكد من هوية المعلن والأوراق الثبوتية'),
        const SizedBox(height: 6),
        _safetyRow('قم بالمعاينة الشخصية في مكان عام وآمن'),
      ]),
    );
  }

  Widget _safetyRow(String text) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(Icons.check_circle_outline, size: 16, color: Colors.amber.shade700),
    const SizedBox(width: 8),
    Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600))),
  ]);

  // ═══════════════════════════════════════════════
  // 12. RELATED ADS
  // ═══════════════════════════════════════════════
  Widget _buildRelatedAds() {
    if (_isLoadingAds) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
    if (_relatedAds.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth / 1.25;
    final imageHeight = 150.0;
    final textHeight = 60.0;
    final cardHeight = imageHeight + textHeight;
    final gridHeight = (cardHeight * 2) + 16.0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('إعلانات مشابهة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF1E293B))),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: gridHeight,
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: cardWidth,
            ),
            itemCount: _relatedAds.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _relatedAds.length) {
                return const Center(child: CircularProgressIndicator());
              }
              final r = _relatedAds[i];
              return GestureDetector(
                onTap: () => Navigator.pushReplacement(ctx, MaterialPageRoute(builder: (_) => AdDetailsPage(ad: r))),
                child: Container(
                  color: Colors.transparent, // Borderless, premium look
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Section
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: imageHeight,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              r.images.isNotEmpty
                                ? ApiService.networkImage(r.images.first, fit: BoxFit.cover, errorWidget: Container(color: Colors.grey.shade100, child: const Icon(Icons.image, color: Colors.grey)))
                                : Container(color: Colors.grey.shade100, child: Center(child: Icon(Icons.image, color: Colors.grey.shade400))),
                              // Gradient Overlay for text
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                      colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent, Colors.transparent],
                                      stops: const [0.0, 0.4, 1.0],
                                    )
                                  ),
                                )
                              ),
                              // Price Overlay
                              Positioned(
                                bottom: 12, left: 12, right: 12,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${r.price.toStringAsFixed(0)} JOD',
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16, fontFamily: 'Roboto', letterSpacing: 0.5),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(6)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.photo_library_outlined, color: Colors.white, size: 10),
                                          const SizedBox(width: 4),
                                          Text('${r.images.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (r.isHot)
                                Positioned(
                                  top: 10, right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.orange.shade600, borderRadius: BorderRadius.circular(8)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.local_fire_department, color: Colors.white, size: 12),
                                        SizedBox(width: 4),
                                        Text('لقطة', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Text Section
                      Padding(
                        padding: const EdgeInsets.only(top: 10, right: 4, left: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, color: Color(0xFF64748B), size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    r.location, 
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  // 13. CONTACT BAR with WhatsApp
  // ═══════════════════════════════════════════════
  Widget _buildContactBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
          decoration: BoxDecoration(color: _card.withOpacity(0.92),
            border: Border(top: BorderSide(color: Colors.grey.shade200))),
          child: Row(children: [
            // WhatsApp
            GestureDetector(
              onTap: () async {
                final phone = ad.phoneNumber;
                if (phone == null || phone.isEmpty) {
                  _snack('رقم الهاتف غير متوفر');
                  return;
                }
                String waPhone = phone;
                // Record interaction
                ApiService().recordAdInteractionChat(ad.id);
                AnalyticsEngine().logContactAgentInitiated(
                  propertyId: ad.id.toString(),
                  contactMethod: 'whatsapp',
                );
                if (waPhone.startsWith('0')) {
                  waPhone = '962' + waPhone.substring(1);
                } else if (waPhone.startsWith('+')) {
                  waPhone = waPhone.substring(1);
                }
                final uri = Uri.parse('whatsapp://send?phone=$waPhone');
                final fallbackUri = Uri.parse('https://wa.me/$waPhone');
                try {
                  bool launched = false;
                  if (await canLaunchUrl(uri)) {
                    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  if (!launched) {
                    await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  _snack('تعذر فتح تطبيق واتساب');
                }
              },
              child: Container(
                height: 52, width: 52,
                decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                child: const Icon(Icons.chat, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 10),
            // Chat
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  if (!authProvider.isAuthenticated) {
                    PremiumLoginBottomSheet.show(
                      context,
                      title: 'دردشة',
                      subtitle: 'سجل الدخول للدردشة مع البائع داخل التطبيق بأمان',
                      onLoginSuccess: () {}, // Handled by user clicking again
                    );
                    return;
                  }
                  
                  final currentUserId = authProvider.userData?['sub']?.toString();
                  if (currentUserId == null) {
                    _snack('حدث خطأ في معلومات الحساب');
                    return;
                  }
                  
                  if (currentUserId == ad.userId.toString()) {
                    _snack('لا يمكنك بدء محادثة مع نفسك');
                    return;
                  }

                  // Record interaction
                  ApiService().recordAdInteractionChat(ad.id);
                  AnalyticsEngine().logContactAgentInitiated(
                    propertyId: ad.id.toString(),
                    contactMethod: 'chat',
                  );

                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PremiumChatScreen(
                      adId: ad.id.toString(),
                      adTitle: ad.title,
                      adPrice: ad.price.toStringAsFixed(0),
                      adImageUrl: ad.images.isNotEmpty ? ad.images.first : '',
                      isSeller: false,
                      currentUserId: currentUserId,
                      currentUserName: authProvider.userData?['full_name'] ?? authProvider.userData?['username'] ?? 'مستخدم',
                      currentUserPhone: authProvider.userData?['phone']?.toString(),
                      otherUserId: ad.userId.toString(),
                      otherUserName: ad.ownerName,
                      otherUserPhone: ad.phoneNumber,
                    )
                  ));
                },
                child: Container(height: 52,
                  decoration: BoxDecoration(border: Border.all(color: _accent, width: 2), borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline, color: _accent, size: 20),
                    SizedBox(width: 8),
                    Text('دردشة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _accent)),
                  ]))),
              ),
            ),
            const SizedBox(width: 10),
            // Phone
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () async {
                  final String? phone = ad.phoneNumber;
                  if (phone == null || phone.isEmpty) {
                    _snack('رقم الهاتف غير متوفر');
                    return;
                  }
                  
                  if (!_showPhone) {
                    setState(() => _showPhone = true);
                    // Record interaction when they reveal the number
                    ApiService().recordAdInteractionPhone(ad.id);
                    AnalyticsEngine().logContactAgentInitiated(
                      propertyId: ad.id.toString(),
                      contactMethod: 'phone_reveal',
                    );
                    return;
                  }
                  
                  // Also record interaction when they actually dial
                  ApiService().recordAdInteractionPhone(ad.id);
                  AnalyticsEngine().logContactAgentInitiated(
                    propertyId: ad.id.toString(),
                    contactMethod: 'phone_dial',
                  );
                  
                  final Uri telUri = Uri.parse('tel:$phone');
                  try {
                    if (await canLaunchUrl(telUri)) {
                      await launchUrl(telUri);
                    } else {
                      _snack('تعذر فتح تطبيق الاتصال');
                    }
                  } catch (e) {
                    _snack('تعذر فتح تطبيق الاتصال');
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_accent, _accentDark]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.phone, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _showPhone && ad.phoneNumber != null ? ad.phoneNumber! : 'أظهر الرقم',
                        key: ValueKey(_showPhone),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                      ),
                    ),
                  ])),
                ),
              ),
            ),
          ]),
        )),
    );
  }

  // ═══════════════════════════════════════════════
  // 14. SELLER INFO
  // ═══════════════════════════════════════════════
  Widget _buildSellerCard() {
    String agentType = 'مستخدم';
    if (ad.attributes != null && ad.attributes!['advertiser_type'] != null) {
      agentType = ad.attributes!['advertiser_type'].toString();
    }

    return GestureDetector(
      onTap: () {
        if (ad.userId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlocProvider(
                create: (_) => ProfileBloc(
                  repository: ApiProfileRepositoryImpl(),
                  targetUserId: ad.userId.toString(),
                ),
                child: PublicProfileScreen(userId: ad.userId.toString()),
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: const Icon(Icons.person, color: Color(0xFF94A3B8), size: 28),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(ad.ownerName ?? 'مستخدم جديد', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('$agentType • يرد خلال 5 دقائق', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                )
              ],
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        )
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // SHARED BUILDERS
  // ═══════════════════════════════════════════════
  Widget _sectionCard(IconData icon, String title, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _accent.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: _accent)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  Widget _sectionHdr(IconData icon, String title) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
    decoration: BoxDecoration(color: _accent.withOpacity(0.04),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: _accent)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
    ]),
  );
}



class _Spec {
  final IconData icon;
  final String label;
  _Spec(this.icon, this.label);
}

