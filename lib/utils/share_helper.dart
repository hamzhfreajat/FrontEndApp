import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareHelper {
  static Future<void> shareAdWithImage(String adTitle, String adId, String? imageUrl) async {
    final String shareUrl = 'https://sooq-com.com/ad/$adId';
    final String text = '$adTitle\nشاهد هذا الاعلان على سوقكم\n$shareUrl';

    if (imageUrl == null || imageUrl.isEmpty) {
      Share.share(text);
      return;
    }

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/shared_ad_image.png');
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles([XFile(file.path)], text: text);
      } else {
        Share.share(text);
      }
    } catch (e) {
      print('Error downloading image for share: $e');
      Share.share(text);
    }
  }
}
