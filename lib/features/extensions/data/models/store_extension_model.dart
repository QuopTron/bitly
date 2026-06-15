import '../../domain/entities/store_extension.dart';

class StoreExtensionModel {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final int downloads;
  final double rating;
  final String category;
  final String iconUrl;
  final List<String> screenshots;

  const StoreExtensionModel({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    this.description = '',
    this.downloads = 0,
    this.rating = 0.0,
    this.category = '',
    this.iconUrl = '',
    this.screenshots = const [],
  });

  factory StoreExtensionModel.fromJson(Map<String, dynamic> json) {
    return StoreExtensionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      author: json['author'] as String,
      description: json['description'] as String? ?? '',
      downloads: json['downloads'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? '',
      iconUrl: json['iconUrl'] as String? ?? '',
      screenshots: (json['screenshots'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'author': author,
      'description': description,
      'downloads': downloads,
      'rating': rating,
      'category': category,
      'iconUrl': iconUrl,
      'screenshots': screenshots,
    };
  }

  StoreExtension toEntity() {
    return StoreExtension(
      id: id,
      name: name,
      version: version,
      author: author,
      description: description,
      downloads: downloads,
      rating: rating,
      category: category,
    );
  }
}
