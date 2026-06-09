class Region {
  final int id;
  final String nameAr;
  final String nameEn;
  final double? latitude;
  final double? longitude;
  final int cityId;

  Region({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.latitude,
    this.longitude,
    required this.cityId,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'],
      nameAr: json['name_ar'],
      nameEn: json['name_en'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      cityId: json['city_id'],
    );
  }
}

class City {
  final int id;
  final String nameAr;
  final String nameEn;
  final List<Region> regions;

  City({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.regions,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    var regionsList = json['regions'] as List? ?? [];
    return City(
      id: json['id'],
      nameAr: json['name_ar'],
      nameEn: json['name_en'],
      regions: regionsList.map((r) => Region.fromJson(r)).toList(),
    );
  }
}
