import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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

  void _shareViaWhatsApp(BuildContext context) async {
    Navigator.pop(context);
    final Uri url = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(_shareText)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showSnack(context, 'تطبيق واتساب غير مثبت');
    }
  }

  void _shareViaFacebook(BuildContext context) async {
    Navigator.pop(context);
    final Uri url = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_shareUrl)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _shareViaInstagram(BuildContext context) async {
    // Instagram only accepts images via native share
    _shareNative(context);
  }

  void _shareViaMessenger(BuildContext context) async {
    Navigator.pop(context);
    final Uri url = Uri.parse('fb-messenger://share/?link=${Uri.encodeComponent(_shareUrl)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showSnack(context, 'تطبيق ماسنجر غير مثبت');
    }
  }

  void _shareViaSMS(BuildContext context) async {
    Navigator.pop(context);
    final Uri url = Uri.parse('sms:?body=${Uri.encodeComponent(_shareText)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _shareViaEmail(BuildContext context) async {
    Navigator.pop(context);
    final Uri url = Uri.parse('mailto:?subject=${Uri.encodeComponent(ad.title)}&body=${Uri.encodeComponent(_shareText)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
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
                  const Text('شارك هذا الإعلان', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Tajawal'),
                    ),
                    const SizedBox(height: 4),
                    Text('${ad.price.toStringAsFixed(0)} دينار', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Horizontally Scrollable Icons
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildIcon(context, iconWidget: const FaIcon(FontAwesomeIcons.facebook, color: Colors.white, size: 28), color: const Color(0xFF1877F2), label: 'Facebook', onTap: () => _shareViaFacebook(context)),
                  _buildIcon(context, iconWidget: const FaIcon(FontAwesomeIcons.instagram, color: Colors.white, size: 28), color: const Color(0xFFE4405F), label: 'Instagram', onTap: () => _shareViaInstagram(context)),
                  _buildIcon(context, iconWidget: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 28), color: const Color(0xFF25D366), label: 'WhatsApp', onTap: () => _shareViaWhatsApp(context)),
                  _buildIcon(context, iconWidget: const FaIcon(FontAwesomeIcons.facebookMessenger, color: Colors.white, size: 28), color: const Color(0xFF00B2FF), label: 'Messenger', onTap: () => _shareViaMessenger(context)),
                  _buildIcon(context, iconWidget: const Icon(Icons.email, color: Colors.white, size: 28), color: const Color(0xFFD44638), label: 'Email', onTap: () => _shareViaEmail(context)),
                  _buildIcon(context, iconWidget: const Icon(Icons.sms, color: Colors.white, size: 28), color: Colors.amber.shade700, label: 'SMS', onTap: () => _shareViaSMS(context)),
                  _buildIcon(context, iconWidget: const Icon(Icons.copy, color: Colors.white, size: 28), color: Colors.grey.shade700, label: 'Copy Link', onTap: () => _copyLink(context)),
                  _buildIcon(context, iconWidget: const Icon(Icons.more_horiz, color: Colors.white, size: 28), color: Colors.blueGrey, label: 'More', onTap: () => _shareNative(context)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, {required Widget iconWidget, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: iconWidget,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontFamily: 'Tajawal', fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
