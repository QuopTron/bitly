class PostProcessing {
  final bool enabled;
  final List<PostProcessingHook> hooks;
  const PostProcessing({required this.enabled, this.hooks = const []});
  factory PostProcessing.fromJson(Map<String, dynamic> json) {
    return PostProcessing(
      enabled: json['enabled'] as bool? ?? false,
      hooks: (json['hooks'] as List<dynamic>?)
          ?.map((h) => PostProcessingHook.fromJson(h as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

class PostProcessingHook {
  final String id;
  final String name;
  final String? description;
  final bool defaultEnabled;
  final List<String> supportedFormats;
  const PostProcessingHook({
    required this.id,
    required this.name,
    this.description,
    this.defaultEnabled = false,
    this.supportedFormats = const [],
  });
  factory PostProcessingHook.fromJson(Map<String, dynamic> json) {
    return PostProcessingHook(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      defaultEnabled: json['defaultEnabled'] as bool? ?? false,
      supportedFormats: (json['supportedFormats'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

class ExtensionServiceHealthCheck {
  final String id;
  final String? label;
  final String url;
  final String method;
  final String? serviceKey;
  final int? timeoutMs;
  final int? cacheTtlSeconds;
  final bool required;
  const ExtensionServiceHealthCheck({
    required this.id,
    this.label,
    required this.url,
    this.method = 'GET',
    this.serviceKey,
    this.timeoutMs,
    this.cacheTtlSeconds,
    this.required = false,
  });
  factory ExtensionServiceHealthCheck.fromJson(Map<String, dynamic> json) {
    return ExtensionServiceHealthCheck(
      id: json['id'] as String? ?? '',
      label: json['label'] as String?,
      url: json['url'] as String? ?? '',
      method: json['method'] as String? ?? 'GET',
      serviceKey: json['serviceKey'] as String?,
      timeoutMs: json['timeoutMs'] as int?,
      cacheTtlSeconds: json['cacheTtlSeconds'] as int?,
      required: json['required'] as bool? ?? false,
    );
  }
}
