import 'dart:convert';
import '../database/app_database.dart';
import '../database/daos/settings_dao.dart';
import '../../frontend/shared/models/feed_models.dart';

/// Snapshot of a previously fetched home feed, restored on startup so the UI
/// can show content immediately even before (or without) a fresh backend
/// response. Mirrors SpotiFLAC's explore home-feed cache.
class FeedCacheData {
  final List<FeedSection> sections;
  final String selectedSource;
  final DateTime? lastFetched;

  const FeedCacheData({
    required this.sections,
    this.selectedSource = '',
    this.lastFetched,
  });

  bool get hasContent => sections.any((s) => s.items.isNotEmpty);
}

/// Local persistence for the home feed. Stores the last successful sections
/// (plus the active source and a timestamp) as JSON in the settings table.
/// If the stored payload can't be parsed it is removed (invalidated).
class FeedCache {
  static const _sectionsKey = 'home_feed_sections';
  static const _sourceKey = 'home_feed_source';
  static const _tsKey = 'home_feed_ts';

  final SettingsDao _s;
  FeedCache(AppDatabase db) : _s = SettingsDao(db);

  Future<FeedCacheData?> load() async {
    try {
      final raw = await _s.get(_sectionsKey);
      if (raw == null || raw.isEmpty) return null;
      final list = (jsonDecode(raw) as List)
          .map((e) => FeedSection.fromJson(e as Map<String, dynamic>))
          .toList();
      final source = await _s.get(_sourceKey) ?? '';
      final tsRaw = await _s.get(_tsKey);
      final ts = tsRaw != null ? DateTime.tryParse(tsRaw) : null;
      final data = FeedCacheData(sections: list, selectedSource: source, lastFetched: ts);
      return data.hasContent ? data : null;
    } catch (_) {
      await _clear();
      return null;
    }
  }

  Future<void> save(List<FeedSection> sections, String selectedSource) async {
    try {
      await _s.set(
        _sectionsKey,
        jsonEncode(sections.map((e) => e.toJson()).toList()),
      );
      await _s.set(_sourceKey, selectedSource);
      await _s.set(_tsKey, DateTime.now().toIso8601String());
    } catch (_) {
      // Caching is best-effort; never let a write failure break the feed.
    }
  }

  Future<void> _clear() async {
    try {
      await _s.remove(_sectionsKey);
      await _s.remove(_sourceKey);
      await _s.remove(_tsKey);
    } catch (_) {}
  }
}
