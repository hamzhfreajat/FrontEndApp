import 'package:flutter/material.dart';
import '../../../domain/entities/user_profile.dart';

class AboutSection extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onEditLanguagesTap;
  final VoidCallback onEditContactTap;

  const AboutSection({
    Key? key,
    required this.profile,
    required this.onEditLanguagesTap,
    required this.onEditContactTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('طريقة التواصل المفضلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                IconButton(
                  onPressed: onEditContactTap,
                  icon: Icon(Icons.edit_rounded, color: Colors.grey.shade600, size: 20),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                )
              ],
            ),
            const SizedBox(height: 12),
            _buildContactBadge(profile.preferredContact),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('اللغات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                IconButton(
                  onPressed: onEditLanguagesTap,
                  icon: Icon(Icons.edit_rounded, color: Colors.grey.shade600, size: 20),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                )
              ],
            ),
            const SizedBox(height: 12),
            profile.languagesSpoken.isEmpty
              ? Text('لم يتم إضافة أي لغات', style: TextStyle(color: Colors.grey.shade500))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.languagesSpoken.map((lang) => Chip(
                    label: Text(lang, style: const TextStyle(color: Colors.black87)),
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide.none,
                  )).toList(),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactBadge(String? method) {
    if (method == null || method.isEmpty) {
      return Text('غير محدد', style: TextStyle(color: Colors.grey.shade500));
    }
    
    IconData icon;
    Color color;
    String label;

    switch (method.toLowerCase()) {
      case 'whatsapp':
        icon = Icons.wechat; // Closest material to WA usually or fa-whatsapp
        color = const Color(0xFF25D366);
        label = 'تواصل واتساب';
        break;
      case 'chat':
        icon = Icons.chat_rounded;
        color = const Color(0xFF1A73E8);
        label = 'دردشة التطبيق';
        break;
      case 'phone':
      default:
        icon = Icons.phone_rounded;
        color = const Color(0xFF0D946A);
        label = 'اتصال هاتفي';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
