import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/ad.dart';
import '../models/saved_search.dart';
import '../models/category.dart';
import '../models/metrics.dart';
import '../models/ticker.dart';
import '../models/story.dart';
import '../models/location.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show navigatorKey;
import '../providers/auth_provider.dart';


class AuthInterceptingClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode == 401) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Provider.of<AuthProvider>(context, listen: false).logout(context);
      }
    }
    return response;
  }
}

final _client = AuthInterceptingClient();

class ApiService {
  static String get searchApiUrl {
    return 'https://api-search.sooq-com.com';
  }
  static String get baseUrl {
    return 'https://api.sooq-com.com/api';
  }

  /// Check if an icon_name represents an image (URL, path, or data URI).
  static bool isImageIcon(String? iconName) {
    if (iconName == null || iconName.isEmpty) return false;
    return iconName.startsWith('http') || iconName.startsWith('/') || iconName.startsWith('data:');
  }

  /// Resolve an icon_name to a full URL or data URI.
  static String? resolveIconUrl(String? iconName) {
    if (iconName == null || iconName.isEmpty) return null;
    if (iconName.startsWith('http')) return iconName;
    if (iconName.startsWith('data:')) return iconName;
    if (iconName.startsWith('/')) {
      final serverRoot = baseUrl.replaceAll('/api', '');
      return '$serverRoot$iconName';
    }
    return null; // It's a material icon name, not a URL
  }

  /// Build an Image widget from a resolved icon URL or data URI.
  static Widget buildIconImage(String resolvedUrl, {double width = 40, double height = 40, BoxFit fit = BoxFit.cover, Widget? fallback}) {
    if (resolvedUrl.startsWith('data:')) {
      try {
        // Extract base64 data after the comma
        final base64Str = resolvedUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => fallback ?? const SizedBox(),
        );
      } catch (_) {
        return fallback ?? const SizedBox();
      }
    }
    final bool isNgrokUrl = resolvedUrl.contains('ngrok');
    
