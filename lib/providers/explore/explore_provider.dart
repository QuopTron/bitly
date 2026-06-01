import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/settings/app_settings.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/providers/explore/explore_state.dart';
import 'package:bitly/providers/explore/explore_service.dart';
import 'package:bitly/providers/extension/extension_provider.dart';
import 'package:bitly/providers/settings/settings_provider.dart';
import 'package:bitly/utils/logger.dart';

export 'package:bitly/providers/explore/explore_state.dart';

final _log = AppLogger('ExploreProvider');

class ExploreNotifier extends Notifier<ExploreState> {
  final _service = ExploreService();
  int _homeFeedRequestId = 0;

  @override
  ExploreState build() { _restoreFromCache(); return const ExploreState(); }

  Future<void> _restoreFromCache() async {
    try {
      if (ref.read(settingsProvider).homeFeedProvider == AppSettings.homeFeedProviderOff) { _log.d('Home feed disabled, skipping cache restore'); return; }
      final cacheResult = await _service.restoreFromCache();
      if (cacheResult == null) return;
      final resolvedProviderId = cacheResult['provider_id']?.toString() ?? _resolveHomeFeedExtension()?.id;
      var normalizedSections = cacheResult['sections'] as List? ?? [];
      if (resolvedProviderId != null && resolvedProviderId.isNotEmpty) {
        normalizedSections = ExploreService.withDefaultExploreProviderId(normalizedSections.cast<Map<String, Object?>>(), resolvedProviderId);
      }
      final sections = ExploreService.buildExploreSectionsFromNormalizedPayload(normalizedSections.cast<Map<String, Object?>>());
      if (sections.isEmpty) return;
      state = ExploreState(greeting: ExploreService.getLocalGreeting(), providerId: resolvedProviderId, sections: sections, lastFetched: cacheResult['lastFetched'] as DateTime?);
    } catch (e) { _log.w('Failed to restore explore cache: $e'); }
  }

  Extension? _resolveHomeFeedExtension() {
    final settings = ref.read(settingsProvider);
    final preferredId = settings.homeFeedProvider;
    final enabledHomeFeedExtensions = ref.read(extensionProvider).extensions.where((extension) => extension.enabled && extension.hasHomeFeed).toList(growable: false);
    if (preferredId != null && preferredId.isNotEmpty) return enabledHomeFeedExtensions.where((extension) => extension.id == preferredId).firstOrNull;
    return enabledHomeFeedExtensions.firstOrNull;
  }

  Future<void> fetchHomeFeed({bool forceRefresh = false}) async {
    _log.i('fetchHomeFeed called, forceRefresh=$forceRefresh');
    if (ref.read(settingsProvider).homeFeedProvider == AppSettings.homeFeedProviderOff) {
      _homeFeedRequestId++; PlatformBridge.cancelExtensionHomeFeedRequests(); state = const ExploreState(); return;
    }
    if (!forceRefresh && state.hasContent && state.lastFetched != null && DateTime.now().difference(state.lastFetched!).inMinutes < 5) { _log.d('Using cached home feed (fresh enough)'); return; }
    if (state.isLoading && !forceRefresh) { _log.d('Home feed fetch already in progress'); return; }
    final requestId = ++_homeFeedRequestId;
    final showLoading = !state.hasContent;
    state = state.copyWith(isLoading: showLoading, error: null);
    try {
      final targetExt = _resolveHomeFeedExtension();
      if (targetExt == null) { if (requestId != _homeFeedRequestId) return; state = state.copyWith(isLoading: false, error: 'No extension with home feed support enabled'); return; }
      _log.i('Fetching home feed from ${targetExt.id}...');
      final result = await PlatformBridge.getExtensionHomeFeed(targetExt.id, cancelPrevious: forceRefresh);
      if (requestId != _homeFeedRequestId) return;
      if (result == null) { state = state.copyWith(isLoading: false, error: 'Failed to fetch home feed'); return; }
      final success = result['success'] as bool? ?? false;
      if (!success) { state = state.copyWith(isLoading: false, error: result['error'] as String?); return; }
      final sectionsData = result['sections'] as List<dynamic>? ?? [];
      final normalizedSectionsWithoutProvider = await compute(ExploreService.normalizeExploreSectionsPayload, sectionsData);
      final normalizedSections = ExploreService.withDefaultExploreProviderId(normalizedSectionsWithoutProvider, targetExt.id);
      if (requestId != _homeFeedRequestId) return;
      final sections = ExploreService.buildExploreSectionsFromNormalizedPayload(normalizedSections);
      _log.i('Fetched ${sections.length} sections');
      state = ExploreState(isLoading: false, greeting: ExploreService.getLocalGreeting(), providerId: targetExt.id, sections: sections, lastFetched: DateTime.now());
      _service.saveToCache(normalizedSections, targetExt.id);
    } catch (e, stack) {
      _log.e('Error fetching home feed: $e', e, stack);
      if (requestId != _homeFeedRequestId) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clear() { _homeFeedRequestId++; PlatformBridge.cancelExtensionHomeFeedRequests(); state = const ExploreState(); }
  Future<void> refresh() => fetchHomeFeed(forceRefresh: true);
}

final exploreProvider = NotifierProvider<ExploreNotifier, ExploreState>(() => ExploreNotifier());
