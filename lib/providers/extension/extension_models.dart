import 'package:bitly/providers/extension/extension_config.dart';

class Extension {
  final String id;
  final String name;
  final String displayName;
  final String version;
  final String description;
  final bool enabled;
  final String status;
  final String? errorMessage;
  final String? iconPath;
  final List<String> permissions;
  final List<ExtensionSetting> settings;
  final List<QualityOption> qualityOptions;
  final bool hasMetadataProvider;
  final bool hasDownloadProvider;
  final bool hasLyricsProvider;
  final bool skipMetadataEnrichment;
  final bool skipLyrics;
  final bool stopProviderFallback;
  final SearchBehavior? searchBehavior;
  final URLHandler? urlHandler;
  final TrackMatching? trackMatching;
  final PostProcessing? postProcessing;
  final List<ExtensionServiceHealthCheck> serviceHealth;
  final Map<String, dynamic> capabilities;

  const Extension({
    required this.id,
    required this.name,
    required this.displayName,
    required this.version,
    required this.description,
    required this.enabled,
    required this.status,
    this.errorMessage,
    this.iconPath,
    this.permissions = const [],
    this.settings = const [],
    this.qualityOptions = const [],
    this.hasMetadataProvider = false,
    this.hasDownloadProvider = false,
    this.hasLyricsProvider = false,
    this.skipMetadataEnrichment = false,
    this.skipLyrics = false,
    this.stopProviderFallback = false,
    this.searchBehavior,
    this.urlHandler,
    this.trackMatching,
    this.postProcessing,
    this.serviceHealth = const [],
    this.capabilities = const {},
  });

  factory Extension.fromJson(Map<String, dynamic> json) {
    return Extension(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['name'] as String? ?? '',
      version: json['version'] as String? ?? '0.0.0',
      description: json['description'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      status: json['status'] as String? ?? 'loaded',
      errorMessage: json['error_message'] as String?,
      iconPath: json['icon_path'] as String?,
      permissions: (json['permissions'] as List<dynamic>?)?.cast<String>() ?? [],
      settings: (json['settings'] as List<dynamic>?)
          ?.map((s) => ExtensionSetting.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      qualityOptions: (json['quality_options'] as List<dynamic>?)
          ?.map((q) => QualityOption.fromJson(q as Map<String, dynamic>))
          .toList() ?? [],
      hasMetadataProvider: json['has_metadata_provider'] as bool? ?? false,
      hasDownloadProvider: json['has_download_provider'] as bool? ?? false,
      hasLyricsProvider: json['has_lyrics_provider'] as bool? ?? false,
      skipMetadataEnrichment: json['skip_metadata_enrichment'] as bool? ?? false,
      skipLyrics: json['skip_lyrics'] as bool? ?? false,
      stopProviderFallback: json['stop_provider_fallback'] as bool? ?? false,
      searchBehavior: json['search_behavior'] != null
          ? SearchBehavior.fromJson(json['search_behavior'] as Map<String, dynamic>)
          : null,
      urlHandler: json['url_handler'] != null
          ? URLHandler.fromJson(json['url_handler'] as Map<String, dynamic>)
          : null,
      trackMatching: json['track_matching'] != null
          ? TrackMatching.fromJson(json['track_matching'] as Map<String, dynamic>)
          : null,
      postProcessing: json['post_processing'] != null
          ? PostProcessing.fromJson(json['post_processing'] as Map<String, dynamic>)
          : null,
      serviceHealth: (json['service_health'] as List<dynamic>?)
          ?.map((h) => ExtensionServiceHealthCheck.fromJson(h as Map<String, dynamic>))
          .toList() ?? [],
      capabilities: (json['capabilities'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Extension copyWith({
    String? id,
    String? name,
    String? displayName,
    String? version,
    String? description,
    bool? enabled,
    String? status,
    String? errorMessage,
    String? iconPath,
    List<String>? permissions,
    List<ExtensionSetting>? settings,
    List<QualityOption>? qualityOptions,
    bool? hasMetadataProvider,
    bool? hasDownloadProvider,
    bool? hasLyricsProvider,
    bool? skipMetadataEnrichment,
    bool? skipLyrics,
    bool? stopProviderFallback,
    SearchBehavior? searchBehavior,
    URLHandler? urlHandler,
    TrackMatching? trackMatching,
    PostProcessing? postProcessing,
    List<ExtensionServiceHealthCheck>? serviceHealth,
    Map<String, dynamic>? capabilities,
  }) {
    return Extension(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      version: version ?? this.version,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      iconPath: iconPath ?? this.iconPath,
      permissions: permissions ?? this.permissions,
      settings: settings ?? this.settings,
      qualityOptions: qualityOptions ?? this.qualityOptions,
      hasMetadataProvider: hasMetadataProvider ?? this.hasMetadataProvider,
      hasDownloadProvider: hasDownloadProvider ?? this.hasDownloadProvider,
      hasLyricsProvider: hasLyricsProvider ?? this.hasLyricsProvider,
      skipMetadataEnrichment: skipMetadataEnrichment ?? this.skipMetadataEnrichment,
      skipLyrics: skipLyrics ?? this.skipLyrics,
      stopProviderFallback: stopProviderFallback ?? this.stopProviderFallback,
      searchBehavior: searchBehavior ?? this.searchBehavior,
      urlHandler: urlHandler ?? this.urlHandler,
      trackMatching: trackMatching ?? this.trackMatching,
      postProcessing: postProcessing ?? this.postProcessing,
      serviceHealth: serviceHealth ?? this.serviceHealth,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}
