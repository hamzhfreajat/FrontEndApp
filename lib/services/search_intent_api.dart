import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class SearchIntent {
  final int? categoryId;
  final String? categoryName;
  final String? location;
  final List<String> tags;
  final double confidence;
  final String? cleanQuery;

  const SearchIntent({
    this.categoryId,
    this.categoryName,
    this.location,
    this.tags = const [],
    this.confidence = 0.0,
    this.cleanQuery,
  });

  factory SearchIntent.fromJson(Map<String, dynamic> json) {
    return SearchIntent(
      categoryId: json['category_id'] as int?,
      categoryName: json['category_name'] as String?,
      location: json['location'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      cleanQuery: json['clean_query'] as String?,
    );
  }
}

class SearchIntentApi {
  static Future<SearchIntent> parse(String query) async {
    if (query.trim().isEmpty) {
      return const SearchIntent();
    }
    
    try {
      final uri = Uri.parse('${ApiService.searchApiUrl}/api/search/intent').replace(
        queryParameters: {'q': query},
      );
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SearchIntent.fromJson(data);
      }
    } catch (e) {
      print('Error parsing search intent from backend: $e');
    }
    
    return const SearchIntent();
  }
}
