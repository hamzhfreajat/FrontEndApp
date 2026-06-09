class Category {
  final int id;
  final int? parentId;
  final String name;
  final String? description;
  final String? iconName;
  final String? colorHex;
  final String? backgroundUrl;
  final String? tag;
  final Map<String, List<String>>? slugs;
  final int adsCount;

  Category({
    required this.id,
    this.parentId,
    required this.name,
    this.description,
    this.iconName,
    this.colorHex,
    this.backgroundUrl,
    this.tag,
    this.slugs,
    this.adsCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>>? parsedSlugs;
    if (json['slugs'] != null) {
      parsedSlugs = (json['slugs'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      );
    }

    return Category(
      id: json['id'],
      parentId: json['parent_id'],
      name: json['name'],
      description: json['description'],
      iconName: json['icon_name'],
      colorHex: json['color_hex'],
      backgroundUrl: json['background_url'],
      tag: json['tag'],
      slugs: parsedSlugs,
      adsCount: json['ads_count'] ?? 0,
    );
  }
}
