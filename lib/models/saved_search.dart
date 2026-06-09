import 'dart:convert';

class SavedSearch {
  final String id;
  final int categoryId;
  final String categoryName;
  final String? searchQuery;
  final double? minPrice;
  final double? maxPrice;
  final List<String> locations;
  final List<String> tags;
  final String alertType; // 'instant', 'daily'
  final DateTime createdAt;

  SavedSearch({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    this.searchQuery,
    this.minPrice,
    this.maxPrice,
    required this.locations,
    required this.tags,
    required this.alertType,
    required this.createdAt,
  });

  SavedSearch copyWith({
    String? id,
    int? categoryId,
    String? categoryName,
    String? searchQuery,
    double? minPrice,
    double? maxPrice,
    List<String>? locations,
    List<String>? tags,
    String? alertType,
    DateTime? createdAt,
    bool clearSearchQuery = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return SavedSearch(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      locations: locations ?? List.from(this.locations),
      tags: tags ?? List.from(this.tags),
      alertType: alertType ?? this.alertType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'searchQuery': searchQuery,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'locations': locations,
      'tags': tags,
      'alertType': alertType,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavedSearch.fromMap(Map<String, dynamic> map) {
    return SavedSearch(
      id: map['id']?.toString() ?? '',
      categoryId: (map['category_id'] ?? map['categoryId'])?.toInt() ?? 0,
      categoryName: map['name'] ?? map['categoryName'] ?? '',
      searchQuery: map['search_query'] ?? map['searchQuery'],
      minPrice: (map['min_price'] ?? map['minPrice'])?.toDouble(),
      maxPrice: (map['max_price'] ?? map['maxPrice'])?.toDouble(),
      locations: List<String>.from(map['locations'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      alertType: map['alert_frequency'] ?? map['alertType'] ?? 'instant',
      createdAt: (map['created_at'] ?? map['createdAt']) != null 
          ? DateTime.parse(map['created_at'] ?? map['createdAt']) 
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory SavedSearch.fromJson(String source) => SavedSearch.fromMap(json.decode(source));
}
