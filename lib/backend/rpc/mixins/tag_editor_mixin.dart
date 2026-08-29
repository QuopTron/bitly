import 'dart:convert';

import 'package:logger/logger.dart';

import '../backend_service.dart';

final _log = Logger();

/// Tag editor — reads/writes audio file metadata via Go backend.
mixin TagEditorMixin on BackendService {
  @override
  Future<String> readFileMetadata(String filePath) async {
    try {
      final result = await rpcCall('readFileMetadata', {'path': filePath});
      if (result is String) return result;
      if (result is Map) return jsonEncode(result);
      return '{}';
    } catch (e) {
      _log.w('[tagEditor] readFileMetadata error: $e');
      return '{}';
    }
  }

  @override
  Future<bool> writeFileMetadata(String filePath, Map<String, String> meta) async {
    try {
      final result = await rpcCall('writeFileMetadata', {
        'filePath': filePath,
        'meta': meta,
      });
      if (result is Map) return result['ok'] == true;
      if (result is String && result.isNotEmpty) {
        final decoded = jsonDecode(result);
        if (decoded is Map) return decoded['ok'] == true;
      }
      return true;
    } catch (e) {
      _log.w('[tagEditor] writeFileMetadata error: $e');
      return false;
    }
  }

  @override
  Future<String> getProviderHealthStatus() async {
    try {
      final result = await rpcCall('getProviderHealthStatus');
      if (result is String) return result;
      if (result is List) return jsonEncode(result);
      return '[]';
    } catch (e) {
      _log.w('[providerHealth] getProviderHealthStatus error: $e');
      return '[]';
    }
  }
}
