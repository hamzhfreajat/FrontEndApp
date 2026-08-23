import 'dart:async';
import '../services/analytics_engine.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import 'notifications_page.dart';
import 'categories_page.dart';
import 'add_ad_images.dart';
import 'saved_ads_page.dart';
import 'global_search_page.dart';
import '../features/chat/presentation/screens/premium_inbox_screen.dart';
import '../features/chat/presentation/screens/premium_chat_screen.dart';
import '../features/chat/data/repositories/firebase_chat_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/my_ads/presentation/screens/my_ads_screen.dart';
import '../features/my_ads/presentation/bloc/my_ads_bloc.dart';
import '../features/my_ads/data/repositories/my_ads_repository_impl.dart';
import '../services/api_service.dart';
import '../features/profile/presentation/screens/private_profile_screen.dart';
import '../features/profile/presentation/bloc/profile_bloc.dart';
import '../features/profile/presentation/bloc/profile_event.dart';
import '../features/profile/data/repositories/api_profile_repository.dart';
import '../providers/app_provider.dart';
import '../providers/saved_search_provider.dart';
import '../providers/auth_provider.dart';
import 'package:app_links/app_links.dart';
import 'package:upgrader/upgrader.dart';
import 'ad_details_page.dart';
import 'category_details_page.dart';
import '../models/category.dart';
import '../widgets/premium_login_bottom_sheet.dart';
import '../widgets/guest_prompt_widget.dart';

class RootScreen extends StatefulWidget {
  final int initialIndex;
  const RootScreen({super.key, this.initialIndex = 0});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _lastTabIndex = 0;

