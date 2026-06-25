import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:share_plus/share_plus.dart';

class ShareHelper {
  static Future<void> shareAdWithImage(String adTitle, String adId, String? imageUrl) async {
    final String shareUrl = 'https://share.sooq-com.com/ad/$adId';
    final String text = '$adTitle\nشاهد هذا الاعلان على سوقكم\n$shareUrl';

    if (imageUrl == null || imageUrl.isEmpty) {
      Share.share(text);
      return;
    }

    try {
      // Use cache manager to instantly get the image that's already loaded on screen
      final file = await DefaultCacheManager().getSingleFile(imageUrl);
      await Share.shareXFiles([XFile(file.path)], text: text);
    } catch (e) {
      print('Error getting image for share: $e');
      Share.share(text);
    }
  }
}
