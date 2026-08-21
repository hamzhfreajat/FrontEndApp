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
import '../../../../services/analytics_engine.dart';
import '../../../../screens/add_ad_details.dart';
import '../../../../services/api_service.dart';
import '../../../../services/iap_service.dart';

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
    IAPService().initialize();
  }

  @override
  void dispose() {
    IAPService().dispose();
    super.dispose();
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
          AnalyticsEngine().logButtonTapped(buttonName: 'edit_ad', location: 'my_ads_screen');
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
             'phone_number': adToEdit.phoneNumber,
          };
          
          final String city = adToEdit.attributes?['city']?.toString() ?? 'O1U.O U+';
          final String region = adToEdit.attributes?['region']?.toString() ?? '';
          
          Navigator.push(context, MaterialPageRoute(builder: (_) => AddAdDetailsPage(
             selectedLeafCategory: category,
             transactionType: adToEdit.attributes?['transaction_type']?.toString() ?? '',
             selectedCity: city,
             selectedRegion: region,
             editingAdData: editingAdData,
          ))).then((_) {
            if (context.mounted) {
              context.read<MyAdsBloc>().add(LoadDashboardData());
            }
          });
        } else if (action == 'promote') {
          _showBidBottomSheet(context, adId);
        } else {
          AnalyticsEngine().logButtonTapped(buttonName: 'single_$action', location: 'my_ads_screen');
          context.read<MyAdsBloc>().add(PerformSingleAction(adId, action));
        }
      },
    );
  }

  void _showTopUpBottomSheet(BuildContext context, int adId, double bidToRetry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _TopUpBottomSheet(adId: adId, bidToRetry: bidToRetry);
      }
    );
  }

  void _showBidBottomSheet(BuildContext context, int adId) {
    final state = context.read<MyAdsBloc>().state;
    final ad = state.ads.firstWhere((a) => a.baseAd.id == adId).baseAd;
    double currentBid = ad.cpcBid;

    // Get Category Name
    final categories = context.read<AppProvider>().categories ?? [];
    String categoryName = 'القسم الحالي';
    if (ad.categoryId != null && categories.isNotEmpty) {
      try {
        categoryName = categories.firstWhere((c) => c.id == ad.categoryId).name;
      } catch (e) {
        // Not found
      }
    }
    
    // Calculate average CPC from ads in the same category
    final categoryAds = state.ads.where((a) => a.baseAd.categoryId == ad.categoryId && a.baseAd.cpcBid > 0).toList();
    double avgCpc = 0.07; // Default minimum
    if (categoryAds.isNotEmpty) {
      double totalCpc = categoryAds.fold(0.0, (sum, item) => sum + item.baseAd.cpcBid);
      avgCpc = double.parse((totalCpc / categoryAds.length).toStringAsFixed(2));
      if (avgCpc < 0.07) avgCpc = 0.07;
    }
    
    final TextEditingController _bidController = TextEditingController(text: currentBid.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ترويج الإعلان (الدفع مقابل النقرة)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text(
                'عيّن سعر النقرة الخاص بك لترويج إعلانك. الحد الأدنى هو 0.07 دينار للنقرة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontFamily: 'Tajawal', color: Colors.black87, fontSize: 13, height: 1.5),
                          children: [
                            const TextSpan(text: 'متوسط سعر النقرة للمعلنين في قسم '),
                            TextSpan(text: '($categoryName)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            const TextSpan(text: ' هو '),
                            TextSpan(text: '$avgCpc دينار.\n', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const TextSpan(text: 'الإعلانات ذات سعر النقرة الأعلى تظهر في صدارة النتائج أولاً!'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              StatefulBuilder(
                builder: (BuildContext sbContext, StateSetter setState) {
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (currentBid > 0.07) {
                                setState(() {
                                  currentBid = double.parse((currentBid - 0.01).toStringAsFixed(2));
                                  _bidController.text = currentBid.toStringAsFixed(2);
                                });
                              }
                            },
                          ),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _bidController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                suffixText: 'JOD',
                                border: UnderlineInputBorder(),
                              ),
                              onChanged: (val) {
                                double? parsed = double.tryParse(val);
                                if (parsed != null) {
                                  currentBid = parsed;
                                }
                              },
                              onSubmitted: (val) {
                                double? parsed = double.tryParse(val);
                                if (parsed == null || parsed < 0.07) {
                                  parsed = 0.07;
                                }
                                setState(() {
                                  currentBid = double.parse(parsed!.toStringAsFixed(2));
                                  _bidController.text = currentBid.toStringAsFixed(2);
                                });
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setState(() {
                                currentBid = double.parse((currentBid + 0.01).toStringAsFixed(2));
                                _bidController.text = currentBid.toStringAsFixed(2);
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              if (currentBid < 0.07) {
                                currentBid = 0.07;
                              }
                              await ApiService().setAdBid(adId, currentBid);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تفعيل الترويج بنجاح!')));
                              context.read<MyAdsBloc>().add(LoadDashboardData());
                            } on InsufficientBalanceException {
                              Navigator.pop(ctx);
                              _showTopUpBottomSheet(context, adId, currentBid);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تفعيل الترويج: $e')));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('حفظ الترويج', style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextButton(
                        onPressed: () async {
                          try {
                            await ApiService().setAdBid(adId, 0.0);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إيقاف الترويج بنجاح!')));
                            context.read<MyAdsBloc>().add(LoadDashboardData());
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل إيقاف الترويج: $e')));
                          }
                        },
                        child: Text('إيقاف الترويج الحالي', style: TextStyle(color: Colors.red)),
                      ),
                      SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPromotionInfoDialog(BuildContext context, int adId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Animated Mockup replacing static icon
              const AnimatedInteractionMockup(),
              const SizedBox(height: 24),
              const Text(
                'كيف يعمل ترويج الإعلانات؟',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              const Text(
                'نظامنا يعمل بالدفع مقابل النقرة (Pay-Per-Click). لن يتم خصم أي مبلغ من رصيدك إلا إذا قام المشتري بالاهتمام الحقيقي والتواصل معك.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 32),
              
              // Features
              _buildPromoFeatureRow(
                icon: Icons.ads_click_rounded,
                title: 'تفاعلات حقيقية فقط',
                desc: 'يتم احتساب التكلفة فقط عند النقر على (رقم الهاتف، المراسلة، أو واتساب). المشاهدات العادية مجانية بالكامل.',
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              _buildPromoFeatureRow(
                icon: Icons.trending_up_rounded,
                title: 'أعلى القائمة',
                desc: 'إعلانك سيظهر في أعلى نتائج البحث وأقسام الفئات لجذب أكبر عدد من المشترين.',
                color: Colors.green,
              ),
              const SizedBox(height: 20),
              _buildPromoFeatureRow(
                icon: Icons.control_camera_rounded,
                title: 'تحكم كامل بالميزانية',
                desc: 'يمكنك تحديد سعر النقرة وإيقاف الترويج في أي وقت تريده بضغطة زر.',
                color: Colors.purple,
              ),
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showBidBottomSheet(context, adId);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFFD4AF37),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'أنا أفهم ذلك، استمر للترويج',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromoFeatureRow({required IconData icon, required String title, required String desc, required Color color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
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
                              AnalyticsEngine().logButtonTapped(buttonName: 'single_republish', location: 'my_ads_screen');
                              context.read<MyAdsBloc>().add(PerformSingleAction(ad.baseAd.id, 'republish'));
                            },
                            onPromoteTap: () {
                              _showPromotionInfoDialog(context, ad.baseAd.id);
                            },
                            onStopPromoteTap: () async {
                              try {
                                await ApiService().setAdBid(ad.baseAd.id, 0.0);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إيقاف الترويج بنجاح!')));
                                context.read<MyAdsBloc>().add(LoadDashboardData());
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل إيقاف الترويج: $e')));
                              }
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
              onTap: () {
                AnalyticsEngine().logButtonTapped(buttonName: 'bulk_pause', location: 'my_ads_screen');
                context.read<MyAdsBloc>().add(PerformBulkAction(state.selectedAdIds.toList(), 'pause'));
              },
            ),
            _SelectionAction(
              icon: Icons.play_circle_outline, 
              label: 'تفعيل',
              onTap: () {
                AnalyticsEngine().logButtonTapped(buttonName: 'bulk_resume', location: 'my_ads_screen');
                context.read<MyAdsBloc>().add(PerformBulkAction(state.selectedAdIds.toList(), 'resume'));
              },
            ),
            _SelectionAction(
              icon: Icons.sell_outlined, 
              label: 'تم بيعه',
              onTap: () {
                AnalyticsEngine().logButtonTapped(buttonName: 'bulk_sold', location: 'my_ads_screen');
                context.read<MyAdsBloc>().add(PerformBulkAction(state.selectedAdIds.toList(), 'sold'));
              },
            ),
            _SelectionAction(
              icon: Icons.delete_outline, 
              label: 'حذف',
              color: Colors.redAccent,
              onTap: () {
                AnalyticsEngine().logButtonTapped(buttonName: 'bulk_delete', location: 'my_ads_screen');
                context.read<MyAdsBloc>().add(PerformBulkAction(state.selectedAdIds.toList(), 'delete'));
              },
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

class AnimatedInteractionMockup extends StatefulWidget {
  const AnimatedInteractionMockup({Key? key}) : super(key: key);

  @override
  State<AnimatedInteractionMockup> createState() => _AnimatedInteractionMockupState();
}

class _AnimatedInteractionMockupState extends State<AnimatedInteractionMockup> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _clickAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

    // Position goes from 0.0 (left) to 1.0 (right)
    _positionAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.15), weight: 20), // pause at phone
      TweenSequenceItem(tween: Tween(begin: 0.15, end: 0.5).chain(CurveTween(curve: Curves.easeInOutCubic)), weight: 15), // move to chat
      TweenSequenceItem(tween: ConstantTween(0.5), weight: 20), // pause at chat
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.85).chain(CurveTween(curve: Curves.easeInOutCubic)), weight: 15), // move to whatsapp
      TweenSequenceItem(tween: ConstantTween(0.85), weight: 20), // pause at whatsapp
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.15).chain(CurveTween(curve: Curves.easeInOutCubic)), weight: 10), // move back
    ]).animate(_controller);

    // Click animation scales down the hand when it's paused
    _clickAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.75), weight: 5), // click down
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 1.0), weight: 5), // release
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 10), 
      
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 15), // move
      
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.75), weight: 5), // click down
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 1.0), weight: 5), // release
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 10), 

      TweenSequenceItem(tween: ConstantTween(1.0), weight: 15), // move

      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.75), weight: 5), // click down
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 1.0), weight: 5), // release
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 10), 
      
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 10), // move back
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildActionButton(icon: Icons.chat_bubble_rounded, label: 'محادثة', color: const Color(0xFF3B82F6), isSolid: false)),
                const SizedBox(width: 8),
                Expanded(child: _buildActionButton(icon: Icons.wechat_rounded, label: 'واتساب', color: const Color(0xFF25D366), isSolid: true)),
                const SizedBox(width: 8),
                Expanded(child: _buildActionButton(icon: Icons.call, label: 'اتصال', color: const Color(0xFF10B981), isSolid: true)),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Align(
                alignment: FractionalOffset(_positionAnimation.value, 0.65),
                child: Transform.scale(
                  scale: _clickAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.5),
                          blurRadius: _clickAnimation.value < 0.9 ? 15 : 0,
                          spreadRadius: _clickAnimation.value < 0.9 ? 8 : 0, 
                        ),
                      ],
                    ),
                    child: const Icon(Icons.touch_app, color: Color(0xFFD4AF37), size: 40),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required bool isSolid}) {
    return Container(
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
          Icon(icon, color: isSolid ? Colors.white : color, size: 16),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: isSolid ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
        ],
      ),
    );
  }
}

