import 'dart:convert';

/// Fetches a detail (album/playlist/artist) with local-cache-first-then-fallback
/// pattern.
///
/// Calls [getLocal] first (e.g. DetailCache). If null/empty, calls [fetchRemote]
/// as fallback (passes source even if empty — the backend can iterate all
/// extensions when source is not specified).
///
/// Returns the parsed [T] on success, or `null` on any error.
Future<T?> loadDetailWithFallback<T>({
  required String id,
  required String source,
  required Future<String?> Function(String id) getLocal,
  required Future<String> Function(String id, String source) fetchRemote,
  required T Function(Map<String, dynamic> json) fromJson,
}) async {
  try {
    var json = await getLocal(id);
    if (json == null || json.isEmpty || json == '{}') {
      json = await fetchRemote(id, source);
    }
    if (json.isEmpty || json == '{}') return null;
    return fromJson(jsonDecode(json) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}


