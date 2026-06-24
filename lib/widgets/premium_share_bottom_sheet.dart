import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/ad.dart';

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

  String get _shareUrl => 'https://sooq-com.com/ad/${ad.id}';
  String get _shareText => '${ad.title}\nشاهد هذا الاعلان على سوقكم\n$_shareUrl';

  Future<String?> _getLocalImagePath() async {
    if (ad.images.isEmpty) return null;
    try {
      final file = await DefaultCacheManager().getSingleFile(ad.images.first);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _shareUrl));
    _showSnack(context, 'تم نسخ الرابط بنجاح');
    Navigator.pop(context);
  }

  void _shareNative(BuildContext context) async {
    Navigator.pop(context);
    final imagePath = await _getLocalImagePath();
    if (imagePath != null) {
      await Share.shareXFiles([XFile(imagePath)], text: _shareText);
    } else {
      Share.share(_shareText);
    }
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, textAlign: TextAlign.center)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = (ad.images.isNotEmpty) ? ad.images.first : null;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.95) : Colors.white.withOpacity(0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
          ]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  const Text('شارك هذا الإعلان', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Ad Preview Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
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
                        child: CachedNetworkImage(imageUrl: imageUrl, height: 140, width: double.infinity, fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      ad.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text('${ad.price.toStringAsFixed(0)} دينار', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Two Professional Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildOptionTile(
                    context,
                    icon: Icons.copy_rounded,
                    title: 'نسخ الرابط',
                    subtitle: 'نسخ رابط الإعلان لمشاركته في أي مكان',
                    color: Colors.blueAccent,
                    onTap: () => _copyLink(context),
                  ),
                  const SizedBox(height: 16),
                  _buildOptionTile(
                    context,
                    icon: Icons.share_rounded,
                    title: 'مشاركة عبر وسائل التواصل',
                    subtitle: 'مشاركة صورة الإعلان مع التطبيقات الأخرى',
                    color: Colors.purpleAccent,
                    onTap: () => _shareNative(context),
                    extraContent: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          _smallIcon(const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 12), const Color(0xFF25D366)),
                          const SizedBox(width: 8),
                          _smallIcon(const FaIcon(FontAwesomeIcons.facebook, color: Color(0xFF1877F2), size: 12), const Color(0xFF1877F2)),
                          const SizedBox(width: 8),
                          _smallIcon(const FaIcon(FontAwesomeIcons.instagram, color: Color(0xFFE4405F), size: 12), const Color(0xFFE4405F)),
                          const SizedBox(width: 8),
                          _smallIcon(const FaIcon(FontAwesomeIcons.facebookMessenger, color: Color(0xFF00B2FF), size: 12), const Color(0xFF00B2FF)),
                          const SizedBox(width: 8),
                          Text('والمزيد...', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _smallIcon(Widget iconWidget, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: iconWidget,
    );
  }

  Widget _buildOptionTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap, Widget? extraContent}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (extraContent != null) extraContent,
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
