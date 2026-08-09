import 'dart:convert';
import '../services/api_service.dart';

class Ad {
  final int id;
  final String title;
  final String description;
  final double price;
  final String location;
  final String? phoneNumber;
  final String? imageUrl;
  final String? videoUrl;
  final List<String> images; // Array of image URLs natively 
  final int views;
  final int favoritesCount;
  final bool isHot;
  final List<String> tags;
  final int? categoryId;
  final DateTime? createdAt;
  final String? sourceType;
  final SharedRoomDetails? sharedRoomDetails;
  final Map<String, dynamic>? attributes;
  final String? ownerName;
  final String? ownerType;
  final int? userId;
  bool isSaved;
  final DateTime? lastRepublishedAt;

  Ad({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    this.phoneNumber,
    this.imageUrl,
    this.videoUrl,
    this.images = const [],
    this.views = 0,
    this.favoritesCount = 0,
    this.isHot = false,
    this.tags = const [],
    this.categoryId,
    this.createdAt,
    this.sourceType,
    this.sharedRoomDetails,
    this.attributes,
    this.ownerName,
    this.ownerType,
    this.userId,
    this.isSaved = false,
    this.lastRepublishedAt,
  });

  factory Ad.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];
    if (json['linked_tags'] != null) {
      parsedTags = (json['linked_tags'] as List).map((t) => t['name'].toString()).toList();
    }
    
    List<String> parsedImages = [];
    if (json['image_urls'] != null && json['image_urls'] is List && (json['image_urls'] as List).isNotEmpty) {
      parsedImages = (json['image_urls'] as List).map((e) => e.toString()).toList();
    } else if (json['attributes'] != null && json['attributes']['image_urls'] != null && json['attributes']['image_urls'] is List && (json['attributes']['image_urls'] as List).isNotEmpty) {
      parsedImages = (json['attributes']['image_urls'] as List).map((e) => e.toString()).toList();
    } else {
      String? mainImageUrl = json['image_url'];
      if (mainImageUrl != null && mainImageUrl.isNotEmpty) {
        if (mainImageUrl.startsWith('[')) {
          // Handle JSON array from the backend
          try {
            final decoded = jsonDecode(mainImageUrl);
            if (decoded is List) {
              parsedImages = decoded.map((e) => e.toString()).toList();
            }
          } catch (_) {
            // Fallback parsing if JSON decode fails
            parsedImages = mainImageUrl
                .replaceAll('[', '')
                .replaceAll(']', '')
                .replaceAll('"', '')
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        } else if (mainImageUrl.contains(',')) {
          // Handle legacy comma separated
          parsedImages = mainImageUrl
              .split(',')
              .map((url) => url.trim())
              .where((url) => url.isNotEmpty)
              .toList();
        } else {
          parsedImages = [mainImageUrl];
        }
      }
    }

    // Resolve relative image URLs to absolute URLs
    final serverRoot = ApiService.baseUrl.replaceAll('/api', '');
    parsedImages = parsedImages.map((url) {
      if (url.startsWith('/')) {
        return '$serverRoot$url';
      }
      return url;
    }).toList();

    String? extractFirstPhone(String? raw) {
      if (raw == null || raw.trim().isEmpty) return null;
      
      String formatLocal(String phone) {
        if (phone.startsWith('+962')) return '0${phone.substring(4)}';
        if (phone.startsWith('00962')) return '0${phone.substring(5)}';
        if (phone.length >= 11 && phone.startsWith('962')) return '0${phone.substring(3)}';
        if (phone.length == 9 && phone.startsWith('7')) return '0$phone';
        return phone;
      }

      // Approach 1: Extremely accurate Jordanian mobile regex (handles spaces & dashes between digits)
      final match = RegExp(r'(?:(?:\+|00)?962|0)?7[789](?:[\s\-]*\d){7}').firstMatch(raw);
      if (match != null) {
         final clean = match.group(0)!.replaceAll(RegExp(r'[^\d\+]'), '');
         return formatLocal(clean);
      }
      
      // Approach 2: Fallback for Landlines or other formats
      final parts = raw.split(RegExp(r'[\/\,\\|\n\-&]|\b(و|أو|or|and)\b'));
      for (var p in parts) {
        final clean = p.replaceAll(RegExp(r'[^\d\+]'), '');
        if (clean.length >= 9 && clean.length <= 15) {
          return formatLocal(clean);
        }
      }
      
      return raw; // Ultimate fallback
    }

    return Ad(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? 'بدون عنوان',
      description: json['description']?.toString() ?? '',
      phoneNumber: extractFirstPhone(
        json['phone_number']?.toString() ?? 
        (json['attributes'] != null && json['attributes'] is Map ? json['attributes']['phone_number']?.toString() : null)
      ),
      price: json['price'] != null ? (double.tryParse(json['price'].toString()) ?? 0.0) : 0.0,
      location: json['location']?.toString() ?? 'غير محدد',
      imageUrl: parsedImages.isNotEmpty ? parsedImages.first : null,
      videoUrl: json['video_url']?.toString() ?? (json['attributes'] != null && json['attributes']['video_url'] != null ? json['attributes']['video_url'].toString() : null),
      images: parsedImages,
      views: json['views'] != null ? (int.tryParse(json['views'].toString()) ?? 0) : 0,
      favoritesCount: json['favorites_count'] != null ? (int.tryParse(json['favorites_count'].toString()) ?? 0) : 0,
      isHot: json['is_hot'] == true || json['is_hot'] == 'true' || json['is_hot'] == 1,
      tags: parsedTags,
      categoryId: json['category_id'] != null ? (int.tryParse(json['category_id'].toString()) ?? 0) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      sourceType: json['source_type']?.toString(),
      sharedRoomDetails: json['attributes'] != null ? SharedRoomDetails.fromJson(json['attributes']) : null,
      attributes: json['attributes'] is Map<String, dynamic> ? json['attributes'] : null,
      ownerName: () {
        if (json['attributes'] != null && json['attributes']['author'] != null && json['attributes']['author'].toString().trim().isNotEmpty) {
          return json['attributes']['author'].toString().trim();
        }
        if (json['owner'] == null) return null;
        String? name = json['owner']['full_name'];
        if (name == null || name.trim().isEmpty) {
          name = json['owner']['username'];
        }
        if (name != null && name == 'ai_scraper') {
          return 'User-${json['user_id'] ?? ''}';
        }
        if (name == null || name.trim().isEmpty) {
          return 'User-${json['user_id'] ?? ''}';
        }
        if (name.toLowerCase().startsWith('user-')) {
          return 'User-${name.substring(5)}';
        }
        return name;
      }(),
      ownerType: json['owner'] != null ? json['owner']['user_type']?.toString() : null,
      userId: json['user_id'] != null ? (int.tryParse(json['user_id'].toString()) ?? 0) : null,
      isSaved: json['is_saved'] == true || json['is_saved'] == 'true' || json['is_saved'] == 1,
      lastRepublishedAt: json['last_republished_at'] != null ? DateTime.tryParse(json['last_republished_at'].toString()) : null,
    );
  }
  String get displayLocation {
    final city = attributes?['city']?.toString();
    final region = attributes?['region']?.toString();
    if (city != null && city.isNotEmpty && region != null && region.isNotEmpty) {
      return '$region، $city';
    } else if (region != null && region.isNotEmpty) {
      return region;
    } else {
      return location;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'location': location,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'image_urls': images,
      'views': views,
      'favorites_count': favoritesCount,
      'is_hot': isHot,
      'linked_tags': tags.map((t) => {'name': t}).toList(),
      'category_id': categoryId,
      'created_at': createdAt?.toIso8601String(),
      'attributes': attributes,
    };
  }
}

