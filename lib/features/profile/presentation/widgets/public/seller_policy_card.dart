import 'package:flutter/material.dart';
import '../../../domain/entities/user_profile.dart';

class SellerPolicyCard extends StatelessWidget {
  final UserProfile profile;

  const SellerPolicyCard({Key? key, required this.profile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!profile.isBusiness || (profile.businessPolicy == null && profile.shopLocation == null)) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Dark premium color
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'عن المعرض',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (profile.businessPolicy != null) ...[
            _buildPolicyRow(Icons.verified_user_outlined, 'الضمان والسياسة', profile.businessPolicy!),
            const SizedBox(height: 16),
          ],
          if (profile.shopLocation != null) ...[
            _buildPolicyRow(Icons.location_on_outlined, 'الموقع', profile.shopLocation!),
            const SizedBox(height: 16),
          ],
          if (profile.shopHours != null) ...[
            _buildPolicyRow(Icons.access_time_rounded, 'أوقات الدوام', profile.shopHours!),
          ],
        ],
      ),
    );
  }

  Widget _buildPolicyRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1A73E8).withValues(alpha: 0.8), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
