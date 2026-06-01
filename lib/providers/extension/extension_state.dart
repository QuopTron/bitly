import 'dart:convert';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/providers/extension/extension_models.dart';

final _log = AppLogger('ExtensionProvider');

bool stringListEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) { if (a[i] != b[i]) return false; }
  return true;
}

List<String>? tryDecodeStringListPreference(String rawJson, String key) {
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) throw const FormatException('expected a JSON list');
    final values = <String>[];
    for (final item in decoded) {
      if (item is! String) throw const FormatException('expected string entries');
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) values.add(trimmed);
    }
    return values;
  } catch (e) { _log.w('Ignoring invalid $key preference: $e'); return null; }
}

class ExtensionHealthStatus {
  final String extensionId;
  final String status;
  final DateTime? checkedAt;
  final List<ExtensionHealthCheckStatus> checks;
  const ExtensionHealthStatus({required this.extensionId, required this.status, this.checkedAt, this.checks = const []});
  factory ExtensionHealthStatus.fromJson(Map<String, dynamic> json) => ExtensionHealthStatus(
    extensionId: json['extension_id'] as String? ?? '', status: json['status'] as String? ?? 'unknown',
    checkedAt: DateTime.tryParse(json['checked_at'] as String? ?? ''),
    checks: (json['checks'] as List<dynamic>?)?.map((c) => ExtensionHealthCheckStatus.fromJson(c as Map<String, dynamic>)).toList() ?? [],
  );
  bool get isSupported => status != 'unsupported';
}

class ExtensionHealthCheckStatus {
  final String id;
  final String? label;
  final String url;
  final String method;
  final String? serviceKey;
  final bool required;
  final String status;
  final int? httpStatus;
  final int latencyMs;
  final String? message;
  final String? error;
  final DateTime? checkedAt;
  const ExtensionHealthCheckStatus({required this.id, this.label, required this.url, required this.method, this.serviceKey, this.required = false, required this.status, this.httpStatus, this.latencyMs = 0, this.message, this.error, this.checkedAt});
  factory ExtensionHealthCheckStatus.fromJson(Map<String, dynamic> json) => ExtensionHealthCheckStatus(
    id: json['id'] as String? ?? '', label: json['label'] as String?, url: json['url'] as String? ?? '',
    method: json['method'] as String? ?? 'GET', serviceKey: json['service_key'] as String?,
    required: json['required'] as bool? ?? false, status: json['status'] as String? ?? 'unknown',
    httpStatus: json['http_status'] as int?, latencyMs: json['latency_ms'] as int? ?? 0,
    message: json['message'] as String?, error: json['error'] as String?,
    checkedAt: DateTime.tryParse(json['checked_at'] as String? ?? ''),
  );
  String get displayLabel => label?.trim().isNotEmpty == true ? label! : id;
}

class ExtensionState {
  final List<Extension> extensions;
  final List<String> providerPriority;
  final List<String> metadataProviderPriority;
  final Map<String, ExtensionHealthStatus> healthStatuses;
  final bool isLoading;
  final String? error;
  final bool isInitialized;
  const ExtensionState({this.extensions = const [], this.providerPriority = const [], this.metadataProviderPriority = const [], this.healthStatuses = const {}, this.isLoading = false, this.error, this.isInitialized = false});

  ExtensionState copyWith({List<Extension>? extensions, List<String>? providerPriority, List<String>? metadataProviderPriority, Map<String, ExtensionHealthStatus>? healthStatuses, bool? isLoading, String? error, bool? isInitialized}) {
    return ExtensionState(extensions: extensions ?? this.extensions, providerPriority: providerPriority ?? this.providerPriority, metadataProviderPriority: metadataProviderPriority ?? this.metadataProviderPriority, healthStatuses: healthStatuses ?? this.healthStatuses, isLoading: isLoading ?? this.isLoading, error: error, isInitialized: isInitialized ?? this.isInitialized);
  }
}

class ExtensionInstallBatchResult {
  final int attempted;
  final int installed;
  final Map<String, String> failures;
  const ExtensionInstallBatchResult({required this.attempted, required this.installed, this.failures = const {}});
  bool get hasFailures => failures.isNotEmpty;
  bool get anyInstalled => installed > 0;
}

enum ExtensionManagerStatus { idle, installing, upgrading, removing, error }
