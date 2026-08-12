import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/cache/settings_cache.dart';
import '../../../../backend/cache/feed_cache.dart';
import '../../../../backend/rpc/backend_service.dart';
import '../../../../frontend/shared/models/feed_models.dart';
import '../../../../injection.dart';
import 'feed_event.dart';
import 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final BackendService _backend;

  FeedBloc(this._backend) : super(const FeedState()) {
    on<LoadFeed>(_onLoadFeed);
    on<DownloadItem>(_onDownloadItem);
    on<FeedSourceChanged>((event, emit) => emit(state.copyWith(selectedSource: event.source)));
  }

  /// Computes the best valid selected source given the fetched sections.
  String _validSource(List<FeedSection> sections, String preferred) {
    final available = <String>{};
    for (final s in sections) {
      if (s.source.isNotEmpty) available.add(s.source);
    }
    return available.contains(preferred)
        ? preferred
        : (available.isNotEmpty ? available.first : '');
  }

  Future<void> _onLoadFeed(LoadFeed event, Emitter<FeedState> emit) async {
    final feedCache = sl<FeedCache>();
    final setup = await sl<SettingsCache>().loadSetupData();

    // 1. Restore the last known feed immediately so the UI shows content even
    //    if the backend is slow, down, or returns nothing (offline recovery).
    FeedCacheData? cached;
    try {
      cached = await feedCache.load();
    } catch (_) {
      cached = null;
    }

    if (cached != null && cached.sections.isNotEmpty) {
      emit(state.copyWith(
        sections: cached.sections,
        username: setup?.username ?? state.username,
        selectedSource: _validSource(cached.sections, cached.selectedSource),
        loading: false,
        error: null,
      ));
    } else {
      emit(state.copyWith(loading: true, error: null));
    }

    // 2. Refresh from the backend in the background, keeping whatever content
    //    is already visible (don't blank the feed while it reloads).
    try {
      final sections = await _backend.getHomeFeed();
      if (emit.isDone) return;
      final valid = _validSource(sections, state.selectedSource);
      emit(state.copyWith(
        sections: sections,
        username: setup?.username ?? '',
        selectedSource: valid,
        loading: false,
        error: null,
      ));
      // 3. Persist the successful feed for the next offline recovery.
      await feedCache.save(sections, valid);
    } catch (e) {
      if (emit.isDone) return;
      // 4. On failure keep the restored (cached) content; only surface the
      //    error when there is nothing to show.
      emit(state.copyWith(
        loading: false,
        error: cached != null && cached.sections.isNotEmpty ? null : e.toString(),
      ));
    }
  }

  Future<void> _onDownloadItem(
      DownloadItem event, Emitter<FeedState> emit) async {
    try {
      await _backend.downloadItem(event.itemId);
    } catch (_) {
      // Silently handle — downloadItem stores the item for later processing
    }
  }
}


