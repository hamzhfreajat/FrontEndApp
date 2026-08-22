import 'package:flutter/material.dart';

import '../../../domain/entities/user_profile.dart';
import '../../../../../screens/saved_ads_page.dart';
import '../../../../../screens/wallet_page.dart';
import 'package:provider/provider.dart';
import '../../../../../providers/app_provider.dart';
import '../../../../../providers/saved_search_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/profile_bloc.dart';

class ActivityHubSection extends StatelessWidget {
  final UserProfile profile;
  const ActivityHubSection({Key? key, required this.profile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('نشاطاتي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          const SizedBox(height: 16),
          Consumer2<AppProvider, SavedSearchProvider>(
            builder: (context, appProvider, savedSearchProvider, _) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildActivityCard(
                      context, 'محفظتي', '${profile.walletBalance.toStringAsFixed(2)} JOD', Icons.account_balance_wallet_rounded, const Color(0xFF4CAF50),
                      onTap: () {
                        final profileBloc = context.read<ProfileBloc>();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: profileBloc,
                            child: WalletPage(),
                          ),
                        ));
                      },
                    ),
                    _buildActivityCard(
                      context, 'الإعلانات المحفوظة', '${appProvider.metrics?.savedItems ?? 0} إعلان', Icons.bookmark_rounded, const Color(0xFFE5B91A),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAdsPage(initialIndex: 0)));
                      },
                    ),
                    _buildActivityCard(
                      context, 'عمليات البحث', '${savedSearchProvider.savedSearches.length} محفوظات', Icons.search_rounded, const Color(0xFF1A73E8),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAdsPage(initialIndex: 1)));
                      },
                    ),
                    _buildActivityCard(context, 'مستخدمين أتابعهم', '${profile.followingCount} مستخدم', Icons.people_rounded, const Color(0xFF8B5CF6)),
                    _buildActivityCard(context, 'مسودات', '0 مسودة', Icons.drafts_rounded, const Color(0xFF64748B)),
                  ],
                ),
              );
            }
          )
        ],
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, String title, String subtitle, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
