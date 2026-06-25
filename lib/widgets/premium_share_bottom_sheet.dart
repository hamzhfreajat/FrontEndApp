import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad.dart';

class PremiumShareBottomSheet extends StatelessWidget {
  final Ad? ad;
  final String? customTitle;
  final String? customUrl;
  final List<String>? previewImages;

  const PremiumShareBottomSheet({Key? key, this.ad, this.customTitle, this.customUrl, this.previewImages}) : super(key: key);

  static void show(BuildContext context, Ad ad) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PremiumShareBottomSheet(ad: ad),
    );
  }

  static void showForLink(BuildContext context, {required String title, required String url, List<String>? previewImages}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PremiumShareBottomSheet(customTitle: title, customUrl: url, previewImages: previewImages),
    );
  }

  String get _shareUrl => ad != null ? 'https://sooq-com.com/ad/${ad!.id}' : customUrl!;
  String get _shareText => ad != null 
    ? '${ad!.title}\nشاهد هذا الاعلان على سوقكم\n$_shareUrl'
    : '${customTitle!}\n$_shareUrl';

  Future<String?> _getLocalImagePath() async {
    if (ad == null || ad!.images.isEmpty) return null;
    try {
      final file = await DefaultCacheManager().getSingleFile(ad!.images.first);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _createCollage(List<String> urls) async {
    if (urls.isEmpty) return null;
    
    // Download all images
    List<File> imageFiles = [];
    for (var url in urls) {
      try {
        final file = await DefaultCacheManager().getSingleFile(url);
        imageFiles.add(file);
      } catch (e) {
        // ignore
      }
    }
    
    if (imageFiles.isEmpty) return null;
    if (imageFiles.length == 1) return imageFiles.first.path;

    try {
      // Decode images
      List<img.Image> images = [];
      for (var file in imageFiles) {
        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          images.add(decoded);
        }
      }

      if (images.isEmpty) return imageFiles.first.path;
      if (images.length == 1) return imageFiles.first.path;

      // Create a 2x2 canvas. Let's say 800x800 total (400x400 each)
      int size = 800;
      int halfSize = size ~/ 2;
      img.Image collage = img.Image(width: size, height: size);
      
      // Fill background with white
      img.fill(collage, color: img.ColorRgb8(255, 255, 255));

      for (int i = 0; i < images.length && i < 4; i++) {
        int x = (i % 2) * halfSize;
        int y = (i ~/ 2) * halfSize;
        
        // Resize and crop to fit 400x400
        img.Image resized = img.copyResizeCropSquare(images[i], size: halfSize);
        
        // Draw onto collage
        img.compositeImage(collage, resized, dstX: x, dstY: y);
      }

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/collage_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(img.encodeJpg(collage, quality: 90));
      
      return file.path;
    } catch (e) {
      // Fallback to first image on failure
      return imageFiles.first.path;
    }
  }

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _shareUrl));
    _showSnack(context, 'تم نسخ الرابط بنجاح');
    Navigator.pop(context);
  }

  void _shareLinkOnly(BuildContext context) {
    Navigator.pop(context); // Close bottom sheet
    Share.share(_shareText); // Share text only to allow Messenger/Insta to parse OG tags
  }

  void _shareDirectWhatsApp(BuildContext context) async {
    Navigator.pop(context);
    final url = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(_shareText)}");
    final webUrl = Uri.parse("https://api.whatsapp.com/send?text=${Uri.encodeComponent(_shareText)}");
    
    try {
      bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        Share.share(_shareText);
      }
    } catch (e) {
      Share.share(_shareText);
    }
  }

  void _shareDirectMessenger(BuildContext context) async {
    Navigator.pop(context);
    final url = Uri.parse("fb-messenger://share/?link=${Uri.encodeComponent(_shareUrl)}");
    
    try {
      bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        Share.share(_shareText);
      }
    } catch (e) {
      Share.share(_shareText);
    }
  }

  void _shareDirectInstagram(BuildContext context) async {
    Navigator.pop(context);
    Clipboard.setData(ClipboardData(text: _shareUrl));
    
    final url = Uri.parse("instagram://");
    final webUrl = Uri.parse("https://www.instagram.com/");
    
    try {
      bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
      if (launched) {
        if (context.mounted) _showSnack(context, 'تم نسخ الرابط! افتح المحادثة للصقه.');
      } else {
        Share.share(_shareText);
      }
    } catch (e) {
      Share.share(_shareText);
    }
  }

  void _shareNative(BuildContext context) async {
    if (previewImages != null && previewImages!.isNotEmpty) {
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    String? imagePath;
    if (previewImages != null && previewImages!.isNotEmpty) {
      imagePath = await _createCollage(previewImages!);
    } else {
      imagePath = await _getLocalImagePath();
    }

    if (previewImages != null && previewImages!.isNotEmpty) {
      Navigator.pop(context); // Close loading dialog
    }
    
    // Some apps like Messenger/Instagram ignore text when sharing an image.
    // We copy the text to clipboard so the user can easily paste it.
    Clipboard.setData(ClipboardData(text: _shareText));
    _showSnack(context, 'تم نسخ النص احتياطياً للصقه في المحادثة');
    
    Navigator.pop(context); // Close bottom sheet

    if (imagePath != null) {
      await Share.shareXFiles([XFile(imagePath, mimeType: 'image/jpeg')], text: _shareText);
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
    final imageUrl = (ad != null && ad!.images.isNotEmpty) ? ad!.images.first : null;

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
        child: SingleChildScrollView(
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
                  const Text('شارك مع الأصدقاء', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    if (previewImages != null && previewImages!.isNotEmpty && previewImages!.length > 1)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: previewImages!.length <= 2 ? 2.0 : 1.0,
                          child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            children: previewImages!.take(4).map((url) => CachedNetworkImage(
                              imageUrl: url, 
                              fit: BoxFit.cover
                            )).toList(),
                          ),
                        ),
                      )
                    else if (previewImages != null && previewImages!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(imageUrl: previewImages!.first, height: 140, width: double.infinity, fit: BoxFit.cover),
                      )
                    else if (imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(imageUrl: imageUrl, height: 140, width: double.infinity, fit: BoxFit.cover),
                      ),
                    if (imageUrl != null || (previewImages != null && previewImages!.isNotEmpty)) const SizedBox(height: 12),
                    Text(
                      ad != null ? ad!.title : customTitle!,
                      maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (ad != null) const SizedBox(height: 4),
                    if (ad != null) Text('${ad!.price.toStringAsFixed(0)} دينار', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Options List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Social Media Icons Wrap
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildSocialIconButton(
                        context,
                        iconWidget: const Icon(Icons.copy_rounded, color: Colors.blueAccent, size: 28),
                        color: Colors.blueAccent,
                        label: 'نسخ الرابط',
                        onTap: () => _copyLink(context),
                      ),
                      _buildSocialIconButton(
                        context,
                        iconWidget: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 28),
                        color: const Color(0xFF25D366),
                        label: 'واتساب',
                        onTap: () => _shareDirectWhatsApp(context),
                      ),
                      _buildSocialIconButton(
                        context,
                        iconWidget: const FaIcon(FontAwesomeIcons.instagram, color: Color(0xFFE4405F), size: 28),
                        color: const Color(0xFFE4405F),
                        label: 'انستغرام',
                        onTap: () => _shareDirectInstagram(context),
                      ),
                      _buildSocialIconButton(
                        context,
                        iconWidget: const FaIcon(FontAwesomeIcons.facebookMessenger, color: Color(0xFF00B2FF), size: 28),
                        color: const Color(0xFF00B2FF),
                        label: 'ماسنجر',
                        onTap: () => _shareDirectMessenger(context),
                      ),
                      _buildSocialIconButton(
                        context,
                        iconWidget: Icon(Icons.more_horiz_rounded, color: Colors.grey.shade600, size: 28),
                        color: Colors.grey.shade600,
                        label: 'المزيد',
                        onTap: () => _shareLinkOnly(context), // Share link only as requested
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
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

  Widget _buildSocialIconButton(BuildContext context, {required Widget iconWidget, required Color color, required String label, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: iconWidget,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
