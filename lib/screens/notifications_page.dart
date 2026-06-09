import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/notification_provider.dart';
import '../services/api_service.dart';
import 'ad_details_page.dart';
import 'category_details_page.dart';
import '../features/chat/presentation/screens/premium_inbox_screen.dart';
import '../features/my_ads/presentation/screens/my_ads_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/my_ads/presentation/bloc/my_ads_bloc.dart';
import '../features/my_ads/data/repositories/my_ads_repository_impl.dart';
import 'root_screen.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    
    // Instantly mark as read before fetching to ensure backend is synced
    if (provider.unreadCount > 0 || provider.notifications.any((n) => n['is_read'] == false)) {
      await provider.markAllAsRead();
    }
    
    await provider.loadNotifications();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  IconData _getIconForType(String? type) {
    if (type == null) return Icons.notifications_active_rounded;
    switch (type) {
      case 'welcome':
        return Icons.celebration_rounded;
      case 'ad_created':
        return Icons.add_task_rounded;
      case 'ad_published':
        return Icons.visibility_rounded;
      case 'ad_unpublished':
        return Icons.visibility_off_rounded;
      case 'phone_revealed':
        return Icons.phone_callback_rounded;
      case 'chat_started':
        return Icons.chat_bubble_outline_rounded;
      case 'category_milestone':
        return Icons.rocket_launch_rounded;
      case 'republish_available':
        return Icons.autorenew_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getColorForType(String? type) {
    if (type == null) return Colors.blueGrey;
    switch (type) {
      case 'welcome':
        return Colors.amber.shade700;
      case 'ad_created':
        return Colors.blue.shade600;
      case 'ad_published':
        return Colors.green.shade600;
      case 'ad_unpublished':
        return Colors.red.shade600;
      case 'phone_revealed':
        return Colors.deepPurple.shade600;
      case 'chat_started':
        return Colors.teal.shade600;
      case 'category_milestone':
        return Colors.pink.shade600;
      case 'republish_available':
        return Colors.orange.shade600;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotificationProvider>(context);
    final notifications = provider.notifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'الإشعارات',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (notifications.any((n) => n['is_read'] == false))
            TextButton.icon(
              onPressed: () async {
                await provider.markAllAsRead();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تحديد الكل كمقروء ✅', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.done_all_rounded, color: Colors.blueAccent, size: 20),
              label: const Text('تحديد الكل', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      final bool isRead = notif['is_read'] ?? true;
                      final DateTime createdAt = DateTime.parse(notif['created_at']).toLocal();
                      final String timeAgo = timeago.format(createdAt, locale: 'ar');
                      final bool isChat = notif['type'] == 'chat_message';

                      return GestureDetector(
                        onTap: () async {
                          if (!isRead) {
                            provider.markAsRead(notif['id']);
                          }
                          
                          if (isChat) {
                            if (mounted) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumInboxScreen()));
                            }
                          } else if (notif['type'] == 'republish_available') {
                            if (mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const RootScreen(initialIndex: 2)),
                                (route) => false,
                              );
                            }
                          } else if (notif['reference_id'] != null) {
                            try {
                              final adId = int.parse(notif['reference_id'].toString());
                              final ad = await ApiService().fetchAdById(adId);
                              if (mounted) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => AdDetailsPage(ad: ad)));
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تعذر تحميل الإعلان')),
                                );
                              }
                            }
                          } else if (notif['type'] == 'category_milestone' && notif['reference_id'] != null) {
                            try {
                              final catId = int.parse(notif['reference_id'].toString());
                              final category = await ApiService().fetchCategoryById(catId);
                              if (mounted) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryDetailsPage(category: category)));
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تعذر تحميل القسم')),
                                );
                              }
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.white : Colors.blue.shade50.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isRead ? Colors.grey.shade200 : Colors.blue.shade200,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon Container
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _getColorForType(notif['type']).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getIconForType(notif['type']),
                                  color: _getColorForType(notif['type']),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notif['title'] ?? 'إشعار جديد',
                                            style: TextStyle(
                                              fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                              fontSize: 16,
                                              color: const Color(0xFF1A1A2E),
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            margin: const EdgeInsets.only(right: 8, top: 4),
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Colors.blueAccent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      notif['body'] ?? '',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Text(
                                          timeAgo,
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (notif['reference_id'] != null || isChat || notif['type'] == 'republish_available') ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            if (!isRead) provider.markAsRead(notif['id']);
                                            
                                            if (isChat) {
                                              if (mounted) {
                                                Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumInboxScreen()));
                                              }
                                            } else if (notif['type'] == 'republish_available') {
                                              if (notif['reference_id'] != null) {
                                                try {
                                                  final adId = int.parse(notif['reference_id'].toString());
                                                  await ApiService().republishAd(adId);
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('تم إعادة نشر إعلانك ورفعه للأعلى! 🚀', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('حدث خطأ أثناء إعادة النشر')),
                                                    );
                                                  }
                                                }
                                              }
                                              if (mounted) {
                                                provider.markAsRead(notif['id']);
                                                Navigator.pushAndRemoveUntil(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => const RootScreen(initialIndex: 2)),
                                                  (route) => false,
                                                );
                                              }
                                            } else if (notif['type'] == 'category_milestone' && notif['reference_id'] != null) {
                                              try {
                                                final catId = int.parse(notif['reference_id'].toString());
                                                final category = await ApiService().fetchCategoryById(catId);
                                                if (mounted) {
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryDetailsPage(category: category)));
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('تعذر تحميل القسم')),
                                                  );
                                                }
                                              }
                                            } else if (notif['reference_id'] != null) {
                                              try {
                                                final adId = int.parse(notif['reference_id'].toString());
                                                final ad = await ApiService().fetchAdById(adId);
                                                if (mounted) {
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => AdDetailsPage(ad: ad)));
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('تعذر تحميل الإعلان')),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                          icon: Icon(isChat ? Icons.chat_rounded : notif['type'] == 'category_milestone' ? Icons.category_rounded : notif['type'] == 'republish_available' ? Icons.rocket_launch_rounded : Icons.visibility_rounded, size: 18),
                                          label: Text(
                                            isChat ? 'عرض المحادثة' : notif['type'] == 'category_milestone' ? 'تصفح الإعلانات' : notif['type'] == 'republish_available' ? 'إعادة نشر 🚀' : 'عرض الإعلان',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: notif['type'] == 'republish_available' ? Colors.orange.shade50 : Colors.blue.shade50,
                                            foregroundColor: notif['type'] == 'republish_available' ? Colors.orange.shade800 : Colors.blue.shade700,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                          ),
                                        ),
                                      ),
                                    ],
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_off_rounded, size: 60, color: Colors.blue.shade300),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا توجد إشعارات',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أنت على اطلاع بكل جديد.\nستظهر إشعاراتك هنا عند توفرها.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
