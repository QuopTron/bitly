import 'package:bitly/constants/app_info.dart';

final RegExp _leadingVersionPrefix = RegExp(r'^v');

int compareVersions(String v1, String v2) {
  final parts1 = v1.replaceAll(_leadingVersionPrefix, '').split('.');
  final parts2 = v2.replaceAll(_leadingVersionPrefix, '').split('.');

  final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;

  for (var i = 0; i < maxLen; i++) {
    final n1 = i < parts1.length ? (int.tryParse(parts1[i]) ?? 0) : 0;
    final n2 = i < parts2.length ? (int.tryParse(parts2[i]) ?? 0) : 0;

    if (n1 < n2) return -1;
    if (n1 > n2) return 1;
  }
  return 0;
}

class StoreCategory {
  static const String metadata = 'metadata';
  static const String download = 'download';
  static const String utility = 'utility';
  static const String lyrics = 'lyrics';
  static const String integration = 'integration';

  static const List<String> all = [
    metadata,
    download,
    utility,
    lyrics,
    integration,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case metadata:
        return 'Metadata';
      case download:
        return 'Download';
      case utility:
        return 'Utility';
      case lyrics:
        return 'Lyrics';
      case integration:
        return 'Integration';
      default:
        return category;
    }
  }
}

class StoreExtension {
  final String id;
  final String name;
  final String displayName;
  final String version;
  final String description;
  final String downloadUrl;
  final String? iconUrl;
  final String category;
  final List<String> tags;
  final int downloads;
  final String updatedAt;
  final String? minAppVersion;
  final bool isInstalled;
  final String? installedVersion;
  final bool hasUpdate;

  const StoreExtension({
    required this.id,
    required this.name,
    required this.displayName,
    required this.version,
    required this.description,
    required this.downloadUrl,
    this.iconUrl,
    required this.category,
    this.tags = const [],
    this.downloads = 0,
    required this.updatedAt,
    this.minAppVersion,
    this.isInstalled = false,
    this.installedVersion,
    this.hasUpdate = false,
  });

  factory StoreExtension.fromJson(Map<String, dynamic> json) {
    return StoreExtension(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      displayName:
          json['display_name'] as String? ?? json['name'] as String? ?? '',
      version: json['version'] as String? ?? '0.0.0',
      description: json['description'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      iconUrl: json['icon_url'] as String?,
      category: json['category'] as String? ?? 'utility',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      downloads: json['downloads'] as int? ?? 0,
      updatedAt: json['updated_at'] as String? ?? '',
      minAppVersion: json['min_app_version'] as String?,
      isInstalled: json['is_installed'] as bool? ?? false,
      installedVersion: json['installed_version'] as String?,
      hasUpdate: json['has_update'] as bool? ?? false,
    );
  }

  bool get requiresNewerApp {
    if (minAppVersion == null || minAppVersion!.isEmpty) return false;
    return compareVersions(minAppVersion!, AppInfo.version) > 0;
  }

  StoreExtension copyWith({
    String? id,
    String? name,
    String? displayName,
    String? version,
    String? description,
    String? downloadUrl,
    String? iconUrl,
    String? category,
    List<String>? tags,
    int? downloads,
    String? updatedAt,
    String? minAppVersion,
    bool? isInstalled,
    String? installedVersion,
    bool? hasUpdate,
  }) {
    return StoreExtension(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      version: version ?? this.version,
      description: description ?? this.description,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      downloads: downloads ?? this.downloads,
      updatedAt: updatedAt ?? this.updatedAt,
      minAppVersion: minAppVersion ?? this.minAppVersion,
      isInstalled: isInstalled ?? this.isInstalled,
      installedVersion: installedVersion ?? this.installedVersion,
      hasUpdate: hasUpdate ?? this.hasUpdate,
    );
  }
}