import 'package:flutter/material.dart';
import 'dart:math';
import '../models/ad.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/chat/presentation/screens/premium_chat_screen.dart';
import 'premium_login_bottom_sheet.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'premium_video_player.dart';
import 'full_screen_media_gallery.dart';
import '../providers/app_provider.dart';
import 'premium_share_bottom_sheet.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/impression_tracker.dart';

class PremiumRealEstateCard extends StatefulWidget {
  final Ad ad;
  final VoidCallback onTap;
  final String? searchQuery;
  final bool isPreview;

  const PremiumRealEstateCard({
    Key? key,
    required this.ad,
    required this.onTap,
    this.searchQuery,
    this.isPreview = false,
  }) : super(key: key);

  @override
  State<PremiumRealEstateCard> createState() => _PremiumRealEstateCardState();
}

class _PremiumRealEstateCardState extends State<PremiumRealEstateCard> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentImageIndex = 0;
  bool _isFavorite = false;
  bool _isHovered = false;

  // Mocked Data for WOW factor (as approved in plan)
  late final int _walkScore;
  late final double _rating;
  late final bool _negotiable;
  late final bool _mortgage;
  late final bool _has360;
  late final bool _hasVideo;


  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Generate stable deterministic mock data based on Ad ID
    final r = Random(widget.ad.id);
    _walkScore = 75 + r.nextInt(25); // 75-99
    _rating = 4.0 + (r.nextInt(10) / 10); // 4.0 - 4.9
    final lowerDesc = widget.ad.description.toLowerCase();
    _negotiable = widget.ad.tags.any((t) => t.contains('تفاوض') || t.contains('negotiable')) || 
                  lowerDesc.contains('قابل للتفاوض') || lowerDesc.contains('تفاوض');
                  
    _mortgage = widget.ad.tags.any((t) => t.contains('تقسيط') || t.contains('اقساط') || t.contains('installment')) || 
                lowerDesc.contains('تقسيط') || lowerDesc.contains('اقساط');
    _has360 = widget.ad.attributes != null && widget.ad.attributes!['virtual_tour_url'] != null;
    _hasVideo = widget.ad.attributes != null && widget.ad.attributes!['video_url'] != null;
    
    final appProvider = context.read<AppProvider>();
    if (appProvider.locallySavedAdIds.contains(widget.ad.id)) {
      _isFavorite = true;
    } else if (appProvider.locallyUnsavedAdIds.contains(widget.ad.id)) {
      _isFavorite = false;
    } else {
      _isFavorite = widget.ad.isSaved;
    }
  }

  @override
  void didUpdateWidget(PremiumRealEstateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final appProvider = context.read<AppProvider>();
    if (appProvider.locallySavedAdIds.contains(widget.ad.id)) {
      _isFavorite = true;
    } else if (appProvider.locallyUnsavedAdIds.contains(widget.ad.id)) {
      _isFavorite = false;
    } else if (widget.ad.isSaved != _isFavorite) {
      _isFavorite = widget.ad.isSaved;
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.isPreview) return;
    
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
        context.read<AppProvider>().toggleFavoriteCount(isNowSaved, adId: widget.ad.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFavorite = originalState);
        if (e.toString().contains('Unauthorized')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('يرجى تسجيل الدخول أولاً', style: TextStyle(fontWeight: FontWeight.w600)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF2D2D2D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('حدث خطأ أثناء حفظ الإعلان.', style: TextStyle(fontWeight: FontWeight.w600)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF2D2D2D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Formatting helpers
  String _formatNumber(int num) {
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
    return num.toString();
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) {
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    }
    if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return 'منذ ${diff.inMinutes} دقيقة';
    return 'الآن';
  }

  // Extract proper location
  String _getLocation() {
    final city = widget.ad.attributes?['city']?.toString();
    final region = widget.ad.attributes?['region']?.toString();
    if (city != null && city.isNotEmpty && region != null && region.isNotEmpty) {
      return '$city، $region';
    } else if (region != null && region.isNotEmpty) {
      return region;
    }
    return widget.ad.location;
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('ad_visibility_${widget.ad.id}'),
      onVisibilityChanged: (VisibilityInfo info) {
        if (!widget.isPreview && info.visibleFraction >= 0.5) {
          ImpressionTracker().trackImpression(widget.ad.id);
        }
      },
      child: GestureDetector(
        onTap: widget.ad.images.isNotEmpty ? widget.onTap : widget.onTap,
        onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 0.98 : 1.0),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        padding: const EdgeInsets.all(2), // small padding inside the border
        decoration: BoxDecoration(
          color: widget.ad.isFeatured || widget.ad.cpcBid > 0 ? const Color(0xFFFFFAEB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.ad.isFeatured || widget.ad.cpcBid > 0 
                ? const Color(0xFFD4AF37) // Premium Gold
                : Colors.grey.shade200, 
            width: widget.ad.isFeatured || widget.ad.cpcBid > 0 ? 2.0 : 1.5,
          ),
          boxShadow: [
            if (widget.ad.isFeatured || widget.ad.cpcBid > 0)
              BoxShadow(
                color: const Color(0xFFD4AF37).withOpacity(_isHovered ? 0.3 : 0.15),
                blurRadius: _isHovered ? 20 : 12,
                spreadRadius: _isHovered ? 4 : 2,
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.08 : 0.03),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopHeroSection(),
              _buildContentSection(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // --- SECTION 1: Top Hero Section ---
  Widget _buildTopHeroSection() {
    if (widget.ad.images.isEmpty) return const SizedBox.shrink();

    final images = widget.ad.images;

    return Column(
      children: [
        SizedBox(
          height: 280, // Increased height to match mockup
          child: Stack(
            children: [
              // 1. Carousel
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                itemBuilder: (context, index) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      _hasVideo && index == 0
                          ? PremiumVideoPlayer(
                              videoUrl: widget.ad.attributes!['video_url'] ?? widget.ad.videoUrl!,
                              thumbnailUrl: images[index],
                            )
                          : ApiService.networkImage(
                              images[index],
                              fit: BoxFit.cover,
                              errorWidget: const ColoredBox(
                                color: Color(0xFFF3F4F9),
                                child: Center(child: Icon(Icons.image, color: Colors.grey)),
                              ),
                            ),

                    ],
                  );
                },
              ),

              // 2. Top Right Overlays
              Positioned(
                top: 12,
                right: 12,
                child: Wrap(
                  spacing: 6,
                  children: [
                    _buildBlurBadge(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('${images.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    if (_hasVideo)
                      _buildBlurBadge(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.play_circle_outline, color: Colors.white, size: 14),
                      ),
                    if (_has360)
                      _buildBlurBadge(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.threed_rotation, color: Colors.white, size: 14),
                      ),
                    if (widget.ad.isHot)
                      _buildBlurBadge(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                            SizedBox(width: 4),
                            Text('لقطة', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    if (widget.ad.isFeatured)
                      _buildBlurBadge(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.star, color: Colors.amber, size: 14),
                            SizedBox(width: 4),
                            Text('مميز', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    if (widget.ad.cpcBid > 0)
                      _buildBlurBadge(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.campaign, color: Colors.blueAccent, size: 14),
                            SizedBox(width: 4),
                            Text('ممول', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // 3. Top Left Overlays (RTL: Top Right visual) - Favorite & Share
              Positioned(
                top: 12,
                left: 12,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (widget.isPreview) return;
                        PremiumShareBottomSheet.show(context, widget.ad);
                      },
                      child: _buildBlurBadge(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _toggleFavorite,
                      child: _buildBlurBadge(
                        padding: const EdgeInsets.all(8),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            key: ValueKey(_isFavorite),
                            color: _isFavorite ? Colors.redAccent : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Bottom Right Overlays - Fullscreen Scale Icon
              Positioned(
                bottom: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    // Record a view when opening fullscreen gallery directly
                    context.read<AppProvider>().addToRecentlyViewed(widget.ad);
                    
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => FullScreenMediaGallery(ad: widget.ad, initialIndex: _currentImageIndex)
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10), // Increased padding
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65), // Darker background
                      shape: BoxShape.circle, // Circular shape looks cleaner
                    ),
                    child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 26), // Bigger icon
                  ),
                ),
              ),

            ],
          ),
        ),
        
        // 5. Thumbnails Row
        if (images.length > 1)
          Container(
            height: 64,
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final isSelected = _currentImageIndex == index;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index, 
                      duration: const Duration(milliseconds: 300), 
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0075FF) : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(color: const Color(0xFF0075FF).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                      ] : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10), // inner radius slightly less than outer
                      child: ApiService.networkImage(
                        images[index],
                        fit: BoxFit.cover,
                        errorWidget: const ColoredBox(
                          color: Color(0xFFF1F5F9),
                          child: Icon(Icons.image, size: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }


  Widget _buildBlurBadge({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: Colors.black.withOpacity(0.35),
        // Normally we use BackdropFilter for true blur, but keeping it simple/performant:
        child: child,
      ),
    );
  }

  // --- SECTION 2: Content Section ---
  Widget _buildContentSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Price, Tags, and Location
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.ad.price.toStringAsFixed(0)} JOD',
                      style: const TextStyle(
                        fontFamily: 'Roboto', // For clean numbers
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                        color: Color(0xFF0075FF), // Brand Blue
                      ),
                    ),
                    if (_negotiable || _mortgage) const SizedBox(height: 6),
                    // Badges under the price
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (_negotiable)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: const Text('قابل للتفاوض 💸', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          if (_mortgage)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                   Icon(Icons.account_balance, size: 12, color: Color(0xFF2563EB)),
                                   SizedBox(width: 4),
                                   Text('متاح تقسيط🏦', style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Location on the left side
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFF94A3B8), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _getLocation(),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Title and Type
          _buildHighlightedTitle(),
          const SizedBox(height: 8),
          
          // Row 3: Professional Stats Row (Date, Views, Saves)
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: Colors.blueGrey.shade400),
              const SizedBox(width: 4),
              Text(
                widget.ad.createdAt != null ? _formatTimeAgo(widget.ad.createdAt!) : 'قبل ساعتين', 
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11, fontWeight: FontWeight.w500)
              ),
              if (widget.ad.views >= 10) ...[
                const SizedBox(width: 12),
                Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueGrey.shade300)),
                const SizedBox(width: 12),
                Icon(Icons.remove_red_eye_outlined, size: 12, color: Colors.blueGrey.shade400),
                const SizedBox(width: 4),
                Text(_formatNumber(widget.ad.views), style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
              if (widget.ad.favoritesCount >= 10) ...[
                const SizedBox(width: 12),
                Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueGrey.shade300)),
                const SizedBox(width: 12),
                Icon(Icons.favorite_border, size: 12, color: Colors.blueGrey.shade400),
                const SizedBox(width: 4),
                Text(_formatNumber(widget.ad.favoritesCount), style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Row 4: Specs Row (Bedrooms, Bathrooms, Area, etc.)
          _buildSpecsRow(),
          const SizedBox(height: 12),

          _buildDashedLine(),
          const SizedBox(height: 12),

          if (widget.ad.description.isNotEmpty) ...[
            Text(
              widget.ad.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.6,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Row 5: Smart Highlights (Tags)
          _buildSmartHighlightsRow(),
          const SizedBox(height: 16),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),


          // Row 7: Wide Actions
          _buildActionsRow(),
        ],
      ),
    );
  }

  Widget _buildHighlightedTitle() {
    if (widget.searchQuery == null || widget.searchQuery!.isEmpty) {
      return Text(
        widget.ad.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          height: 1.4,
          color: Color(0xFF1E293B),
        ),
      );
    }

    final queryWords = widget.searchQuery!.toLowerCase().split(' ').where((w) => w.length > 1).toList();
    if (queryWords.isEmpty) {
      return Text(widget.ad.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B)));
    }

    String pattern = queryWords.map((w) => RegExp.escape(w)).join('|');
    RegExp regex = RegExp('($pattern)', caseSensitive: false);
    Iterable<RegExpMatch> matches = regex.allMatches(widget.ad.title);
    
    if (matches.isEmpty) {
      return Text(widget.ad.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B)));
    }
    
    List<TextSpan> spans = [];
    int currentIndex = 0;
    for (RegExpMatch match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: widget.ad.title.substring(currentIndex, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(color: Color(0xFF0075FF), backgroundColor: Color(0xFFEFF6FF)),
      ));
      currentIndex = match.end;
    }
    if (currentIndex < widget.ad.title.length) {
      spans.add(TextSpan(text: widget.ad.title.substring(currentIndex)));
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          height: 1.4,
          color: Color(0xFF1E293B),
          fontFamily: 'Tajawal', // Best fallback
        ),
        children: spans,
      ),
    );
  }

  Widget _buildSpecsRow() {
    int? beds;
    int? baths;
    int? area;
    String? floor;
    String? furnishedStatus;
    String? rentDuration;
    String? zoningClassification;
    String? streetFacade;
    String? topography;
    String? ownershipType;

    // Extract real data if available
    if (widget.ad.sharedRoomDetails != null) {
      beds = widget.ad.sharedRoomDetails!.rooms;
      baths = widget.ad.sharedRoomDetails!.bathrooms;
      floor = widget.ad.sharedRoomDetails!.floor;
      
      final dynFurnished = widget.ad.sharedRoomDetails!.furnished;
      if (dynFurnished == 'مفروش' || dynFurnished == 'Yes' || dynFurnished == 'نعم') {
        furnishedStatus = 'مفروشة';
      } else if (dynFurnished == 'غير مفروش' || dynFurnished == 'No' || dynFurnished == 'لا') {
        furnishedStatus = 'غير مفروشة';
      } else {
        furnishedStatus = dynFurnished;
      }
      rentDuration = widget.ad.sharedRoomDetails!.rentDuration;
    }

    // Fallback and Attempt to extract area & specs from attributes
    if (widget.ad.attributes != null) {
      final dyn = widget.ad.attributes!['dynamic_data'] as Map<String, dynamic>? ?? {};
      
      var areaRaw = widget.ad.attributes!['area'] ?? dyn['area'];
      if (areaRaw != null) {
        area = int.tryParse(areaRaw.toString().replaceAll(RegExp(r'[^0-9]'), ''));
      }
      
      var bedsRaw = widget.ad.attributes!['rooms'] ?? dyn['bedrooms'];
      if (beds == null && bedsRaw != null) {
        beds = int.tryParse(bedsRaw.toString().replaceAll(RegExp(r'[^0-9]'), ''));
      }
      
      var bathsRaw = widget.ad.attributes!['bathrooms'] ?? dyn['bathrooms'];
      if (baths == null && bathsRaw != null) {
        baths = int.tryParse(bathsRaw.toString().replaceAll(RegExp(r'[^0-9]'), ''));
      }
      
      var floorRaw = widget.ad.attributes!['floor'] ?? dyn['floor'];
      if (floor == null && floorRaw != null) {
        floor = floorRaw.toString();
      }

      var furnRaw = widget.ad.attributes!['furnished'] ?? dyn['furnishing'];
      if (furnishedStatus == null && furnRaw != null) {
        var fs = furnRaw.toString();
        if (fs == 'مفروش' || fs == 'Yes' || fs == 'نعم') {
          furnishedStatus = 'مفروشة';
        } else if (fs == 'غير مفروش' || fs == 'No' || fs == 'لا') {
          furnishedStatus = 'غير مفروشة';
        } else {
          furnishedStatus = fs;
        }
      }
      
      var rentRaw = widget.ad.attributes!['rent_duration'] ?? dyn['rent_duration'];
      if (rentDuration == null && rentRaw != null) {
        rentDuration = rentRaw.toString();
      }

      var zoningRaw = widget.ad.attributes!['zoning_classification'] ?? dyn['zoning_classification'];
      if (zoningClassification == null && zoningRaw != null) {
        zoningClassification = zoningRaw.toString();
      }

      var facadeRaw = widget.ad.attributes!['street_facade'] ?? dyn['street_facade'];
      if (streetFacade == null && facadeRaw != null) {
        streetFacade = facadeRaw.toString();
      }

      var topoRaw = widget.ad.attributes!['topography'] ?? dyn['topography'];
      if (topography == null && topoRaw != null) topography = topoRaw.toString();
      
      var ownerRaw = widget.ad.attributes!['ownership_type'] ?? dyn['ownership_type'];
      if (ownershipType == null && ownerRaw != null) ownershipType = ownerRaw.toString();
    }

    // Try to extract from tags if still null
    if (area == null) {
      for (var t in widget.ad.tags) {
        if (t.contains('م٢') || t.contains('متر') || t.contains('m2') || t.contains('sqm')) {
          final parsed = int.tryParse(t.replaceAll(RegExp(r'[^0-9]'), ''));
          if (parsed != null && parsed > 0) {
            area = parsed;
            break;
          }
        }
      }
    }

    List<Widget> specChildren = [];

    Widget _specItem(IconData icon, String value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF475569))),
        ],
      );
    }

    if (beds != null && beds > 0) specChildren.add(_specItem(Icons.bed_outlined, '$beds غرف نوم'));
    if (baths != null && baths > 0) specChildren.add(_specItem(Icons.bathtub_outlined, '$baths حمّامات'));
    if (rentDuration != null && rentDuration!.isNotEmpty) specChildren.add(_specItem(Icons.calendar_month_outlined, rentDuration!));
    if (furnishedStatus != null && furnishedStatus!.isNotEmpty) specChildren.add(_specItem(Icons.chair_outlined, furnishedStatus!));
    if (area != null && area! > 0) specChildren.add(_specItem(Icons.square_foot, '$area م٢'));
    if (zoningClassification != null && zoningClassification!.isNotEmpty) specChildren.add(_specItem(Icons.category_outlined, zoningClassification!));
    if (streetFacade != null && streetFacade!.isNotEmpty) specChildren.add(_specItem(Icons.straighten_outlined, streetFacade!));
    if (topography != null && topography!.isNotEmpty) specChildren.add(_specItem(Icons.terrain_outlined, topography!));
    if (ownershipType != null && ownershipType!.isNotEmpty) specChildren.add(_specItem(Icons.assignment_ind_outlined, ownershipType!));
    if (floor != null && floor!.isNotEmpty) {
      final String floorDisplay = floor!.contains('طابق') || floor!.contains('الطابق') ? floor! : 'الطابق $floor';
      specChildren.add(_specItem(Icons.layers_outlined, floorDisplay));
    }
    
    return Wrap(
      spacing: 20, // Increased spacing significantly to widen out the elements
      runSpacing: 10,
      children: specChildren,
    );
  }

  Widget _buildSmartHighlightsRow() {
    List<String> tags = [];
    
    if (widget.ad.attributes != null) {
      final dynFurnished = widget.ad.attributes!['furnished'];
      if (dynFurnished != null && dynFurnished.toString().isNotEmpty) {
        tags.add('🛋️ $dynFurnished');
      }
      
      final payment = widget.ad.attributes!['payment_method'];
      if (payment != null && payment.toString().isNotEmpty) {
        tags.add('💳 $payment');
      }
    }

    if (tags.isEmpty && widget.ad.sharedRoomDetails != null) {
      final dynFurnished = widget.ad.sharedRoomDetails!.furnished;
      if (dynFurnished != null && dynFurnished.isNotEmpty) tags.add('🛋️ $dynFurnished');
    }

    if (widget.ad.tags.isNotEmpty) {
      for (var t in widget.ad.tags.take(3)) {
        tags.add('✨ $t');
      }
    }
    
    if (tags.isEmpty) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(tag, style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
      )).toList(),
    );
  }





  Widget _buildActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
          icon: Icons.chat_bubble_rounded,
          label: 'محادثة',
          color: const Color(0xFF3B82F6),
          isSolid: false,
          onTap: () {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final currentUserId = authProvider.userData?['sub']?.toString();
            if (currentUserId == null || currentUserId.isEmpty) {
              PremiumLoginBottomSheet.show(
                context, 
                subtitle: 'يرجى تسجيل الدخول لبدء محادثة',
                onLoginSuccess: () {},
              );
              return;
            }
            if (currentUserId == widget.ad.userId.toString()) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكنك بدء محادثة مع نفسك')));
              return;
            }
            ApiService().trackAdClick(widget.ad.id, 'chat');
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => PremiumChatScreen(
                adId: widget.ad.id.toString(),
                adTitle: widget.ad.title,
                adPrice: widget.ad.price.toStringAsFixed(0),
                adImageUrl: widget.ad.images.isNotEmpty ? widget.ad.images.first : '',
                isSeller: false,
                currentUserId: currentUserId,
                currentUserName: authProvider.userData?['full_name']?.toString() ?? authProvider.userData?['username']?.toString() ?? 'مستخدم',
                otherUserId: widget.ad.userId.toString(),
                otherUserName: widget.ad.ownerName,
                otherUserPhone: widget.ad.phoneNumber,
              )
            ));
          }
        )),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            icon: Icons.wechat_rounded,
          label: 'واتساب',
          color: const Color(0xFF25D366),
          isSolid: true,
          onTap: () async {
            final phone = widget.ad.phoneNumber;
            if (phone == null || phone.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم الهاتف غير متوفر')));
              return;
            }
            String waPhone = phone;
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
              ApiService().trackAdClick(widget.ad.id, 'whatsapp');
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
            }
          }
        )),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            icon: Icons.call,
          label: 'اتصال',
          color: const Color(0xFF10B981),
          isSolid: true,
          onTap: () async {
            final phone = widget.ad.phoneNumber;
            if (phone == null || phone.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('رقم الهاتف غير متوفر لهذه القائمة'), 
                  behavior: SnackBarBehavior.floating, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))
              );
              return;
            }
            final uri = Uri.parse('tel:$phone');
            try {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
                ApiService().trackAdClick(widget.ad.id, 'call');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')));
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')));
            }
          }
        )),
      ],
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required bool isSolid, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isSolid ? color : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: isSolid ? null : Border.all(color: color.withOpacity(0.2)),
          boxShadow: isSolid ? [
            BoxShadow(color: color.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 3))
          ] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSolid ? Colors.white : color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSolid ? Colors.white : color, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFCBD5E1))),
            );
          }),
        );
      },
    );
  }
}

