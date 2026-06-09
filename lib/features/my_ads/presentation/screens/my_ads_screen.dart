import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:animate_do/animate_do.dart';
import '../bloc/my_ads_bloc.dart';
import '../bloc/my_ads_event.dart';
import '../bloc/my_ads_state.dart';
import '../widgets/my_ads_header.dart';
import '../widgets/my_ad_card.dart';
import '../../../../models/category.dart';
import '../../../../providers/app_provider.dart';
import '../../../../screens/add_ad_city.dart';
import '../widgets/my_ads_skeleton.dart';
import '../../domain/entities/my_ad_entities.dart';

class MyAdsScreen extends StatefulWidget {
  final bool isStandalone;
  const MyAdsScreen({Key? key, this.isStandalone = false}) : super(key: key);

  @override
  State<MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends State<MyAdsScreen> {
  final List<String> _tabs = ['All', 'Active', 'Uncompleted', 'Expired', 'Sold', 'Paused'];
  final Map<String, String> _tabTranslations = {
    'All': 'الكل',
    'Active': 'نشط',
    'Uncompleted': 'غير مكتمل',
    'Expired': 'منتهية',
    'Sold': 'مباعة',
    'Paused': 'متوقفة',
  };

  @override
  void initState() {
    super.initState();
    context.read<MyAdsBloc>().add(LoadDashboardData());
  }

  void _onTabTapped(String tab) {
    context.read<MyAdsBloc>().add(FetchAds(status: tab));
  }

  String _getTabLabel(String tab, DashboardSummary? summary) {
    final translation = _tabTranslations[tab] ?? tab;
    if (summary == null) return translation;
    
    int count = 0;
    switch (tab) {
      case 'All': count = summary.totalAds; break;
      case 'Active': count = summary.activeAds; break;
      case 'Uncompleted': count = summary.pendingAds; break;
      case 'Expired': count = summary.expiredAds; break;
      case 'Sold': count = summary.soldAds; break;
      case 'Paused': count = summary.pausedAds; break;
    }
    return '$translation ($count)';
  }

  void _handleAction(int adId, String title, String currentStatus) {
    ActionBottomSheet.show(
      context,
      adTitle: title,
      status: currentStatus,
      onActionSelected: (action) {
        if (action == 'edit') {
          // Navigate to edit screen starting from City
          final state = context.read<MyAdsBloc>().state;
          final adToEdit = state.ads.firstWhere((a) => a.baseAd.id == adId).baseAd;
          
          final categories = context.read<AppProvider>().categories ?? [];
          final category = categories.firstWhere(
            (c) => c.id == adToEdit.categoryId, 
            orElse: () => Category(id: adToEdit.categoryId ?? 1, name: adToEdit.attributes?['leaf_category_name']?.toString() ?? 'إعلان', parentId: null),
          );
          
          final editingAdData = {
             'id': adToEdit.id,
             'title': adToEdit.title,
             'description': adToEdit.description,
             'price': adToEdit.price,
             'location': adToEdit.location,
             'attributes': adToEdit.attributes ?? {},
             'image_urls': adToEdit.images,
          };
          
          Navigator.push(context, MaterialPageRoute(builder: (_) => AddAdCityPage(
             selectedLeafCategory: category,
             transactionType: adToEdit.attributes?['transaction_type']?.toString() ?? '',
             editingAdData: editingAdData,
          ))).then((_) {
            if (context.mounted) {
              context.read<MyAdsBloc>().add(LoadDashboardData());
            }
          });
        } else {
          context.read<MyAdsBloc>().add(PerformSingleAction(adId, action));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MyAdsBloc, MyAdsState>(
      listener: (context, state) {
        if (state.actionSuccessMessage != null) {
          String translatedMsg = 'تم تنفيذ العملية بنجاح';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translatedMsg), backgroundColor: Colors.green));
        }
        if (state.errorMessage != null) {
          if (state.errorMessage!.contains('already_republished')) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('هذا الإعلان تم إعادة نشره بالفعل وهو الآن في أعلى القائمة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)), 
              backgroundColor: Colors.orange,
            ));
          } else if (state.errorMessage!.contains('Bulk action') || state.errorMessage!.contains('Failed to perform')) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء التنفيذ'), backgroundColor: Colors.red));
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          appBar: _buildAppBar(context, state),
          body: Stack(
            children: [
              RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<MyAdsBloc>();
              bloc.add(LoadDashboardData());
              // Wait until status changes from loading to loaded or error
              await bloc.stream.firstWhere((s) => s.status != MyAdsStatus.loading);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: FadeInDown(
                    duration: const Duration(milliseconds: 500),
                    child: MyAdsHeader(summary: state.dashboardSummary),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    child: Container(
                      color: const Color(0xFFF4F6FA),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: _tabs.map((tab) {
                            final isActive = state.activeFilter == tab;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: ChoiceChip(
                                label: Text(_getTabLabel(tab, state.dashboardSummary)),
                                selected: isActive,
                                onSelected: (selected) {
                                  if (selected) _onTabTapped(tab);
                                },
                                selectedColor: const Color(0xFF1A73E8),
                                labelStyle: TextStyle(
                                  color: isActive ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                if (state.status == MyAdsStatus.loading)
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: MyAdsSkeleton()))
                else if (state.status == MyAdsStatus.error && state.ads.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(state.errorMessage ?? 'An error occurred', style: const TextStyle(color: Colors.grey)),
                          TextButton(
                            onPressed: () => context.read<MyAdsBloc>().add(LoadDashboardData()),
                            child: const Text('Retry'),
                          )
                        ],
                      ),
                    ),
                  )
                else if (state.ads.isEmpty)
                  SliverFillRemaining(
                    child: FadeInUp(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Pulse(
                              infinite: true,
                              duration: const Duration(seconds: 3),
                              child: Icon(Icons.inbox_rounded, size: 90, color: Colors.blue.withOpacity(0.2)),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'لم تقم بنشر أي إعلانات بعد\nابدأ بالبيع الآن!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final ad = state.ads[index];
                        return FadeInUp(
                          duration: const Duration(milliseconds: 400),
                          delay: Duration(milliseconds: index * 50),
                          child: MyAdCard(
                            ad: ad,
                            isSelectionMode: state.isSelectionMode,
                            isSelected: state.selectedAdIds.contains(ad.baseAd.id),
                            onTap: () {
                              context.read<MyAdsBloc>().add(ToggleAdSelection(ad.baseAd.id));
                            },
                            onLongPress: () {
                              if (!state.isSelectionMode) {
                                context.read<MyAdsBloc>().add(const ToggleSelectionMode(true));
                                context.read<MyAdsBloc>().add(ToggleAdSelection(ad.baseAd.id));
                              }
                            },
                            onActionTap: () => _handleAction(ad.baseAd.id, ad.baseAd.title, ad.status),
                            onRepublishTap: () {
                              context.read<MyAdsBloc>().add(PerformSingleAction(ad.baseAd.id, 'republish'));
                            },
                          ),
                        );
                      },
                      childCount: state.ads.length,
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
            
            // Selection Bottom Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              bottom: state.isSelectionMode ? 16 : -100,
              left: 16,
              right: 16,
              child: _buildSelectionBar(context, state),
            ),
          ],
        ),
        );
      },
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context, MyAdsState state) {
    if (state.isSelectionMode) {
      return AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.read<MyAdsBloc>().add(ClearSelection()),
        ),
        title: Text(
          'تم تحديد ${state.selectedAdIds.length}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all, color: Colors.white),
            onPressed: () => context.read<MyAdsBloc>().add(SelectAllAds()),
          ),
        ],
      );
    }
    if (widget.isStandalone) {
      return AppBar(
        title: const Text('إعلاناتي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      );
    }
    
    return null;
  }

  Widget _buildSelectionBar(BuildContext context, MyAdsState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: state.isActionLoading 
        ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.white)))
        : Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (state.selectedAdIds.isNotEmpty) ...[
            _SelectionAction(
              icon: Icons.pause_circle_outline, 
              label: 'إيقاف',
              onTap: () => context.read<MyAdsBloc>().add(PerformBulkAction(state.selectedAdIds.toList(), 'pause')),
            ),
            _SelectionAction(
              icon: Icons.play_circle_outline, 
              label: 'تفعيل',
              onTap: () => context.read<MyAdsBloc>().add(PerformBulkAction(state.selectedAdIds.toList(), 'resume')),
            ),
            _SelectionAction(
              icon: Icons.sell_outlined, 
              label: 'تم بيعه',
              onTap: () => context.read<MyAdsBloc>().add(PerformBulkAction(state.selectedAdIds.toList(), 'sold')),
            ),
            _SelectionAction(
              icon: Icons.delete_outline, 
              label: 'حذف',
              color: Colors.redAccent,
              onTap: () => context.read<MyAdsBloc>().add(PerformBulkAction(state.selectedAdIds.toList(), 'delete')),
            ),
          ] else
            const Text('لم يتم تحديد أي إعلان', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SelectionAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _SelectionAction({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color ?? Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
  }
}
