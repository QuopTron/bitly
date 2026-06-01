import 'package:bitly/providers/extension/extension_config_pp.dart';
import 'package:bitly/providers/extension/extension_config_urlhandler.dart';

export 'package:bitly/providers/extension/extension_config_pp.dart';
export 'package:bitly/providers/extension/extension_config_urlhandler.dart';

class SearchFilter {
  final String id;
  final String? label;
  final String? icon;
  const SearchFilter({required this.id, this.label, this.icon});
  factory SearchFilter.fromJson(Map<String, dynamic> json) {
    return SearchFilter(
      id: json['id'] as String? ?? '',
      label: json['label'] as String?,
      icon: json['icon'] as String?,
    );
  }
}

class SearchBehavior {
  final bool enabled;
  final String? placeholder;
  final bool primary;
  final String? icon;
  final String? thumbnailRatio;
  final int? thumbnailWidth;
  final int? thumbnailHeight;
  final List<SearchFilter> filters;

  const SearchBehavior({
    required this.enabled,
    this.placeholder,
    this.primary = false,
    this.icon,
    this.thumbnailRatio,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.filters = const [],
  });

  factory SearchBehavior.fromJson(Map<String, dynamic> json) {
    return SearchBehavior(
      enabled: json['enabled'] as bool? ?? false,
      placeholder: json['placeholder'] as String?,
      primary: json['primary'] as bool? ?? false,
      icon: json['icon'] as String?,
      thumbnailRatio: json['thumbnailRatio'] as String?,
      thumbnailWidth: json['thumbnailWidth'] as int?,
      thumbnailHeight: json['thumbnailHeight'] as int?,
      filters: (json['filters'] as List<dynamic>?)
          ?.map((f) => SearchFilter.fromJson(f as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  (double, double) getThumbnailSize({double defaultSize = 56}) {
    if (thumbnailWidth != null && thumbnailHeight != null) {
      return (thumbnailWidth!.toDouble(), thumbnailHeight!.toDouble());
    }
    switch (thumbnailRatio) {
      case 'wide':
        return (defaultSize * 16 / 9, defaultSize);
      case 'portrait':
        return (defaultSize * 2 / 3, defaultSize);
      case 'square':
      default:
        return (defaultSize, defaultSize);
    }
  }
}

class TrackMatching {
  final bool customMatching;
  final String? strategy;
  final int durationTolerance;
  const TrackMatching({
    required this.customMatching,
    this.strategy,
    this.durationTolerance = 3,
  });
  factory TrackMatching.fromJson(Map<String, dynamic> json) {
    return TrackMatching(
      customMatching: json['customMatching'] as bool? ?? false,
      strategy: json['strategy'] as String?,
      durationTolerance: json['durationTolerance'] as int? ?? 3,
    );
  }
}
