import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/providers/recent_access/recent_access_service.dart';
import 'package:bitly/providers/recent_access/recent_access_state.dart';

export 'package:bitly/providers/recent_access/recent_access_service.dart';
export 'package:bitly/providers/recent_access/recent_access_state.dart';

class RecentAccessNotifier extends Notifier<RecentAccessState> {
  final _service = RecentAccessService();

  @override
  RecentAccessState build() {
    _loadHistory();
    return const RecentAccessState();
  }

  Future<void> _loadHistory() async {
    try {
      final items = await _service.loadHistory();
      final hiddenIds = await _service.loadHiddenDownloadIds();
      state = state.copyWith(
        items: items,
        hiddenDownloadIds: hiddenIds,
        isLoaded: true,
      );
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  void recordArtistAccess({
    required String id,
    required String name,
    String? imageUrl,
    String? providerId,
  }) {
    _recordAccess(
      RecentAccessItem(
        id: id,
        name: name,
        imageUrl: imageUrl,
        type: RecentAccessType.artist,
        accessedAt: DateTime.now(),
        providerId: providerId,
      ),
    );
  }

  void recordAlbumAccess({
    required String id,
    required String name,
    String? artistName,
    String? imageUrl,
    String? providerId,
  }) {
    _recordAccess(
      RecentAccessItem(
        id: id,
        name: name,
        subtitle: artistName,
        imageUrl: imageUrl,
        type: RecentAccessType.album,
        accessedAt: DateTime.now(),
        providerId: providerId,
      ),
    );
  }

  void recordTrackAccess({
    required String id,
    required String name,
    String? artistName,
    String? imageUrl,
    String? providerId,
  }) {
    _recordAccess(
      RecentAccessItem(
        id: id,
        name: name,
        subtitle: artistName,
        imageUrl: imageUrl,
        type: RecentAccessType.track,
        accessedAt: DateTime.now(),
        providerId: providerId,
      ),
    );
  }

  void recordPlaylistAccess({
    required String id,
    required String name,
    String? ownerName,
    String? imageUrl,
    String? providerId,
  }) {
    _recordAccess(
      RecentAccessItem(
        id: id,
        name: name,
        subtitle: ownerName,
        imageUrl: imageUrl,
        type: RecentAccessType.playlist,
        accessedAt: DateTime.now(),
        providerId: providerId,
      ),
    );
  }

  void _recordAccess(RecentAccessItem item) {
    final updatedItems = state.items
        .where((e) => e.uniqueKey != item.uniqueKey)
        .toList();

    updatedItems.insert(0, item);

    RecentAccessItem? removedTail;
    if (updatedItems.length > 20) {
      removedTail = updatedItems.removeLast();
    }

    state = state.copyWith(items: updatedItems);
    unawaited(_service.saveAccess(item));
    if (removedTail != null) {
      unawaited(_service.deleteAccess(removedTail.uniqueKey));
    }
  }

  void removeItem(RecentAccessItem item) {
    final updatedItems = state.items
        .where((e) => e.uniqueKey != item.uniqueKey)
        .toList();
    state = state.copyWith(items: updatedItems);
    unawaited(_service.deleteAccess(item.uniqueKey));
  }

  void hideDownloadFromRecents(String downloadId) {
    final updatedHidden = {...state.hiddenDownloadIds, downloadId};
    state = state.copyWith(hiddenDownloadIds: updatedHidden);
    unawaited(_service.hideDownload(downloadId));
  }

  bool isDownloadHidden(String downloadId) {
    return state.hiddenDownloadIds.contains(downloadId);
  }

  void clearHistory() {
    state = state.copyWith(items: []);
    unawaited(_service.clearHistory());
  }

  void clearHiddenDownloads() {
    state = state.copyWith(hiddenDownloadIds: {});
    unawaited(_service.clearHiddenDownloads());
  }
}

final recentAccessProvider =
    NotifierProvider<RecentAccessNotifier, RecentAccessState>(
      RecentAccessNotifier.new,
    );