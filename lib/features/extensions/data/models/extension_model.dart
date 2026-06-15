import '../../domain/entities/extension.dart';

class ExtensionModel {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final bool enabled;
  final String type;
  final int priority;
  final String source;

  const ExtensionModel({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    this.description = '',
    required this.enabled,
    required this.type,
    this.priority = 0,
    this.source = 'dart',
  });

  factory ExtensionModel.fromJson(Map<String, dynamic> json) {
    return ExtensionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      author: json['author'] as String,
      description: json['description'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      type: json['type'] as String? ?? 'api',
      priority: json['priority'] as int? ?? 0,
      source: json['source'] as String? ?? 'dart',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'author': author,
      'description': description,
      'enabled': enabled,
      'type': type,
      'priority': priority,
      'source': source,
    };
  }

  Extension toEntity() {
    return Extension(
      id: id,
      name: name,
      version: version,
      author: author,
      description: description,
      isEnabled: enabled,
      type: type,
      priority: priority,
    );
  }

  factory ExtensionModel.fromEntity(Extension entity) {
    return ExtensionModel(
      id: entity.id,
      name: entity.name,
      version: entity.version,
      author: entity.author,
      description: entity.description,
      enabled: entity.isEnabled,
      type: entity.type,
      priority: entity.priority,
    );
  }
}