class SharedRoomDetails {
  final int? rooms;
  final int? bathrooms;
  final String? furnished;
  final String? floor;
  final List<String> keyFeatures;
  
  // 1. Basic Info
  final String? roomType;
  final List<String> targetAudience;
  final String? roomCapacity;
  final int? currentOccupants;
  final String? rentDuration;
  
  // 2. Cost & Bills
  final List<String> rentIncludes;
  final String? paymentFrequency;
  final bool? insuranceRequired;
  
  // 3. Room Specs
  final String? bathroomType;
  final List<String> roomContents;
  final List<String> roomFeatures;
  
  // 4. Shared Spaces
  final List<String> sharedSpaces;
  final List<String> kitchenAppliances;
  final List<String> laundryAppliances;
  
  // 5. House Rules
  final String? smokingRules;
  final String? quietnessRules;
  final String? guestsRules;
  final String? petsRules;
  final String? cleaningRules;
  
  // 6. Building Specs
  final String? buildingAge;
  final List<String> buildingFeatures;
  
  // 7. Locations
  final List<String> nearbyPlaces;

  SharedRoomDetails({
    this.rooms,
    this.bathrooms,
    this.furnished,
    this.floor,
    this.keyFeatures = const [],
    this.roomType,
    this.targetAudience = const [],
    this.roomCapacity,
    this.currentOccupants,
    this.rentDuration,
    this.rentIncludes = const [],
    this.paymentFrequency,
    this.insuranceRequired,
    this.bathroomType,
    this.roomContents = const [],
    this.roomFeatures = const [],
    this.sharedSpaces = const [],
    this.kitchenAppliances = const [],
    this.laundryAppliances = const [],
    this.smokingRules,
    this.quietnessRules,
    this.guestsRules,
    this.petsRules,
    this.cleaningRules,
    this.buildingAge,
    this.buildingFeatures = const [],
    this.nearbyPlaces = const [],
  });

