class URLHandler {
  final bool enabled;
  final List<String> patterns;
  const URLHandler({required this.enabled, this.patterns = const []});
  factory URLHandler.fromJson(Map<String, dynamic> json) {
    return URLHandler(
      enabled: json['enabled'] as bool? ?? false,
      patterns: (json['patterns'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
  bool matchesURL(String url) {
    if (!enabled || patterns.isEmpty) return false;
    final lowerUrl = url.toLowerCase();
    for (final pattern in patterns) {
      if (lowerUrl.contains(pattern.toLowerCase())) return true;
    }
    return false;
  }
}

class QualityOption {
  final String id;
  final String label;
  final String? description;
  final List<QualitySpecificSetting> settings;
  final double? sizeMB;
  const QualityOption({
    required this.id,
    required this.label,
    this.description,
    this.settings = const [],
    this.sizeMB,
  });
  factory QualityOption.fromJson(Map<String, dynamic> json) {
    return QualityOption(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String?,
      settings: (json['settings'] as List<dynamic>?)
          ?.map((s) => QualitySpecificSetting.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      sizeMB: (json['sizeMB'] as num?)?.toDouble(),
    );
  }
}

class QualitySpecificSetting {
  final String key;
  final String label;
  final String type;
  final dynamic defaultValue;
  final String? description;
  final List<String>? options;
  final bool required;
  final bool secret;
  const QualitySpecificSetting({
    required this.key,
    required this.label,
    required this.type,
    this.defaultValue,
    this.description,
    this.options,
    this.required = false,
    this.secret = false,
  });
  factory QualitySpecificSetting.fromJson(Map<String, dynamic> json) {
    return QualitySpecificSetting(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? 'string',
      defaultValue: json['default'],
      description: json['description'] as String?,
      options: (json['options'] as List<dynamic>?)?.cast<String>(),
      required: json['required'] as bool? ?? false,
      secret: json['secret'] as bool? ?? false,
    );
  }
}

class ExtensionSetting {
  final String key;
  final String label;
  final String type;
  final dynamic defaultValue;
  final String? description;
  final List<String>? options;
  final bool required;
  final String? action;
  const ExtensionSetting({
    required this.key,
    required this.label,
    required this.type,
    this.defaultValue,
    this.description,
    this.options,
    this.required = false,
    this.action,
  });
  factory ExtensionSetting.fromJson(Map<String, dynamic> json) {
    return ExtensionSetting(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? 'string',
      defaultValue: json['default'],
      description: json['description'] as String?,
      options: (json['options'] as List<dynamic>?)?.cast<String>(),
      required: json['required'] as bool? ?? false,
      action: json['action'] as String?,
    );
  }
}