    return Image.network(
      resolvedUrl,
      headers: isNgrokUrl ? _tunnelHeaders : null,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback ?? const SizedBox(),
    );
  }

  /// Headers needed for any image/network request going through ngrok tunnel
  static const Map<String, String> _tunnelHeaders = {
    'ngrok-skip-browser-warning': 'true',
    'Bypass-Tunnel-Reminder': 'true',
  };

  /// Universal image widget that automatically adds tunnel headers.
  /// Use this EVERYWHERE instead of Image.network() directly.
  static Widget networkImage(String url, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? errorWidget,
  }) {
    if (url.startsWith('file://')) {
      return Image.file(
        File(url.replaceFirst('file://', '')),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => errorWidget ?? Container(
          color: const Color(0xFFF5F5F5),
          child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
        ),
      );
    }

    String finalUrl = url;
    if (url.startsWith('/')) {
      finalUrl = '${baseUrl.replaceAll('/api', '')}$url';
    } else if (!url.startsWith('http') && !url.isEmpty) {
      finalUrl = '${baseUrl.replaceAll('/api', '')}/$url';
    }
    
    // Only apply Ngrok bypass headers if the URL is actually an Ngrok URL
    final bool isNgrokUrl = finalUrl.contains('ngrok');
    
    return CachedNetworkImage(
      imageUrl: finalUrl,
      httpHeaders: isNgrokUrl ? _tunnelHeaders : null,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) => Container(
        color: const Color(0xFFF3F4F9),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => errorWidget ?? Container(
        color: const Color(0xFFF5F5F5),
        child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
      ),
    );
  }

  static const Map<String, String> _defaultHeaders = {
    'Bypass-Tunnel-Reminder': 'true',
    'ngrok-skip-browser-warning': 'true',
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  // Helper to get headers with Auth token dynamically appended
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    
    final headers = Map<String, String>.from(_defaultHeaders);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  //---------------------------------------------------------
  // Authentication Endpoints
  //---------------------------------------------------------
  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: await _getHeaders(),
      body: jsonEncode({'id_token': idToken}),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data;
    } else {
      throw Exception(json.decode(response.body)['detail'] ?? 'Google Login failed');
    }
  }

  Future<Map<String, dynamic>> loginWithFacebook(String accessToken) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/facebook'),
      headers: await _getHeaders(),
      body: jsonEncode({'access_token': accessToken}),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data;
    } else {
      throw Exception(json.decode(response.body)['detail'] ?? 'Facebook Login failed');
    }
  }

  Future<Map<String, dynamic>> loginWithApple(String idToken, {String? email, String? firstName, String? lastName}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/apple'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'id_token': idToken,
        if (email != null) 'email': email,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
      }),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data;
    } else {
      throw Exception(json.decode(response.body)['detail'] ?? 'Apple Login failed');
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/users/me/profile'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to update profile');
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/users/me/profile'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load user profile');
    }
  }

  //---------------------------------------------------------
  // Existing Endpoints
  //---------------------------------------------------------
  Future<UserMetrics> fetchDashboardMetrics() async {
    final response = await _client.get(Uri.parse('$baseUrl/dashboard/metrics'), headers: await _getHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return UserMetrics.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load metrics');
    }
  }

  Future<List<Category>> fetchCategories({String? parentId, List<String>? locations}) async {
    String url = '$baseUrl/categories';
    List<String> queryParams = [];
    if (parentId != null) queryParams.add('parent_id=$parentId');
    if (locations != null && locations.isNotEmpty) {
      for (var loc in locations) {
        if (loc.isNotEmpty) {
          queryParams.add('location=${Uri.encodeComponent(loc)}');
        }
      }
    }
    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }
    final response = await _client.get(Uri.parse(url), headers: await _getHeaders()).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse.map((cat) => Category.fromJson(cat)).toList();
    } else {
      throw Exception('Failed to load categories (status: ${response.statusCode})');
    }
  }

  Future<List<City>> fetchLocations() async {
    final response = await _client.get(Uri.parse('$baseUrl/locations'), headers: await _getHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse.map((city) => City.fromJson(city)).toList();
    } else {
      throw Exception('Failed to load locations');
    }
  }

  Future<List<Map<String, dynamic>>> fetchDirectorates(int governorateId) async {
    final response = await _client.get(Uri.parse('$baseUrl/locations/directorates/$governorateId'), headers: await _getHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return (json.decode(utf8.decode(response.bodyBytes)) as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchVillages(int directorateId) async {
    final response = await _client.get(Uri.parse('$baseUrl/locations/villages/$directorateId'), headers: await _getHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return (json.decode(utf8.decode(response.bodyBytes)) as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchBasins(int villageId) async {
    final response = await _client.get(Uri.parse('$baseUrl/locations/basins/$villageId'), headers: await _getHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return (json.decode(utf8.decode(response.bodyBytes)) as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchNeighborhoods(int basinId) async {
    final response = await _client.get(Uri.parse('$baseUrl/locations/neighborhoods/$basinId'), headers: await _getHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return (json.decode(utf8.decode(response.bodyBytes)) as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<LiveTicker>> fetchTicker() async {
    final response = await _client.get(Uri.parse('$baseUrl/ticker'), headers: await _getHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((tick) => LiveTicker.fromJson(tick)).toList();
    } else {
      throw Exception('Failed to load ticker');
    }
  }

  Future<List<Map<String, dynamic>>> getTrendingSearches() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/search/trending'), headers: await _getHeaders()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(utf8.decode(response.bodyBytes)));
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> searchAutocomplete(String query) async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/search/autocomplete?q=${Uri.encodeComponent(query)}'), headers: await _getHeaders()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error searching autocomplete: $e');
    }
    return {'categories': [], 'suggestions': []};
  }

  Future<Category> fetchCategoryById(int id) async {
    final response = await _client.get(Uri.parse('$baseUrl/categories/$id'), headers: await _getHeaders());
    if (response.statusCode == 200) {
      return Category.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Failed to load category');
    }
  }

  static final Set<int> _deletedAdIds = {};

  Future<List<Ad>> fetchAds({
    String? section, 
    int? categoryId, 
    String? userId,
    List<String>? tags, 
    String? search,
    String? sortBy,
    double? minPrice,
    double? maxPrice,
    List<String>? locations,
    bool? isHot,
    double? userLat,
    double? userLng,
    int skip = 0, 
    int limit = 20
  }) async {
    String url = '$baseUrl/ads';
    List<String> queryParams = [];
    if (search != null && search.isNotEmpty) queryParams.add('search=${Uri.encodeComponent(search)}');
    if (section != null) queryParams.add('section=${Uri.encodeComponent(section)}');
    if (categoryId != null && categoryId > 0) queryParams.add('category_id=$categoryId');
    if (userId != null && userId.isNotEmpty) queryParams.add('user_id=$userId');
    if (sortBy != null) queryParams.add('sort_by=$sortBy');
    if (minPrice != null) queryParams.add('min_price=$minPrice');
    if (maxPrice != null) queryParams.add('max_price=$maxPrice');
    if (locations != null && locations.isNotEmpty) {
      for (var loc in locations) {
        if (loc.isNotEmpty) {
          queryParams.add('location=${Uri.encodeComponent(loc)}');
        }
      }
    }
    if (isHot != null) queryParams.add('is_hot=$isHot');
    if (userLat != null) queryParams.add('user_lat=$userLat');
    if (userLng != null) queryParams.add('user_lng=$userLng');

    if (tags != null && tags.isNotEmpty) {
      for (var t in tags) {
        queryParams.add('tags=${Uri.encodeComponent(t)}');
      }
    }
    
    queryParams.add('skip=$skip');
    queryParams.add('limit=$limit');

    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final response = await _client.get(Uri.parse(url), headers: await _getHeaders()).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      var ads = jsonResponse.map((ad) => Ad.fromJson(ad)).toList();
      ads.removeWhere((ad) => _deletedAdIds.contains(ad.id));
      return ads;
    } else {
      throw Exception('Failed to load ads');
    }
  }

  Future<Ad> fetchAdById(int id) async {
    final response = await _client.get(Uri.parse('$baseUrl/ads/$id'), headers: await _getHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return Ad.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load ad details');
    }
  }

  Future<int> fetchAdsCount({
    String? section, 
    int? categoryId, 
    String? userId,
    List<String>? tags,
    String? search,
    double? minPrice,
    double? maxPrice,
    List<String>? locations,
    bool? isHot
  }) async {
    String url = '$baseUrl/ads/count';
    List<String> queryParams = [];
    if (search != null && search.isNotEmpty) queryParams.add('search=${Uri.encodeComponent(search)}');
    if (section != null) queryParams.add('section=${Uri.encodeComponent(section)}');
    if (categoryId != null && categoryId > 0) queryParams.add('category_id=$categoryId');
    if (userId != null && userId.isNotEmpty) queryParams.add('user_id=$userId');
    if (minPrice != null) queryParams.add('min_price=$minPrice');
    if (maxPrice != null) queryParams.add('max_price=$maxPrice');
    if (locations != null && locations.isNotEmpty) {
      for (var loc in locations) {
        if (loc.isNotEmpty) {
          queryParams.add('location=${Uri.encodeComponent(loc)}');
        }
      }
    }
    if (isHot != null) queryParams.add('is_hot=$isHot');

    if (tags != null && tags.isNotEmpty) {
      for (var t in tags) {
        queryParams.add('tags=${Uri.encodeComponent(t)}');
      }
    }

    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final response = await _client.get(Uri.parse(url), headers: await _getHeaders()).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return json.decode(response.body)['total_count'] as int;
    } else {
      return 0; // Fallback
    }
  }

  Future<List<Story>> fetchStories() async {
    final response = await _client.get(Uri.parse('$baseUrl/stories'), headers: await _getHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((story) => Story.fromJson(story)).toList();
    } else {
      throw Exception('Failed to load stories');
    }
  }

  //---------------------------------------------------------
  // Ad Publishing Endpoints
  //---------------------------------------------------------
  
  Future<List<String>> checkWatermarks(List<XFile> files, {Function(int current, int total)? onProgress}) async {
    if (files.isEmpty) return [];
    
    int processed = 0;
    List<String> failedPaths = [];
    
    for (var file in files) {
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/media/check-watermarks'),
        );
        
        final headers = await _getHeaders();
        headers.remove('Content-Type'); 
        request.headers.addAll(headers);
        
        request.files.add(await http.MultipartFile.fromPath('files', file.path));
        
        final response = await _client.send(request);
        if (response.statusCode == 400) {
          failedPaths.add(file.path);
        } else if (response.statusCode != 200) {
          throw Exception('حدث خطأ أثناء فحص الصورة');
        }
        
        processed++;
        if (onProgress != null) {
          onProgress(processed, files.length);
        }
      } catch (e) {
        rethrow;
      }
    }
    
    return failedPaths;
  }
  
  Future<List<String>> uploadMedia(List<XFile> files, {bool bypassWatermark = false}) async {
    if (files.isEmpty) return [];

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/media/upload${bypassWatermark ? '?bypass_watermark=true' : ''}'),
      );
      
      final headers = await _getHeaders();
      headers.remove('Content-Type'); 
      request.headers.addAll(headers);
      
      for (var file in files) {
        request.files.add(await http.MultipartFile.fromPath('files', file.path));
      }

      final response = await _client.send(request).timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = json.decode(respStr) as Map<String, dynamic>;
        return (data['urls'] as List).cast<String>();
      } else {
        throw Exception('Failed to upload media: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error uploading media: $e');
      throw Exception('Failed to upload media files.');
    }
  }

  Future<Ad> createDraft(Map<String, dynamic> adData) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/ads/draft'),
      headers: await _getHeaders(),
      body: jsonEncode(adData),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Ad.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Failed to create draft: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Ad> updateDraft(int adId, Map<String, dynamic> adData) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/ads/$adId/draft'),
      headers: await _getHeaders(),
      body: jsonEncode(adData),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return Ad.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Failed to update draft: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Ad> publishAd(Map<String, dynamic> adData, List<XFile>? images, XFile? reelVideo) async {
    try {
      if (images != null && images.isNotEmpty) {
        final imageUploads = await uploadMedia(images);
        if (imageUploads.isNotEmpty) {
           adData['image_url'] = imageUploads.first;
           adData['image_urls'] = imageUploads; 
        }
      }

      if (reelVideo != null) {
        final videoUploads = await uploadMedia([reelVideo]);
        if (videoUploads.isNotEmpty) {
           adData['video_url'] = videoUploads.first;
        }
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/ads'),
        headers: await _getHeaders(),
        body: jsonEncode(adData),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return Ad.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to publish ad: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error publishing ad: $e');
      throw Exception('Failed to contact server while publishing ad.');
    }
  }
  Future<Ad> updateAd(int adId, Map<String, dynamic> adData, List<XFile>? images, XFile? reelVideo) async {
    try {
      List<String> uploadedUrls = List<String>.from(adData['image_urls'] ?? []);
      
      if (images != null && images.isNotEmpty) {
        final newUrls = await uploadMedia(images);
        if (newUrls.isNotEmpty) {
           uploadedUrls.addAll(newUrls);
        }
      }
      
      adData['image_urls'] = uploadedUrls;
      if (uploadedUrls.isNotEmpty) {
        adData['image_url'] = uploadedUrls.first;
      }

      if (reelVideo != null) {
        final videoUploads = await uploadMedia([reelVideo]);
        if (videoUploads.isNotEmpty) {
           adData['video_url'] = videoUploads.first;
        }
      }

      final response = await _client.put(
        Uri.parse('$baseUrl/ads/$adId'),
        headers: await _getHeaders(),
        body: jsonEncode(adData),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return Ad.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update ad: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error updating ad: $e');
      throw Exception('Failed to contact server while updating ad.');
    }
  }

  //---------------------------------------------------------
  // My Ads Dashboard Endpoints
  //---------------------------------------------------------
  Future<Map<String, dynamic>> fetchMyAdsDashboard() async {
    final response = await _client.get(Uri.parse('$baseUrl/my-ads/dashboard'), headers: await _getHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to load my ads dashboard');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyAds({String status = 'All', String? search}) async {
    String url = '$baseUrl/my-ads?status=$status';
    if (search != null && search.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(search)}';
    }
    final response = await _client.get(Uri.parse(url), headers: await _getHeaders()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return (json.decode(utf8.decode(response.bodyBytes)) as List).cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load my ads');
    }
  }

  Future<void> performMyAdsBulkAction(List<int> adIds, String action) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/my-ads/bulk-action'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'ad_ids': adIds,
        'action': action,
      }),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Failed to perform bulk action');
    }
    
    if (action == 'delete') {
      _deletedAdIds.addAll(adIds);
    }
  }

  Future<Ad> republishAd(int adId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/ads/$adId/republish'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return Ad.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    } else {
      String errorMessage = 'Failed to republish ad';
      try {
        final error = json.decode(response.body);
        if (error['detail'] != null) {
          errorMessage = error['detail'];
        }
      } catch (_) {
        // Ignored, use default
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> recordAdView(int adId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/ads/$adId/interaction/view'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('Failed to record ad view on backend');
      }
    } catch (_) {
      // Fail silently for passive tracking
    }
  }

  Future<void> recordAdInteractionPhone(int adId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/ads/$adId/interaction/phone'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('Failed to record phone interaction on backend');
      }
    } catch (_) {
      // Fail silently for passive tracking
    }
  }

  Future<void> recordAdInteractionChat(int adId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/ads/$adId/interaction/chat'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('Failed to record chat interaction on backend');
      }
    } catch (_) {
      // Fail silently for passive tracking
    }
  }

  Future<List<Ad>> fetchRecentlyViewedAds() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/my-ads/recently-viewed'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        return jsonResponse.map((ad) => Ad.fromJson(ad)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching recently viewed ads from backend: $e');
    }
    return [];
  }

  //---------------------------------------------------------
  // Notification Endpoints
  //---------------------------------------------------------

  Future<void> registerDeviceToken(String fcmToken, {String? deviceType}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/notifications/device-token'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'fcm_token': fcmToken,
        'device_type': deviceType ?? 'android',
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to register device token');
    }
  }

  Future<void> updateLatestCategory(int categoryId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/users/me/latest-category'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'category_id': categoryId,
        }),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('Failed to update latest category');
      }
    } catch (_) {
      // Fail silently for passive tracking
    }
  }

  Future<void> saveCategoryFilters(int categoryId, double? minPrice, double? maxPrice, List<String> tags) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/users/me/category-filters/$categoryId'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'min_price': minPrice,
          'max_price': maxPrice,
          'tags': tags,
        }),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('Failed to save category filters');
      }
    } catch (_) {
      // Fail silently
    }
  }

  Future<Map<String, dynamic>?> getCategoryFilters(int categoryId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/users/me/category-filters/$categoryId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data.isEmpty) return null;
        return data;
      }
    } catch (_) {
      // Fail silently
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchNotifications({int skip = 0, int limit = 50}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/notifications/?skip=$skip&limit=$limit'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  Future<int> fetchUnreadCount() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/notifications/unread-count'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['unread_count'] as int;
    }
    return 0;
  }

  Future<void> markNotificationRead(int notificationId) async {
    await _client.put(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: await _getHeaders(),
    );
  }

  Future<void> markAllNotificationsRead() async {
    await _client.put(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: await _getHeaders(),
    );
  }

  //---------------------------------------------------------
  // Saved Ads (Wishlist)
  //---------------------------------------------------------
  Future<bool> toggleSaveAd(int adId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/ads/$adId/save'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['is_saved'] as bool;
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to toggle save ad: ${response.statusCode}');
    }
  }

  Future<List<Ad>> fetchSavedAds() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/users/me/saved-ads'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Ad.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load saved ads');
    }
  }

  Future<void> deleteAccount() async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/auth/account'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete account: ${response.statusCode}');
    }
  }

  Future<void> reportAd(int adId, String reason, {String? comments}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/ads/$adId/report'),
      headers: await _getHeaders(),
      body: json.encode({
        'reason': reason,
        if (comments != null && comments.isNotEmpty) 'comments': comments,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to report ad: ${response.statusCode}');
    }
  }

  //---------------------------------------------------------
  // Tracking
  //---------------------------------------------------------
  Future<void> logUserActivity(String actionType, {int? categoryId, Map<String, dynamic>? filters}) async {
    try {
      await _client.post(
        Uri.parse('$baseUrl/tracking/log_event'),
        headers: await _getHeaders(),
        body: json.encode({
          'action_type': actionType,
          if (categoryId != null) 'category_id': categoryId,
          if (filters != null) 'filters_json': filters,
        }),
      );
    } catch (e) {
      debugPrint("Failed to log activity: \$e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchPersonalizedAds() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/tracking/personalized_ads'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> decodedLanes = json.decode(utf8.decode(response.bodyBytes));
        
        List<Map<String, dynamic>> results = [];
        for (var lane in decodedLanes) {
          final adsData = lane['ads'] as List;
          results.add({
            'title': lane['title'] ?? 'قد يعجبك',
            'category_id': lane['category_id'],
            'filters': lane['filters_json'],
            'ads': adsData.map((a) => Ad.fromJson(a)).toList(),
          });
        }
        return results;
      }
    } catch (e) {
      debugPrint("Failed to fetch personalized ads: \$e");
    }
    return [];
  }

  //---------------------------------------------------------
  // AI Generation Endpoints
  //---------------------------------------------------------
  
  Future<Map<String, dynamic>> generateAdSuggestions(Map<String, dynamic> adData) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/ai/generate-suggestions'),
        headers: await _getHeaders(),
        body: jsonEncode(adData),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        final suggestionsList = (decoded['suggestions'] as List).cast<Map<String, dynamic>>();
        final smartTags = (decoded['smart_tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
        
        return {
          'suggestions': suggestionsList.map((dynamic item) => {
            'title': item['title']?.toString() ?? '',
            'description': item['description']?.toString() ?? '',
          }).toList(),
          'smart_tags': smartTags,
        };
      } else {
        throw Exception('Failed to generate suggestions: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error calling generateAdSuggestions: $e');
      throw Exception('Failed to contact AI generation service.');
    }
  }

  Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/ai/analyze-image'),
      );
      
      final headers = await _getHeaders();
      headers.remove('Content-Type'); // Important: Let MultipartRequest set its own multipart form boundary Content-Type
      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));

      final response = await _client.send(request);
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        return json.decode(respStr) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to analyze image: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error calling analyzeImage: $e');
      // Graceful fallback
      return {'category_name': null, 'image_quality': 'good'};
    }
  }

  Future<List<String>> fetchLocationIntelligence(String city, String region) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'city': city,
        'region': region,
      });

      final response = await _client.post(
        Uri.parse('$baseUrl/ai/location-intelligence'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final landmarks = data['landmarks'] as List<dynamic>?;
        return landmarks?.map((e) => e.toString()).toList() ?? [];
      } else {
        throw Exception('Failed to fetch location intelligence: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error calling fetchLocationIntelligence: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchPriceEstimate(int categoryId, String city, String region) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'category_id': categoryId,
        'city': city,
        'region': region,
      });

      final response = await _client.post(
        Uri.parse('$baseUrl/ai/price-estimate'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch price estimate: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error calling fetchPriceEstimate: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchAdEvaluation(Map<String, dynamic> adData) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/ai/evaluate-ad'),
        headers: await _getHeaders(),
        body: jsonEncode(adData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return {
          'score': decoded['score'] ?? 75,
          'tips': (decoded['tips'] as List?)?.map((e) => e.toString()).toList() ?? [],
        };
      } else {
        throw Exception('Failed to evaluate ad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error calling fetchAdEvaluation: $e');
      return {'score': 75, 'tips': ['تأكد من مراجعة التفاصيل قبل النشر']};
    }
  }

  Future<void> sendChatAlert({
    required int targetUserId,
    required String senderName,
    required String messagePreview,
    required String adId,
    required String adTitle,
    required String chatId,
    required String messageId,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/notifications/chat-alert'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'target_user_id': targetUserId,
          'sender_name': senderName,
          'message_preview': messagePreview,
          'ad_id': adId,
          'ad_title': adTitle,
          'chat_id': chatId,
          'message_id': messageId,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to send chat alert: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error calling sendChatAlert: $e');
    }
  }

  Future<List<SavedSearch>> fetchSavedSearches() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/saved_filters'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => SavedSearch.fromMap(json)).toList();
    } else if (response.statusCode == 401) {
      return [];
    } else {
      throw Exception('Failed to fetch saved searches: ${response.statusCode}');
    }
  }

  Future<SavedSearch> createSavedSearch(SavedSearch search) async {
    final payload = {
      'category_id': search.categoryId,
      'name': search.categoryName,
      'search_query': search.searchQuery,
      'min_price': search.minPrice,
      'max_price': search.maxPrice,
      'tags': search.tags,
      'locations': search.locations,
      'alert_frequency': search.alertType == 'instant' ? 'فوري' : search.alertType,
      'is_active': true
    };

    final response = await _client.post(
      Uri.parse('$baseUrl/saved_filters'),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return SavedSearch.fromMap(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create saved search: ${response.statusCode}');
    }
  }

  Future<void> deleteSavedSearch(String searchId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/saved_filters/$searchId'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete saved search: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> fetchAppVersionInfo() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/config/version'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch version info: ${response.statusCode}');
    }
  }
}

