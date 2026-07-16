import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../../../models/ad.dart';
import '../../../../services/api_service.dart'; // To access base URL

class ApiProfileRepositoryImpl implements ProfileRepository {
  
  Future<Map<String, String>> _getHeaders() async {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<UserProfile> getPublicProfile(String userId) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/users/$userId/profile');
      final response = await http.get(url, headers: await _getHeaders());

      if (response.statusCode == 200) {
        return _mapToUserProfile(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception('Failed to load profile (status: ${response.statusCode})');
      }
    } catch (e) {
      // Fallback for demo or hard backend failures.
      throw Exception('Network error while loading profile: $e');
    }
  }

  @override
  Future<UserProfile> getPrivateProfile() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/users/me/profile');
      final response = await http.get(url, headers: await _getHeaders());

      if (response.statusCode == 200) {
        return _mapToUserProfile(json.decode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 401) {
        throw Exception('الرجاء تسجيل الدخول أولاً');
      } else {
        throw Exception('Failed to load private profile (status: ${response.statusCode})');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('الرجاء تسجيل الدخول أولاً')) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  @override
  Future<List<Ad>> getUserAds(String userId, {int limit = 10, int offset = 0}) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/ads?user_id=$userId&limit=$limit&skip=$offset');
      final response = await http.get(url, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => Ad.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Review>> getUserReviews(String userId, {int limit = 10, int offset = 0}) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/users/$userId/reviews');
      final response = await http.get(url, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map<Review>((json) => Review(
          id: json['id']?.toString() ?? '',
          reviewerName: json['reviewer']?['full_name'] ?? json['reviewer']?['username'] ?? json['reviewer']?['mobile_number'] ?? 'مستخدم رقم ${json['reviewer']?['id'] ?? ""}'.trim(),
          reviewerAvatar: json['reviewer']?['avatar_url'] ?? 'https://ui-avatars.com/api/?name=User&background=random',
          rating: (json['rating'] ?? 5.0).toDouble(),
          text: json['text'] ?? '',
          date: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
        )).toList();
      } else {
        return []; // Replace with actual empty review data mapping
      }
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> followUser(String userId) async {
    // API endpoint doesn't exist yet, mock delay
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> unfollowUser(String userId) async {
    // API endpoint doesn't exist yet, mock delay
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> reportUser(String userId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> blockUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  UserProfile _mapToUserProfile(Map<String, dynamic> json) {
    // Collect specific review tags from metrics or reviews (mocked as empty for now until aggregated)
    return UserProfile(
      id: json['id'].toString(),
      name: () {
        String? n = json['full_name'];
        if (n == null || n.trim().isEmpty) n = json['username'];
        if (n == null || n.trim().isEmpty) n = json['mobile_number'];
        if (n == null || n.trim().isEmpty) return 'مستخدم رقم ${json['id']}';
        return n;
      }(),
      username: json['username'] ?? json['mobile_number'] ?? 'user_${json['id']}',
      avatar: (json['avatar_url'] != null && json['avatar_url'].toString().trim().isNotEmpty)
          ? json['avatar_url']
          : 'https://ui-avatars.com/api/?name=${json['username'] ?? "U"}&background=random',
      coverImage: (json['cover_image_url'] != null && json['cover_image_url'].toString().trim().isNotEmpty)
          ? json['cover_image_url']
          : 'https://images.unsplash.com/photo-1557683316-973673baf926?auto=format&fit=crop&q=80',
      memberSince: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now().subtract(const Duration(days: 30)),
      location: json['location']?.isNotEmpty == true ? json['location'] : 'غير محدد',
      userType: json['user_type'] ?? 'private',
      lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
      replyTimeLabel: json['average_response_time'] ?? 'عادة يرد خلال ساعة',
      overallRating: (json['overall_rating'] ?? 0.0).toDouble(),
      reviewCount: json['review_count'] ?? 0,
      responseRate: json['response_rate'] ?? 100,
      averageResponseTime: json['average_response_time'] ?? 'عادة يرد خلال ساعة',
      trustScore: json['trust_score'] ?? 50,
      isEmailVerified: json['is_email_verified'] ?? false,
      isPhoneVerified: json['is_phone_verified'] ?? true, // Phones are heavily used
      isIdentityVerified: json['is_identity_verified'] ?? false,
      businessPolicy: json['business_policy'] ?? 'سياسة المتجر العادية',
      shopLocation: json['shop_location'] ?? json['location'],
      shopHours: json['shop_hours'] ?? 'مفتوح',
      activeAdsCount: json['active_ads_count'] ?? 0,
      soldAdsCount: json['sold_ads_count'] ?? 0,
      totalAdsPosted: json['total_ads_count'] ?? 0,
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      reviewTags: (json['review_tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      phoneNumber: json['mobile_number'],
      bio: json['bio'],
      preferredContact: json['preferred_contact'],
      languagesSpoken: (json['languages_spoken'] as List?)?.map((e) => e.toString()).toList() ?? [],
      dealsCompleted: json['deals_completed'] ?? 0,
      cancellationRate: json['cancellation_rate'] ?? 0,
      buyerSatisfaction: json['buyer_satisfaction'] ?? 0,
    );
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/users/me/profile');
      final response = await http.patch(
        url, 
        headers: await _getHeaders(),
        body: json.encode(updates),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while updating profile: $e');
    }
  }
}

