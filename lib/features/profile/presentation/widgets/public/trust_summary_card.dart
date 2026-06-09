import 'package:flutter/material.dart';
import '../../../domain/entities/user_profile.dart';

class TrustSummaryCard extends StatelessWidget {
  final UserProfile profile;

  const TrustSummaryCard({Key? key, required this.profile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        _buildMetricItem(
          context, 
          title: 'التقييم', 
          value: profile.overallRating > 0 ? '${profile.overallRating}' : 'جديد',
          subtitle: profile.reviewCount > 0 ? '${profile.reviewCount} تقييم' : 'لا تقييمات',
          icon: Icons.star_rounded,
          iconColor: const Color(0xFFE5B91A), // Darker premium gold
        ),
        _buildMetricItem(
          context, 
          title: 'معدل الرد', 
          value: '${profile.responseRate}%',
          subtitle: profile.averageResponseTime,
          icon: Icons.chat_bubble_rounded,
          iconColor: const Color(0xFF1A73E8), // Primary Accent
        ),
        _buildMetricItem(
          context, 
          title: 'الموثوقية', 
          value: '${profile.trustScore}',
          subtitle: 'ممتاز',
          icon: Icons.shield_rounded,
          iconColor: const Color(0xFF0D946A), // Emerald green
        ),
        _buildMetricItem(
          context,
          title: 'الصفقات',
          value: '${profile.dealsCompleted}',
          subtitle: 'مكتملة',
          icon: Icons.handshake_rounded,
          iconColor: const Color(0xFF673AB7), // Deep Purple
        ),
        _buildMetricItem(
          context,
          title: 'الإلغاء',
          value: '${profile.cancellationRate}%',
          subtitle: 'طلبات ملغاة',
          icon: Icons.cancel_presentation_rounded,
          iconColor: const Color(0xFFE53935), // Red
        ),
        _buildMetricItem(
          context,
          title: 'رضا العميل',
          value: '${profile.buyerSatisfaction}%',
          subtitle: 'شراء موفق',
          icon: Icons.sentiment_very_satisfied_rounded,
          iconColor: const Color(0xFFFF9800), // Orange
        ),
      ],
    );
  }

  Widget _buildMetricItem(BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: (MediaQuery.of(context).size.width - 90) / 3, // dynamically size to wrap perfectly into a 3-column grid
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [iconColor.withValues(alpha: 0.2), iconColor.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