  static const _accent = Color(0xFF1A73E8);
  static const _accentDark = Color(0xFF1557B0);
  static const _bg = Color(0xFFF4F6FA);

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialIndex);
    _lastTabIndex = widget.initialIndex;
    
    _tabController.addListener(() {
      if (_tabController.index != _lastTabIndex) {
        _lastTabIndex = _tabController.index;
        final tabNames = ['home', 'categories_tab', 'my_ads', 'my_account'];
        if (_tabController.index >= 0 && _tabController.index < tabNames.length) {
          AnalyticsEngine().logScreenViewed(screenName: tabNames[_tabController.index]);
        }
      }
    });

    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    
    // Handle link when app is in warm state (front or background)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
    
    // Handle link when app is in cold state (terminated)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) async {
    // For HTTPS URLs: https://sooq-com.com/ad/14032 → pathSegments = ['ad', '14032']
    // For custom scheme: sooqcom://ad/14032 → host = 'ad', pathSegments = ['14032']
    
    String? type;
    String? idStr;
    Map<String, String> queryParams = uri.queryParameters;
    
    if (uri.scheme == 'sooqcom') {
      // Custom scheme: sooqcom://ad/123 or sooqcom://category/456
      type = uri.host; // 'ad' or 'category'
      if (uri.pathSegments.isNotEmpty) {
        idStr = uri.pathSegments.first;
      }
    } else {
      // HTTPS scheme: https://sooq-com.com/ad/123
      if (uri.pathSegments.isNotEmpty) {
        type = uri.pathSegments.first;
        if (uri.pathSegments.length > 1) {
          idStr = uri.pathSegments[1];
        }
      }
    }
    
    if (type == 'ad' && idStr != null) {
      final adId = int.tryParse(idStr);
      if (adId != null) {
        try {
          final ad = await ApiService().fetchAdById(adId);
          if (mounted) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdDetailsPage(ad: ad)));
          }
        } catch (e) {
          print('Failed to load ad from deep link: $e');
        }
      }
    } else if (type == 'category' && idStr != null) {
      final categoryId = int.tryParse(idStr);
      if (categoryId != null) {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        final categories = appProvider.categories ?? [];
        Category? category;
        try {
          category = categories.firstWhere((c) => c.id == categoryId);
        } catch (_) {}

        if (category != null) {
          final query = queryParams['query'];
          final minPriceStr = queryParams['minPrice'];
          final maxPriceStr = queryParams['maxPrice'];
          final isHotStr = queryParams['isHot'];
          final locationsStr = queryParams['locations'];
          final tagsStr = queryParams['tags'];

          final minPrice = minPriceStr != null ? double.tryParse(minPriceStr) : null;
          final maxPrice = maxPriceStr != null ? double.tryParse(maxPriceStr) : null;
          final isHot = isHotStr == 'true';
          final locations = locationsStr != null && locationsStr.isNotEmpty ? locationsStr.split(',') : null;
          final tags = tagsStr != null && tagsStr.isNotEmpty ? tagsStr.split(',') : null;

          if (mounted) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryDetailsPage(
              category: category!,
              initialSearchQuery: query,
              initialMinPrice: minPrice,
              initialMaxPrice: maxPrice,
              initialIsHot: isHot,
              initialLocations: locations,
              initialTags: tags,
            )));
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: UpgradeAlert(
          upgrader: Upgrader(
            languageCode: 'ar',
            messages: UpgraderMessages(code: 'ar'),
          ),
          child: Scaffold(
            backgroundColor: _bg,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).cardColor,
              titleSpacing: 0,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Image.asset('assets/images/sooqcom_logo_v2.png', width: 42, height: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(context.tr('sooqcom'),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: 'Cairo', color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w900, fontSize: 20, height: 1.1),
                          ),
                          Text('SOOQCOM',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Montserrat', color: Color(0xFF1A73E8), fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 2.0, height: 1.1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                GestureDetector(
                  onTap: () {
                    AnalyticsEngine().logButtonTapped(buttonName: 'top_nav_search', location: 'root_screen');
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchPage()));
                  },
                  child: _headerBtn(Icons.search_rounded),
                ),
                const SizedBox(width: 6),

                Consumer<AppProvider>(
                  builder: (context, provider, child) {
                    final int count = provider.metrics?.savedItems ?? 0;
                    return GestureDetector(
                      onTap: () {
                        AnalyticsEngine().logButtonTapped(buttonName: 'top_nav_saved_ads', location: 'root_screen');
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        if (!auth.isAuthenticated) {
                          PremiumLoginBottomSheet.show(
                            context,
                            title: 'الإعلانات المحفوظة',
                            subtitle: 'سجل الدخول للوصول إلى إعلاناتك المحفوظة',
                            onLoginSuccess: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAdsPage())),
                          );
                          return;
                        }
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAdsPage()));
                      },
                      child: _headerBtnWithBadge(Icons.favorite_border_rounded, count > 0 ? count.toString() : null),
                    );
                  },
                ),

                const SizedBox(width: 6),
                Consumer<NotificationProvider>(
                  builder: (context, notifProvider, child) {
                    final count = notifProvider.unreadCount;
                    return GestureDetector(
                      onTap: () {
                        AnalyticsEngine().logButtonTapped(buttonName: 'top_nav_notifications', location: 'root_screen');
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        if (!auth.isAuthenticated) {
                          PremiumLoginBottomSheet.show(
                            context,
                            title: 'الإشعارات',
                            subtitle: 'سجل الدخول لرؤية أحدث الإشعارات والتنبيهات',
                            onLoginSuccess: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
                          );
                          return;
                        }
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
                      },
                      child: _headerBtnWithBadge(
                        Icons.notifications_none_rounded, 
                        count > 0 ? (count > 99 ? '+99' : count.toString()) : null
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    final currentUserId = authProvider.userData?['sub']?.toString() ?? '';
                    return GestureDetector(
                      onTap: () {
                        AnalyticsEngine().logButtonTapped(buttonName: 'top_nav_inbox', location: 'root_screen');
                        if (!authProvider.isAuthenticated) {
                          PremiumLoginBottomSheet.show(
                            context,
                            title: 'الرسائل',
                            subtitle: 'سجل الدخول للتواصل مع البائعين والمشترين',
                            onLoginSuccess: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumInboxScreen())),
                          );
                          return;
                        }
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumInboxScreen()));
                      },
                      child: StreamBuilder<int>(
                        stream: FirebaseChatRepository().getTotalUnreadCount(currentUserId),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return _headerBtnWithBadge(
                            Icons.chat_bubble_outline_rounded,
                            count > 0 ? (count > 99 ? '+99' : count.toString()) : null,
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(width: 14),
              ],
              pinned: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ?? Theme.of(context).cardColor,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          AnalyticsEngine().logButtonTapped(buttonName: 'bottom_nav_add_ad', location: 'root_screen');
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          if (!auth.isAuthenticated) {
                            PremiumLoginBottomSheet.show(
                              context,
                              title: 'إضافة إعلان',
                              subtitle: 'سجل الدخول لتتمكن من إضافة إعلاناتك الخاصة',
                              onLoginSuccess: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAdImagesPage())),
                            );
                            return;
                          }
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAdImagesPage()));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12, left: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [_accent, _accentDark],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _accent.withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                ),
                                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(height: 2),
                              Text(context.tr('add_ad'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _accent)),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.grey.shade300,
                        margin: const EdgeInsets.only(left: 4),
                      ),
                      Expanded(
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.label,
                          indicatorWeight: 3,
                          indicatorColor: _accent,
                          labelColor: _accent,
                          unselectedLabelColor: const Color(0xFF8E8E93),
                          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
                          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                          dividerColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                          tabs: [
                            _tab(Icons.home_rounded, Icons.home_outlined, context.tr('home'), 0),
                            _tab(Icons.grid_view_rounded, Icons.grid_view, context.tr('categories'), 1),
                            _tab(Icons.article_rounded, Icons.article_outlined, context.tr('my_ads'), 2),
                            _tab(Icons.person_rounded, Icons.person_outline_rounded, context.tr('my_account'), 3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: Consumer<AuthProvider>(
            builder: (context, auth, child) {
              if (auth.isAuthenticated) {
                return MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) => MyAdsBloc(repository: MyAdsRepositoryImpl(ApiService())),
                    ),
                    BlocProvider(
                      create: (_) => ProfileBloc(repository: ApiProfileRepositoryImpl())..add(LoadProfile()),
                    ),
                  ],
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      const HomePage(),
                      const CategoriesPage(),
                      const MyAdsScreen(),
                      const PrivateProfileScreen(),
                    ],
                  ),
                );
              }
              
              return TabBarView(
                controller: _tabController,
                children: [
                  const HomePage(),
                  const CategoriesPage(),
                  GuestPromptWidget(
                    icon: Icons.article_rounded,
                    title: 'إعلاناتي',
                    subtitle: 'سجل الدخول لعرض وإدارة إعلاناتك بكل سهولة',
                    onLoginSuccess: () {},
                  ),
                  GuestPromptWidget(
                    icon: Icons.person_rounded,
                    title: 'حسابي',
                    subtitle: 'سجل الدخول للوصول إلى تفاصيل حسابك وإعداداتك',
                    onLoginSuccess: () {},
                  ),
                ],
              );
            },
          ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _tab(IconData activeIcon, IconData inactiveIcon, String label, int index, {String? badge}) {
    return Tab(
      height: 46,
      child: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          final isActive = _tabController.index == index;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(isActive ? activeIcon : inactiveIcon, size: 22),
              if (badge != null)
                Positioned(right: -10, top: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                    ),
                    child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  )),
            ]),
            const SizedBox(height: 2),
            Text(label),
          ]);
        },
      ),
    );
  }

  Widget _headerBtn(IconData icon) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: Theme.of(context).iconTheme.color ?? const Color(0xFF4A4A4A), size: 20),
    );
  }

  Widget _headerBtnWithBadge(IconData icon, String? badge) {
    return Stack(clipBehavior: Clip.none, children: [
      _headerBtn(icon),
      if (badge != null && badge.isNotEmpty)
        Positioned(right: -4, top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
            ),
            child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          )),
    ]);
  }
}
