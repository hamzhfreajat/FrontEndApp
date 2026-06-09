import '../l10n/app_localizations.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/emoji_category_icon.dart';
import '../providers/app_provider.dart';
import '../widgets/shimmer_loading.dart';
import '../models/metrics.dart';
import '../models/ticker.dart';
import '../models/category.dart';
import '../models/ad.dart';
import '../models/story.dart';
import '../models/location.dart';
import 'story_view_page.dart';
import 'category_details_page.dart';
import 'categories_page.dart';
import 'ad_details_page.dart';
import 'add_ad_images.dart';
import 'global_search_page.dart';
import 'saved_ads_page.dart';
import 'static_content_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../providers/saved_search_provider.dart';
import '../providers/auth_provider.dart';
import '../features/chat/presentation/screens/premium_chat_screen.dart';

class _SavedActivityBanner extends StatelessWidget {
  const _SavedActivityBanner();

  @override
  Widget build(BuildContext context) {
    final searchProvider = context.watch<SavedSearchProvider>();
    final appProvider = context.watch<AppProvider>();
    
    final int savedSearches = searchProvider.savedSearches.length;
    final int favorites = appProvider.metrics?.savedItems ?? 0;

    if (savedSearches == 0 && favorites == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              if (savedSearches > 0)
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAdsPage(initialIndex: 1))),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.manage_search_rounded, color: Colors.blue, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('عمليات البحث', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                                Text('$savedSearches محفوظ', style: TextStyle(color: Colors.blue.shade700, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (savedSearches > 0 && favorites > 0) const SizedBox(width: 12),
              if (favorites > 0)
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAdsPage())),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('المفضلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                                Text('$favorites إعلان', style: TextStyle(color: Colors.red.shade700, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshData() async {
    await Provider.of<AppProvider>(context, listen: false).refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFCFCFC),
      child: RefreshIndicator(
        onRefresh: _refreshData,
        child: Consumer<AppProvider>(
          builder: (context, provider, child) {
            
            // Show shimmer during any load (initial or refresh)
            if (provider.isLoading) {
               return const ShimmerHomeScreen();
            }
            
              return CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QuickActionsGateways(categories: provider.categories),
                      _PromoBannerCarousel(),
                      const _SavedActivityBanner(),
                      // _StoriesRow(stories: provider.stories), // Hidden for now
                      const SizedBox(height: 16),
                      const _PremiumHorizontalList(title: 'الأكثر بحث', sortBy: 'popular'),
                      const SizedBox(height: 20),
                      const _PremiumHorizontalList(title: 'الأكثر مشاهدة', sortBy: 'views'),
                      const SizedBox(height: 20),
                      _PremiumHorizontalList(title: 'شقق ملائمة', categoryId: 301, showViewAll: false, allCategories: provider.categories),
                      const SizedBox(height: 20),
                      _PremiumHorizontalList(title: 'شقق للايجار', subtitle: 'أحدث الإعلانات من شقق للايجار', sortBy: 'newest', categoryId: 301, showViewAll: true, allCategories: provider.categories),
                      const SizedBox(height: 20),
                      _PremiumHorizontalList(title: 'شقق للبيع', subtitle: 'أحدث الإعلانات من شقق للبيع', sortBy: 'newest', categoryId: 10301, showViewAll: true, allCategories: provider.categories),
                      const SizedBox(height: 30),
                      const _HomeFooter(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildPremiumGrids(List<Category>? categories) {
    return [
      _PremiumCategoryGrid(
        title: context.tr('browse_best'),
        categories: categories,
        viewAllTargetId: 3,
        items: [
          {'title': context.tr('apartments_rent'), 'image': 'assets/images/real_estate/feat_apt.png', 'targetId': 301},
          {'title': context.tr('houses_sale'), 'image': 'assets/images/real_estate/feat_house.png', 'targetId': 10102},
          {'title': context.tr('farms_chalets'), 'image': 'assets/images/real_estate/feat_chalet.png', 'targetId': 314},
          {'title': context.tr('lands'), 'image': 'assets/images/real_estate/feat_land.png', 'targetId': 10313},
        ],
      ),
      _PremiumCategoryGrid(
        title: context.tr('real_estate_sale'),
        categories: categories,
        viewAllTargetId: 2,
        items: [
          {'title': context.tr('residential'), 'image': 'assets/images/real_estate/sale_house.png', 'targetId': 10310},
          {'title': context.tr('commercial'), 'image': 'assets/images/real_estate/sale_commercial.png', 'targetId': 10311},
          {'title': context.tr('farms'), 'image': 'assets/images/real_estate/sale_farm.png', 'targetId': 10314},
          {'title': context.tr('chalets_summer'), 'image': 'assets/images/real_estate/sale_resort.png', 'targetId': 10315},
        ],
      ),
      _PremiumCategoryGrid(
        title: context.tr('real_estate_rent'),
        categories: categories,
        viewAllTargetId: 3,
        items: [
          {'title': context.tr('apartments_rent'), 'image': 'assets/images/real_estate/rent_apt.png', 'targetId': 301},
          {'title': context.tr('studios_rent'), 'image': 'assets/images/real_estate/rent_studio.png', 'targetId': 302},
          {'title': context.tr('villas_palaces'), 'image': 'assets/images/real_estate/rent_palace.png', 'targetId': 3101},
          {'title': context.tr('independent_houses'), 'image': 'assets/images/real_estate/rent_house.png', 'targetId': 3102},
        ],
      ),
      _PremiumCategoryGrid(
        title: context.tr('lands_farms'),
        categories: categories,
        viewAllTargetId: 103,
        items: [
          {'title': context.tr('lands'), 'image': 'assets/images/real_estate/land_land.png', 'targetId': 10313},
          {'title': context.tr('farms'), 'image': 'assets/images/real_estate/land_farm.png', 'targetId': 10314},
          {'title': context.tr('chalets_resorts'), 'image': 'assets/images/real_estate/land_resort.png', 'targetId': 10315},
          {'title': context.tr('country_houses'), 'image': 'assets/images/real_estate/land_country.png', 'targetId': 316},
        ],
      ),
    ];
  }

  Widget _buildQuickFilters(AppProvider provider) {
    final filters = [
      {'name': context.tr('most_viewed'), 'icon': '🔥', 'sort': 'views'},
      {'name': context.tr('featured'), 'icon': '🌟', 'isHot': true},
      {'name': context.tr('new'), 'icon': '⚡', 'sort': 'newest'},
      {'name': context.tr('nearest_to_you'), 'icon': '📍', 'sort': 'closest'},
    ];

    return Container(
      height: 46,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          return GestureDetector(
            onTap: () {
               final safeCategories = (provider.categories == null || provider.categories!.isEmpty) ? [
                Category(id: 2, name: context.tr('real_estate_sale'), iconName: '🏢', adsCount: 0),
                Category(id: 3, name: context.tr('real_estate_rent'), iconName: '🔑', adsCount: 0),
              ] : provider.categories!;
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryDetailsPage(
                    category: Category(id: 0, name: context.tr('all_offers'), iconName: '🌐', adsCount: 0),
                    allCategories: safeCategories,
                    initialSort: filter['sort'] as String?,
                    initialIsHot: filter['isHot'] as bool?,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                ]
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(filter['icon'] as String, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    filter['name'] as String,
                    style: const TextStyle(color: Color(0xFF1E1E2C), fontWeight: FontWeight.bold, fontSize: 12),
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


class _StoriesRow extends StatelessWidget {
  final List<Story>? stories;
  const _StoriesRow({required this.stories});

  @override
  Widget build(BuildContext context) {
    if (stories == null || stories!.isEmpty) return const SizedBox();
    
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth / 2.25;
    final cardHeight = cardWidth * 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: cardHeight), 
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12), 
            itemCount: stories!.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _buildStoryCard(context, stories!, index, cardWidth, cardHeight),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStoryCard(BuildContext context, List<Story> allStories, int index, double width, double height) {
    final story = allStories[index];
    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => StoryViewPage(stories: allStories, initialIndex: index)));
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black12,
          image: DecorationImage(
            image: CachedNetworkImageProvider(story.imageUrl),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.5, 1.0],
                )
              ),
            ),
            Positioned(
              bottom: 12,
              left: 8,
              right: 8,
              child: Text(
                story.owner?.username ?? context.tr('user'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          ],
        )
      ),
    );
  }
}

class _UserDashboard extends StatelessWidget {
  final UserMetrics? metrics;
  const _UserDashboard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.blue.withOpacity(0.05),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('welcome_back'),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Theme.of(context).textTheme.bodyLarge?.color)),
                  SizedBox(height: 4),
                  Text(context.tr('quick_look'),
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0075FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(context.tr('personal_account'),
                        style: TextStyle(
                            color: Color(0xFF0075FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios,
                        size: 10, color: Color(0xFF0075FF)),
                  ],
                ),
              ),
            ],
          ),
          if (metrics == null) Text(context.tr('failed_to_load'), style: TextStyle(color: Colors.red))
          else Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricCard(context,
                  Icons.bookmark_outlined,
                  context.tr('saves'),
                  '${metrics!.savedItems}',
                  const Color(0xFF7CB342),
                  context.tr('recently_discovered')),
              _buildMetricCard(context,
                  Icons.history_outlined,
                  context.tr('recently_viewed'),
                  '${metrics!.recentlyViewed}',
                  const Color(0xFF0075FF),
                  context.tr('last_24_hours')),
              _buildMetricCard(context,
                  Icons.campaign_outlined,
                  context.tr('active_ads'),
                  '${metrics!.activeAds}',
                  const Color(0xFFF58721),
                  context.tr('getting_engagement')),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context,
      IconData icon, String label, String value, Color color, String subLabel) {
    bool hasBadge = label == context.tr('saves') || label == context.tr('active_ads');
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: color, size: 20),
                    if (hasBadge)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: _PulsingBadge(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935), // Red dot
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      )
                  ],
                ),
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodyLarge?.color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subLabel,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _PulsingBadge extends StatefulWidget {
  final Widget child;
  const _PulsingBadge({required this.child});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: widget.child,
    );
  }
}