class _TopUpBottomSheet extends StatefulWidget {
  final int adId;
  final double bidToRetry;

  const _TopUpBottomSheet({required this.adId, required this.bidToRetry});

  @override
  State<_TopUpBottomSheet> createState() => _TopUpBottomSheetState();
}

class _TopUpBottomSheetState extends State<_TopUpBottomSheet> {
  String _selectedProductId = 'wallet_topup_10';

  final List<Map<String, dynamic>> _options = [
    {'id': 'wallet_topup_10', 'amount': 10, 'label': '10 JOD'},
    {'id': 'wallet_topup_20', 'amount': 20, 'label': '20 JOD'},
    {'id': 'wallet_topup_50', 'amount': 50, 'label': '50 JOD'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text('شحن الرصيد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            'اختر قيمة الشحن المناسبة لك:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _options.map((option) {
              final isSelected = _selectedProductId == option['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedProductId = option['id'];
                  });
                },
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${option['amount']}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.blue : Colors.black87,
                        ),
                      ),
                      Text(
                        'JOD',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري معالجة الدفع...')));
                
                IAPService().onPurchaseCompleted = (success) async {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم شحن الرصيد بنجاح!')));
                    try {
                      await ApiService().setAdBid(widget.adId, widget.bidToRetry);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفعيل الترويج بنجاح!')));
                        context.read<MyAdsBloc>().add(LoadDashboardData());
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تفعيل الترويج: $e')));
                      }
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشلت عملية الدفع أو تم إلغاؤها.')));
                    }
                  }
                };

                bool started = await IAPService().buyTopUp(_selectedProductId);
                if (!started) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('خدمة الدفع غير متوفرة حالياً (المنتج غير موجود في المتجر).')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('شحن الرصيد الآن', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
