import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ad.dart';
import '../utils/share_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PremiumShareBottomSheet extends StatelessWidget {
  final Ad ad;

  const PremiumShareBottomSheet({Key? key, required this.ad}) : super(key: key);

  static void show(BuildContext context, Ad ad) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PremiumShareBottomSheet(ad: ad),
    );
  }

  void _copyLink(BuildContext context) {
    final String shareUrl = 'https://sooq-com.com/ad/${ad.id}';
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الرابط بنجاح', textAlign: TextAlign.center)),
    );
    Navigator.pop(context);
  }

  void _shareViaWhatsApp(BuildContext context) async {
    final String shareUrl = 'https://sooq-com.com/ad/${ad.id}';
    final String text = '${ad.title}\nشاهد هذا الاعلان على سوقكم\n$shareUrl';
    final Uri waUrl = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    
    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تطبيق واتساب غير مثبت', textAlign: TextAlign.center)),
      );
    }
    Navigator.pop(context);
  }

  void _shareNativeWithImage(BuildContext context) {
    Navigator.pop(context); // Close sheet before sharing
    final imageUrl = (ad.images.isNotEmpty) ? ad.images.first : null;
    ShareHelper.shareAdWithImage(ad.title, ad.id.toString(), imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = (ad.images.isNotEmpty) ? ad.images.first : null;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.85) : Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40), // Balance
                const Text(
                  'شارك هذا الإعلان',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ad Preview Card
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    ad.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ad.price.toStringAsFixed(0)} دينار',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Share Options Grid
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _buildShareIcon(
                  context,
                  icon: Icons.copy_rounded,
                  label: 'نسخ الرابط',
                  color: Colors.blueAccent,
                  onTap: () => _copyLink(context),
                ),
                _buildShareIcon(
                  context,
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'واتساب',
                  color: Colors.green,
                  onTap: () => _shareViaWhatsApp(context),
                ),
                _buildShareIcon(
                  context,
                  icon: Icons.image_rounded,
                  label: 'مشاركة كصورة',
                  color: Colors.purpleAccent,
                  onTap: () => _shareNativeWithImage(context),
                ),
                _buildShareIcon(
                  context,
                  icon: Icons.more_horiz_rounded,
                  label: 'المزيد',
                  color: Colors.grey.shade600,
                  onTap: () => _shareNativeWithImage(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShareIcon(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
