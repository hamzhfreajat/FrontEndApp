import 'package:flutter/material.dart';
import '../../../domain/entities/user_profile.dart';

class SellerStatsRow extends StatelessWidget {
  final UserProfile profile;

  const SellerStatsRow({Key? key, required this.profile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('متابعون', profile.followersCount.toString())),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('يتابع', profile.followingCount.toString())),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('إعلان نشط', profile.activeAdsCount.toString())),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('تم البيع', profile.soldAdsCount.toString())),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