class _LiveTicker extends StatelessWidget {
  final List<LiveTicker>? tickers;
  const _LiveTicker({required this.tickers});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      height: 40,
      color: const Color(0xFFE53935)
          .withOpacity(0.08), // Red tint to look like urgent news
      child: Row(
        children: [
          _PulsingBadge(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: const Color(0xFFE53935), // Urgent Red
              child: Center(
                child: Row(
                  children: [
                    const Icon(Icons.sensors,
                        color: Colors.white, size: 16), // Broadcast icon
                    SizedBox(width: 4),
                    Text(context.tr('live_now'),
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:Builder(
              builder: (context) {
                if (tickers == null || tickers!.isEmpty) {
                  return Text(context.tr('no_updates'),
                      style: TextStyle(fontSize: 12, color: Colors.grey));
                }

                final combinedMessage =
                    tickers!.map((t) => t.message).join(' • ');
                return Text(
                  combinedMessage,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumHorizontalList extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int? categoryId;
  final String? sortBy;
  final bool showViewAll;
  final List<Category>? allCategories;

  const _PremiumHorizontalList({
    required this.title,
    this.subtitle,
    this.categoryId,
    this.sortBy,
    this.showViewAll = false,
    this.allCategories,
  });

  @override
  State<_PremiumHorizontalList> createState() => _PremiumHorizontalListState();
}

class _PremiumHorizontalListState extends State<_PremiumHorizontalList> {
  bool _isLoading = true;
  List<Ad> _ads = [];

  @override
  void initState() {
    super.initState();
    _fetchAds();
  }

  Future<void> _fetchAds() async {
    try {
      final ads = await ApiService().fetchAds(limit: 10, skip: 0, categoryId: widget.categoryId, sortBy: widget.sortBy);
      if (mounted) {
        setState(() {
          _ads = ads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _ads.isEmpty) return const SizedBox();

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth / 2.25;
    final cardHeight = cardWidth * 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.title, 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                      ),
                    ],
                  ),
                  if (widget.showViewAll)
                    GestureDetector(
                      onTap: () {
                        if (widget.categoryId != null) {
                          final targetCat = widget.allCategories?.firstWhere(
                            (c) => c.id == widget.categoryId,
                            orElse: () => Category(id: widget.categoryId!, name: widget.title, adsCount: 0)
                          ) ?? Category(id: widget.categoryId!, name: widget.title, adsCount: 0);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryDetailsPage(
                                category: targetCat,
                                allCategories: widget.allCategories ?? [],
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'عرض المزيد',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))
                      ),
                    )
                ],
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Text(
                    widget.subtitle!,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ],
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: cardHeight),
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _ads.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: SizedBox(
                      width: cardWidth,
                      child: _buildAdCard(context, _ads[index]),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildAdCard(BuildContext context, Ad ad) {
    final imageUrl = ad.images.isNotEmpty ? ad.images.first : 'https://via.placeholder.com/150';
    final price = ad.price != null ? '${ad.price} د.أ' : '';
    final title = ad.title;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdDetailsPage(ad: ad)),
        ).then((_) {
          if (context.mounted) {
            // Rebuild home page to reflect changes in ad.isSaved
            final state = context.findAncestorStateOfType<State<HomePage>>();
            // ignore: invalid_use_of_protected_member
            state?.setState(() {});
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: CachedNetworkImageProvider(imageUrl),
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 0, left: 0, right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withOpacity(0.3), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    if (ad.videoUrl != null)
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    if (ad.isHot ?? false)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0,2))],
                          ),
                          child: const Text('عاجل', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ),
                    Positioned(
                      top: 0,
                      left: 0,
                      child: StatefulBuilder(
                        builder: (context, setIconState) {
                          return IconButton(
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            icon: Icon(ad.isSaved ? Icons.favorite : Icons.favorite_border, color: ad.isSaved ? Colors.redAccent : Colors.white, size: 20),
                            onPressed: () async {
                              final originalState = ad.isSaved;
                              setIconState(() => ad.isSaved = !originalState);
                              try {
                                final isNowSaved = await ApiService().toggleSaveAd(ad.id);
                                if (context.mounted) {
                                  setIconState(() => ad.isSaved = isNowSaved);
                                  context.read<AppProvider>().toggleFavoriteCount(isNowSaved);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  setIconState(() => ad.isSaved = originalState);
                                }
                              }
                            },
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.w800, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 12, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.grey, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ad.location.isNotEmpty ? ad.location : 'عمان',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGateways extends StatelessWidget {
  final List<Category>? categories;
  const _QuickActionsGateways({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _PremiumQuickActionCard(
              title: context.tr('buy'), // عقارات للبيع
              subtitle: 'ابحث عن عقار أحلامك',
              imagePath: 'assets/images/real_estate/house_sale.png',
              gradientColors: const [Color(0xFF0075FF), Color(0xFF0052B4)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoriesPage(
                      parentId: 2,
                      title: context.tr('buy'),
                      allCategories: categories,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _PremiumQuickActionCard(
              title: context.tr('rent'), // عقارات للايجار
              subtitle: 'أفضل العروض للإيجار',
              imagePath: 'assets/images/real_estate/rent_apt.png',
              gradientColors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoriesPage(
                      parentId: 3,
                      title: context.tr('rent'),
                      allCategories: categories,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _routeToCategory(BuildContext context, String keyword, int fallbackId, {int? parentId}) {
    // If categories are empty, create a smart fallback based on the action so navigation doesn't stall silently.
    final List<Category> safeCategories = (categories == null || categories!.isEmpty) ? [
      Category(id: 2, name: context.tr('real_estate_sale'), iconName: '🏢', adsCount: 0),
      Category(id: 3, name: context.tr('real_estate_rent'), iconName: '🔑', adsCount: 0),
    ] : categories!;

    try {
      final normalizedKeyword = keyword.replaceAll('إ', 'ا').replaceAll('أ', 'ا').replaceAll('آ', 'ا');
      final target = safeCategories.firstWhere(
        (c) {
          final normalizedName = c.name.replaceAll('إ', 'ا').replaceAll('أ', 'ا').replaceAll('آ', 'ا');
          return (normalizedName.contains(normalizedKeyword) && (parentId == null || c.parentId == parentId)) || c.id == fallbackId;
        },
        orElse: () {
          if (keyword.contains(context.tr('lands'))) {
             return Category(
               id: 10313, // Real Lands Database ID
               parentId: null, 
               name: context.tr('lands'), 
               iconName: '⛰️',
               description: context.tr('lands'),
               adsCount: 0
             );
          }
          return safeCategories.firstWhere((c) => c.id == fallbackId, orElse: () => safeCategories.first);
        },
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryDetailsPage(
            category: target,
            allCategories: safeCategories,
          ),
        ),
      );
    } catch (e) {
      // Emergency fallback if exception occurs
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryDetailsPage(
            category: Category(id: fallbackId, name: keyword, adsCount: 0),
            allCategories: safeCategories,
          ),
        ),
      );
    }
  }

  Widget _buildQuickAction(BuildContext context, String title, String emoji, List<Color> gradientColors, VoidCallback onTap) {
    return const SizedBox.shrink(); // Replaced by _PremiumQuickActionCard
  }
}

class _PremiumQuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final VoidCallback onTap;

  final List<Color> gradientColors;

  const _PremiumQuickActionCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gradientColors.first.withOpacity(0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large Image
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradientColors.map((c) => c.withOpacity(0.5)).toList(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    imagePath,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Black Text at the bottom
            FittedBox(
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1E1E2C),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


class _RecentlyViewedSliders extends StatelessWidget {
  final List<Ad> ads;
  final List<Category>? categories;
  const _RecentlyViewedSliders({required this.ads, required this.categories});

  @override
  Widget build(BuildContext context) {
    if (ads.isEmpty) return const SizedBox.shrink();
    return _AdListHorizontal(title: context.tr('seen_recently'), ads: ads, categories: categories);
  }
}

class _BudgetSlider extends StatelessWidget {
  final List<Ad>? ads;
  final List<Category>? categories;
  const _BudgetSlider({required this.ads, required this.categories});

  @override
  Widget build(BuildContext context) {
    return _AdListHorizontal(title: context.tr('within_budget'), ads: ads, categories: categories);
  }
}

class _NearYouSlider extends StatelessWidget {
  final List<Ad>? ads;
  final List<Category>? categories;
  const _NearYouSlider({required this.ads, required this.categories});

  @override
  Widget build(BuildContext context) {
    return _AdListHorizontal(title: context.tr('near_you'), ads: ads, categories: categories);
  }
}

class _PromotionalBanner extends StatelessWidget {
  const _PromotionalBanner();

  static const _accent = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAdImagesPage())),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_accent, const Color(0xFF1557B0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('add_ad_now'),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white)),
                const SizedBox(height: 8),
                Text(context.tr('reach_thousands'),
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 14),
                // Steps
                Row(children: [
                  _step(Icons.camera_alt_outlined, context.tr('shoot')),
                  _arrow(),
                  _step(Icons.edit_outlined, context.tr('write')),
                  _arrow(),
                  _step(Icons.campaign_outlined, context.tr('publish')),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_circle_outline, color: _accent, size: 18),
                    SizedBox(width: 6),
                    Text(context.tr('add_ad_free'),
                        style: TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.sell_outlined, color: Colors.white, size: 32),
            ),
          ]),
        ),
      ),
    );
  }

  static Widget _step(IconData icon, String label) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.w700)),
    ]);
  }

  static Widget _arrow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 6, right: 6),
      child: Icon(Icons.arrow_forward, color: Colors.white.withOpacity(0.5), size: 14),
    );
  }
}

class _AdListHorizontal extends StatelessWidget {
  final String title;
  final List<Ad>? ads;
  final List<Category>? categories;
  final int? targetCategoryId;
  final Map<String, dynamic>? targetFilters;

  const _AdListHorizontal({
    required this.title,
    required this.ads,
    required this.categories,
    this.targetCategoryId,
    this.targetFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (ads == null || ads!.isEmpty) return const SizedBox.shrink();

    return Container(color: Theme.of(context).cardColor, // Solid white background for all sliders
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    if (categories == null || categories!.isEmpty) return;
                    Category? target;
                    if (targetCategoryId != null) {
                      try {
                        target = categories!.firstWhere((c) => c.id == targetCategoryId);
                      } catch (_) {}
                    }
                    if (target == null) {
                      try {
                        target = categories!.firstWhere((c) => c.name == title);
                      } catch (_) {}
                    }
                    
                    if (target != null) {
                      // Extract filters if available
                      double? minPrice;
                      double? maxPrice;
                      List<String>? initialTags;
                      List<String>? initialLocations;
                      if (targetFilters != null) {
                        try {
                           if (targetFilters!['min_price'] != null) minPrice = double.tryParse(targetFilters!['min_price'].toString());
                           if (targetFilters!['max_price'] != null) maxPrice = double.tryParse(targetFilters!['max_price'].toString());
                           if (targetFilters!['tags'] != null) {
                              initialTags = (targetFilters!['tags'] as List).map((e) => e.toString()).toList();
                           }
                           if (targetFilters!['locations'] != null) {
                              initialLocations = (targetFilters!['locations'] as List).map((e) => e.toString()).toList();
                           }
                        } catch (_) {}
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoryDetailsPage(
                            category: target!,
                            allCategories: categories!,
                            initialMinPrice: minPrice,
                            initialMaxPrice: maxPrice,
                            initialTags: initialTags,
                            initialLocations: initialLocations,
                          ),
                        ),
                      );
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.tr('view_all'),
                          style: TextStyle(
                              color: Color(0xFF1A73E8),
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1A73E8).withOpacity(0.08),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_ios,
                            color: Color(0xFF1A73E8), size: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (categories != null)
            Builder(
              builder: (context) {
                if (categories == null || categories!.isEmpty) return const SizedBox.shrink();
                final matchingCat = categories!.firstWhere((c) => c.name == title, orElse: () => Category(id:-1, name:''));
                if (matchingCat.id == -1) return const SizedBox.shrink();
                
                final slugs = matchingCat.slugs?['ar'] ?? matchingCat.slugs?['en'];

                if (slugs == null || slugs.isEmpty)
                  return const SizedBox.shrink();

                return SizedBox(
                  height: 36,
                  child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: slugs.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(left: 8.0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            slugs[index],
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context).textTheme.bodyLarge?.color),
                          ),
                        );
                      }),
                );
              },
            ),
          if (categories != null) const SizedBox(height: 16),
          SizedBox(
            height: 280, // Taller for the new bespoke cards
            child: Builder(
              builder: (context) {
                if (ads == null || ads!.isEmpty) {
                  return Center(child: Text(context.tr('no_ads')));
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: ads!.length,
                  itemBuilder: (context, index) {
                    final ad = ads![index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => AdDetailsPage(ad: ad)));
                        },
                        child: _AdCard(ad: ad),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  final Ad ad;
  const _AdCard({required this.ad});

  static const _accent = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 175,
      margin: const EdgeInsets.only(bottom: 8), // Shadow breathing room
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.04),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Image Hero Section
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 155,
                  width: double.infinity,
                  child: ad.imageUrl != null
                      ? ApiService.networkImage(ad.imageUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade100, child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade300, size: 30)),
                ),
              ),
              // Soft gradient overlay for high contrast elements
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),
              // Glassmorphic Price Tag (Bottom Left)
              Positioned(
                bottom: 10, right: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5),
                      ),
                      child: Text(
                        '${ad.price.toStringAsFixed(0)} د.أ',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
              // Frosted Favorite Button
              Positioned(
                top: 10, left: 10,
                child: StatefulBuilder(
                  builder: (context, setIconState) {
                    return GestureDetector(
                      onTap: () async {
                        final originalState = ad.isSaved;
                        setIconState(() => ad.isSaved = !originalState);
                        try {
                          final isNowSaved = await ApiService().toggleSaveAd(ad.id);
                          if (context.mounted) {
                            setIconState(() => ad.isSaved = isNowSaved);
                            context.read<AppProvider>().toggleFavoriteCount(isNowSaved);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setIconState(() => ad.isSaved = originalState);
                          }
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 0.5),
                            ),
                            child: Icon(ad.isSaved ? Icons.favorite : Icons.favorite_border, color: ad.isSaved ? Colors.redAccent : Colors.grey.shade700, size: 16),
                          ),
                        ),
                      ),
                    );
                  }
                ),
              ),
              if (ad.isHot) // Glowing Hot Badge
                Positioned(
                  top: 10, right: 10,
                  child: _PulsingBadge(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)]),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFFF9800).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.local_fire_department, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(context.tr('featured'), style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
          // Refined Details Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ad.title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF1E1E2C), height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.location_on_rounded, size: 13, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 80),
                          child: Text(
                            ad.location.split('،').first, 
                            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      Row(children: [
                        Icon(Icons.access_time_filled, size: 12, color: Colors.grey.shade300),
                        const SizedBox(width: 3),
                        Text(context.tr('now'), style: TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _PremiumCategoryGrid extends StatelessWidget {
  final Color backgroundColor;
  final String title;
  final List<Category>? categories;
  final int viewAllTargetId;
  final List<Map<String, dynamic>> items;

  const _PremiumCategoryGrid({
    required this.title,
    required this.categories,
    required this.viewAllTargetId,
    required this.items,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              fontFamily: 'Tajawal',
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PremiumGridItem(
                  image: items[0]['image'],
                  title: items[0]['title'],
                  targetId: items[0]['targetId'],
                  categories: categories,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PremiumGridItem(
                  image: items[1]['image'],
                  title: items[1]['title'],
                  targetId: items[1]['targetId'],
                  categories: categories,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PremiumGridItem(
                  image: items[2]['image'],
                  title: items[2]['title'],
                  targetId: items[2]['targetId'],
                  categories: categories,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PremiumGridItem(
                  image: items[3]['image'],
                  title: items[3]['title'],
                  targetId: items[3]['targetId'],
                  categories: categories,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
               final parentCat = Category(id: viewAllTargetId, name: title, adsCount: 0);
               Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryDetailsPage(
                      category: parentCat,
                      allCategories: categories ?? [],
                    ),
                  ),
               );
            },
            child: Text(
              context.tr('show_more'),
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumGridItem extends StatelessWidget {
  final String image;
  final String title;
  final int targetId;
  final List<Category>? categories;

  const _PremiumGridItem({
    required this.image,
    required this.title,
    required this.targetId,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final targetCat = Category(id: targetId, name: title, adsCount: 0);
        final provider = Provider.of<AppProvider>(context, listen: false);

        if (provider.isLeafCategory(targetId)) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryDetailsPage(
                category: targetCat,
                allCategories: categories ?? [],
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoriesPage(
                parentId: targetId,
                title: title,
                category: targetCat,
                allCategories: categories ?? [],
              ),
            ),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF8FAFC),
                image: DecorationImage(
                  image: AssetImage(image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              fontFamily: 'Tajawal',
              color: Color(0xFF1A1A2E), // Deep professional dark blue/black
              letterSpacing: -0.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PromoBannerCarousel extends StatefulWidget {
  @override
  __PromoBannerCarouselState createState() => __PromoBannerCarouselState();
}

class __PromoBannerCarouselState extends State<_PromoBannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  List<Map<String, dynamic>> get _banners => [
    {
      'image': 'assets/images/real_estate/premium_banner_1.png',
      'title': 'سكن موظفين',
      'subtitle': context.tr('browse_now'),
      'targetId': 3063,
    },
    {
      'image': 'assets/images/real_estate/premium_banner_2.png',
      'title': 'بيوت مستقلة للبيع',
      'subtitle': context.tr('explore'),
      'targetId': 10102,
    },
    {
      'image': 'assets/images/real_estate/premium_banner_3.png',
      'title': 'بيوت مستقلة للايجار',
      'subtitle': context.tr('view_details'),
      'targetId': 3102,
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < _banners.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuart,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 180,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return GestureDetector(
                onTap: () {
                  final targetCat = Category(id: banner['targetId'], name: banner['title'].replaceAll('\\n', ' '), adsCount: 0);
                  final provider = Provider.of<AppProvider>(context, listen: false);

                  if (provider.isLeafCategory(banner['targetId'])) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryDetailsPage(
                          category: targetCat,
                          allCategories: [],
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoriesPage(
                          parentId: banner['targetId'],
                          title: banner['title'].replaceAll('\\n', ' '),
                          category: targetCat,
                          allCategories: [],
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: AssetImage(banner['image']),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Premium Frosted Glass Text Card
                      Positioned(
                        right: 16,
                        top: 24,
                        bottom: 24,
                        width: 170,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.2),
                                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    banner['title'].replaceAll('\n', ' ').replaceAll('\\n', ' '),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      height: 1.3,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.1),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.arrow_back_ios_new_rounded,
                                          size: 10,
                                          color: Color(0xFF1A73E8),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          banner['subtitle'],
                                          style: const TextStyle(
                                            color: Color(0xFF1A73E8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
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
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 24 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: _currentPage == index ? const Color(0xFF1A73E8) : const Color(0xFF1A73E8).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _HomeFooter extends StatelessWidget {
  const _HomeFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 40, bottom: 24, left: 24, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CTA Card (Sell/Rent your property)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 20),
                const Text(
                  'هل لديك عقار للبيع أو للإيجار؟',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أضف إعلانك الآن وانضم لملايين المستخدمين. بيع أسرع وبدون أي عمولة!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAdImagesPage()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'أضف إعلانك مجاناً',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildCustomerSupportCard(context),
          const SizedBox(height: 48),

          // 2. Links Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اكتشف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
                    const SizedBox(height: 16),
                    _footerLink('عقارات للبيع', onTap: () {
                      final cats = Provider.of<AppProvider>(context, listen: false).categories;
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CategoriesPage(parentId: 2, title: 'عقارات للبيع', allCategories: cats)));
                    }),
                    _footerLink('عقارات للايجار', onTap: () {
                      final cats = Provider.of<AppProvider>(context, listen: false).categories;
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CategoriesPage(parentId: 3, title: 'عقارات للايجار', allCategories: cats)));
                    }),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('معلومات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
                    const SizedBox(height: 16),
                    _footerLink('عن التطبيق', onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StaticContentPage(
                        pageTitle: 'عن التطبيق', 
                        headerText: 'مرحباً بكم في تطبيق Classifieds، وجهتكم الرقمية الرائدة والموثوقة للإعلانات المبوبة والتجارة الذكية. تأسس التطبيق ليكون الجسر الآمن والأسرع الذي يربط بين البائعين والمشترين في بيئة تفاعلية سهلة الاستخدام.',
                        sections: [
                          ContentSection(
                            title: 'رؤيتنا',
                            content: 'نسعى لإعادة صياغة مفهوم الإعلانات المبوبة من خلال توفير منصة تعتمد على أحدث التقنيات لتبسيط عملية البيع والشراء، وجعلها تجربة سلسة، آمنة، ومتاحة للجميع في أي وقت ومن أي مكان.'
                          ),
                          ContentSection(
                            title: 'ما الذي يميزنا؟',
                            content: 'نقدم لك أفضل تجربة تصفح وأعلى معايير الأمان:',
                            bullets: [
                              'تصنيف ذكي وشامل: أقسام متعددة تغطي كافة الاحتياجات (عقارات، سيارات، إلكترونيات، وظائف، خدمات، وغيرها) للوصول إلى الغاية بضغطة زر.',
                              'تجربة مستخدم استثنائية: واجهة بسيطة وتصميم عصري يضمنان سهولة التصفح ونشر الإعلانات في ثوانٍ معدودة.',
                              'بيئة آمنة وموثوقة: نطبق معايير صارمة للتحقق من الإعلانات لضمان حماية المستخدمين من الاحتيال وتقديم محتوى ذي جودة عالية.',
                              'تواصل فعّال: أدوات مراسلة فورية مدمجة تضمن التواصل المباشر بين البائع والمشتري دون تعقيدات.'
                            ]
                          ),
                        ]
                      )));
                    }),
                    _footerLink('الشروط والأحكام', onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StaticContentPage(
                        pageTitle: 'الشروط والأحكام', 
                        headerText: 'تمثل هذه الاتفاقية عقداً ملزماً بينك كـ "مستخدم" وبين منصتنا. باستخدامك للتطبيق، فإنك تقر بموافقتك الكاملة على الشروط التالية:',
                        sections: [
                          ContentSection(
                            title: '1. طبيعة الخدمة والمسؤولية',
                            content: 'نعمل كـ منصة وسيطة تتيح للمستخدمين عرض وطلب السلع والخدمات. نحن لا نملك السلع المعروضة، ولا نتدخل في عمليات الدفع المباشرة بين الأطراف، ولا نتحمل مسؤولية جودة المنتجات أو مصداقية البائع.\nالمستخدم هو المسؤول الوحيد عن إتمام عمليات البيع والشراء خارج إطار التطبيق بناءً على تقييمه الشخصي.'
                          ),
                          ContentSection(
                            title: '2. الحسابات والتسجيل',
                            content: 'يُشترط تقديم معلومات صحيحة ودقيقة عند إنشاء الحساب (رقم الهاتف، البريد الإلكتروني، الاسم).\nيتحمل المستخدم المسؤولية الكاملة عن الحفاظ على سرية بيانات الدخول الخاصة به، وعن كافة الأنشطة التي تتم عبر حسابه.'
                          ),
                          ContentSection(
                            title: '3. سياسة النشر والإعلانات المحظورة',
                            content: 'يُمنع منعاً باتاً نشر أي إعلانات تتضمن:',
                            bullets: [
                              'سلعاً أو خدمات غير قانونية أو مسروقة أو محظورة محلياً ودولياً.',
                              'محتوى مضللاً، احتيالياً، أو يتضمن معلومات وهمية.',
                              'أسلحة، مواد خطرة، أدوية غير مرخصة، أو سلعاً تنتهك حقوق الملكية الفكرية لطرف ثالث.',
                              'عبارات مسيئة، عنصرية، أو خادشة للحياء العام.'
                            ]
                          ),
                          ContentSection(
                            title: '4. حقوق الملكية والإجراءات',
                            content: 'نحتفظ بالحق المطلق في حذف، أو تعديل، أو إخفاء أي إعلان يخالف هذه الشروط دون سابق إنذار.\nيحق لإدارة التطبيق حظر أو إيقاف حساب أي مستخدم يثبت تورطه في عمليات احتيال أو انتهاك متكرر لسياسة الاستخدام.'
                          ),
                          ContentSection(
                            title: '5. التعديلات',
                            content: 'يحق لنا تحديث شروط الاستخدام في أي وقت. سيتم إشعار المستخدمين بالتحديثات الجوهرية، ويُعتبر استمرار استخدام التطبيق بعد التحديث موافقة ضمنية على الشروط الجديدة.'
                          ),
                        ]
                      )));
                    }),
                    _footerLink('سياسة الخصوصية', onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StaticContentPage(
                        pageTitle: 'سياسة الخصوصية', 
                        headerText: 'نحن ندرك أهمية خصوصيتك، ونلتزم التزاماً كاملاً بحماية بياناتك الشخصية وفقاً لأعلى معايير الأمان الرقمي.',
                        sections: [
                          ContentSection(
                            title: '1. البيانات التي نجمعها',
                            content: 'نقوم بجمع البيانات التالية لضمان تقديم أفضل خدمة ممكنة:',
                            bullets: [
                              'بيانات التسجيل: الاسم، رقم الهاتف، والبريد الإلكتروني المدخلة عند إنشاء الحساب.',
                              'بيانات الاستخدام: الإعلانات التي تتصفحها، عمليات البحث، والمراسلات التي تتم داخل التطبيق لغايات تحسين التجربة.',
                              'البيانات التقنية: عنوان بروتوكول الإنترنت (IP)، نوع الجهاز، نظام التشغيل، وبيانات الموقع الجغرافي.'
                            ]
                          ),
                          ContentSection(
                            title: '2. كيف نستخدم بياناتك؟',
                            content: 'نستخدم البيانات التي نجمعها للأغراض التالية:',
                            bullets: [
                              'لإنشاء وإدارة حسابك وتسهيل عمليات نشر وتصفح الإعلانات.',
                              'لتقديم الدعم الفني والرد على استفساراتك وشكاويك.',
                              'لتحسين أداء التطبيق وتطوير خدمات جديدة تناسب اهتماماتك.',
                              'لاكتشاف ومنع أي أنشطة احتيالية أو غير قانونية لضمان سلامة المنصة.'
                            ]
                          ),
                          ContentSection(
                            title: '3. مشاركة البيانات',
                            content: 'السرية التامة: نحن لا نقوم ببيع، أو تأجير، أو تداول بياناتك الشخصية مع أي جهة خارجية لأغراض تسويقية.\nالاستثناءات القانونية: قد نضطر لمشاركة بعض البيانات إذا طُلب منا ذلك بموجب أمر قضائي، أو للامتثال للقوانين والتشريعات النافذة، أو لحماية حقوق التطبيق ومستخدميه.'
                          ),
                          ContentSection(
                            title: '4. حماية البيانات وأمنها',
                            content: 'نستخدم بروتوكولات تشفير متقدمة (مثل SSL) وتدابير أمنية تقنية وتنظيمية صارمة لحماية بياناتك من الوصول غير المصرح به، أو التعديل، أو الإتلاف.'
                          ),
                          ContentSection(
                            title: '5. حقوق المستخدم',
                            content: 'لك الحق الكامل في:',
                            bullets: [
                              'الوصول إلى بياناتك الشخصية وتحديثها عبر إعدادات الحساب.',
                              'طلب حذف حسابك وكافة بياناتك المرتبطة به بشكل نهائي عبر خيار "حذف الحساب" داخل التطبيق أو بمراسلة فريق الدعم.'
                            ]
                          ),
                        ]
                      )));
                    }),
                    _footerLink('خدمة العملاء (الدعم الفني)', onTap: () {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final currentUserId = authProvider.userData?['sub']?.toString() ?? '';
                      
                      if (currentUserId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr('login_required') ?? 'يرجى تسجيل الدخول أولاً'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumChatScreen(
                        adId: 'support',
                        adTitle: 'خدمة العملاء',
                        adPrice: '',
                        adImageUrl: '',
                        currentUserId: currentUserId,
                        currentUserName: authProvider.userData?['name']?.toString() ?? 'مستخدم',
                        currentUserPhone: authProvider.userData?['phone_number']?.toString(),
                        otherUserId: 'admin',
                        otherUserName: 'فريق الدعم',
                        isSeller: false,
                      )));
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // 3. Divider
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 24),

          // 4. Social & Copyright
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© 2026 جميع الحقوق محفوظة.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              Row(
                children: [
                  _socialIcon(Icons.facebook),
                  const SizedBox(width: 12),
                  _socialIcon(Icons.camera_alt), // Instagram fallback
                  const SizedBox(width: 12),
                  _socialIcon(Icons.link), // Twitter/X fallback
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _footerLink(String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _socialIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
    );
  }

  Widget _buildCustomerSupportCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 20),
              const Text(
                'تحتاج مساعدة؟',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'فريق خدمة العملاء متواجد دائماً لخدمتك والرد على استفساراتك',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final currentUserId = authProvider.userData?['sub']?.toString() ?? '';
                    
                    if (currentUserId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('login_required') ?? 'يرجى تسجيل الدخول أولاً'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumChatScreen(
                      adId: 'support',
                      adTitle: 'خدمة العملاء',
                      adPrice: '',
                      adImageUrl: '',
                      currentUserId: currentUserId,
                      currentUserName: authProvider.userData?['name']?.toString() ?? 'مستخدم',
                      currentUserPhone: authProvider.userData?['phone_number']?.toString(),
                      otherUserId: 'admin',
                      otherUserName: 'فريق الدعم',
                      isSeller: false,
                    )));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'تواصل معنا',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
