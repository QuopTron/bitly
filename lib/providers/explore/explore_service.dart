import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitly/providers/explore/explore_state.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('ExploreService');

class ExploreService {
  static const _cacheKey = 'explore_home_feed_cache';
  static const _cacheTsKey = 'explore_home_feed_ts';

  static String getLocalGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Buenos días';
    if (hour >= 12 && hour < 17) return 'Buenas tardes';
    if (hour >= 17 && hour < 21) return 'Buenas noches';
    return 'Buenas noches';
  }

  static List<Map<String, Object?>> normalizeExploreSectionsPayload(
    dynamic rawSections,
  ) {
    if (rawSections is! List) return const [];
    final sections = <Map<String, Object?>>[];
    for (final rawSection in rawSections) {
      if (rawSection is! Map) continue;
      final section = Map<Object?, Object?>.from(rawSection);
      final rawItems = section['items'];
      final items = <Map<String, Object?>>[];
      if (rawItems is List) {
        for (final rawItem in rawItems) {
          if (rawItem is! Map) continue;
          items.add(Map<String, Object?>.from(rawItem));
        }
      }
      sections.add({
        'uri': section['uri']?.toString() ?? '',
        'title': section['title']?.toString() ?? '',
        'items': items,
      });
    }
    return sections;
  }

  static List<Map<String, Object?>> withDefaultExploreProviderId(
    List<Map<String, Object?>> normalizedSections,
    String providerId,
  ) {
    final normalizedProviderId = providerId.trim();
    if (normalizedProviderId.isEmpty) return normalizedSections;

    return normalizedSections.map((section) {
      final rawItems = section['items'];
      if (rawItems is! List) return section;
      return <String, Object?>{
        ...section,
        'items': rawItems.map((rawItem) {
          if (rawItem is! Map) return rawItem;
          final item = Map<String, Object?>.from(rawItem);
          final itemProviderId =
              item['provider_id']?.toString().trim() ?? '';
          if (itemProviderId.isEmpty) {
            item['provider_id'] = normalizedProviderId;
          }
          return item;
        }).toList(growable: false),
      };
    }).toList(growable: false);
  }

  static Map<String, Object?> decodeExploreCache(String rawCache) {
    final decoded = jsonDecode(rawCache);
    if (decoded is! Map) {
      return const {'provider_id': null, 'sections': <Map<String, Object?>>[]};
    }
    final providerId = decoded['provider_id']?.toString().trim();
    var sections = normalizeExploreSectionsPayload(decoded['sections']);
    if (providerId != null && providerId.isNotEmpty) {
      sections = withDefaultExploreProviderId(sections, providerId);
    }
    return {'provider_id': providerId, 'sections': sections};
  }

  static String encodeExploreCache(Map<String, Object?> cachePayload) {
    return jsonEncode(cachePayload);
  }

  static List<ExploreSection> buildExploreSectionsFromNormalizedPayload(
    List<Map<String, Object?>> normalizedSections,
  ) {
    return normalizedSections
        .map((section) =>
            ExploreSection.fromJson(Map<String, dynamic>.from(section)))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> restoreFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      final cachedTs = prefs.getInt(_cacheTsKey);
      if (cached == null || cached.isEmpty) return null;

      final cachePayload = await compute(decodeExploreCache, cached);
      final rawSections = cachePayload['sections'];
      var normalizedSections = rawSections is List
          ? rawSections.whereType<Map<Object?, Object?>>()
              .map((section) => Map<String, Object?>.from(section))
              .toList(growable: false)
          : const <Map<String, Object?>>[];

      final sections = buildExploreSectionsFromNormalizedPayload(normalizedSections);
      if (sections.isEmpty) return null;

      final lastFetched = cachedTs != null
          ? DateTime.fromMillisecondsSinceEpoch(cachedTs)
          : null;

      _log.i('Restored ${sections.length} cached explore sections');
      return {
        'sections': sections,
        'lastFetched': lastFetched,
        'greeting': getLocalGreeting(),
      };
    } catch (e) {
      _log.w('Failed to restore explore cache: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cacheKey);
        await prefs.remove(_cacheTsKey);
      } catch (_) {}
      return null;
    }
  }

  Future<void> saveToCache(
    List<Map<String, Object?>> normalizedSections,
    String providerId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = await compute(encodeExploreCache, {
        'provider_id': providerId,
        'sections': normalizedSections,
      });
      await prefs.setString(_cacheKey, encoded);
      await prefs.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
      _log.d('Saved ${normalizedSections.length} explore sections to cache');
    } catch (e) {
      _log.w('Failed to save explore cache: $e');
    }
  }
}