  factory SharedRoomDetails.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String) {
        if (val.trim().startsWith('[') && val.trim().endsWith(']')) {
           try {
             final List dynList = jsonDecode(val.trim());
             return dynList.map((e) => e.toString()).toList();
           } catch (_) {}
        }
        return val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [val.toString()];
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is String) {
        final match = RegExp(r'\d+').firstMatch(val);
        if (match != null) return int.tryParse(match.group(0)!);
      }
      if (val is double) return val.toInt();
      return null;
    }

    bool? parseBool(dynamic val) {
      if (val == null) return null;
      if (val is bool) return val;
      if (val is String) {
        final lower = val.toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'yes' || lower == 'نعم';
      }
      if (val is num) return val > 0;
      return null;
    }

    String? parseString(dynamic val) {
      if (val == null) return null;
      return val.toString();
    }

    return SharedRoomDetails(
      rooms: parseInt(json['rooms']),
      bathrooms: parseInt(json['bathrooms']),
      furnished: parseString(json['furnished']),
      floor: parseString(json['floor']),
      keyFeatures: parseStringList(json['key_features']),
      roomType: parseString(json['room_type']),
      targetAudience: parseStringList(json['target_audience']),
      roomCapacity: parseString(json['room_capacity']),
      currentOccupants: parseInt(json['current_occupants']),
      rentDuration: parseString(json['rent_duration']),
      rentIncludes: parseStringList(json['rent_includes']),
      paymentFrequency: parseString(json['payment_frequency']),
      insuranceRequired: parseBool(json['insurance_required']),
      bathroomType: parseString(json['bathroom_type']),
      roomContents: parseStringList(json['room_contents']),
      roomFeatures: parseStringList(json['room_features']),
      sharedSpaces: parseStringList(json['shared_spaces']),
      kitchenAppliances: parseStringList(json['kitchen_appliances']),
      laundryAppliances: parseStringList(json['laundry_appliances']),
      smokingRules: parseString(json['smoking_rules']),
      quietnessRules: parseString(json['quietness_rules']),
      guestsRules: parseString(json['guests_rules']),
      petsRules: parseString(json['pets_rules']),
      cleaningRules: parseString(json['cleaning_rules']),
      buildingAge: parseString(json['building_age']),
      buildingFeatures: parseStringList(json['building_features']),
      nearbyPlaces: parseStringList(json['nearby_places']),
    );
  }
}
