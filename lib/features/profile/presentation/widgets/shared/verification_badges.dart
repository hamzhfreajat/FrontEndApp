import 'package:flutter/material.dart';

class VerificationBadges extends StatelessWidget {
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isIdentityVerified;

  const VerificationBadges({
    Key? key,
    required this.isEmailVerified,
    required this.isPhoneVerified,
    required this.isIdentityVerified,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          if (isIdentityVerified) _buildBadge(context, Icons.verified_user_rounded, 'هوية موثقة', const Color(0xFF0D946A)),
          if (isPhoneVerified) _buildBadge(context, Icons.phone_android_rounded, 'رقم موثق', const Color(0xFF1A73E8)),
          if (isEmailVerified) _buildBadge(context, Icons.email_rounded, 'بريد موثق', const Color(0xFFE56A1A)),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, IconData icon, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
