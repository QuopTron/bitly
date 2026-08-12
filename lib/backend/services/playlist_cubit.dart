import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../frontend/shared/models/detail_models.dart';
import '../../frontend/shared/models/playlist_domain.dart';
import 'playlist_domain_service.dart';
import 'playlist_export_service.dart';

class PlaylistState extends Equatable {
  final bool loading;
  final List<PlaylistItem> playlists;
  final PlaylistDetail? currentDetail;
  final UserStats? stats;
  final String? error;

  const PlaylistState({
    this.loading = false,
    this.playlists = const [],
    this.currentDetail,
    this.stats,
    this.error,
  });

  PlaylistState copyWith({
    bool? loading,
    List<PlaylistItem>? playlists,
    PlaylistDetail? currentDetail,
    UserStats? stats,
    String? error,
  }) => PlaylistState(
    loading: loading ?? this.loading,
    playlists: playlists ?? this.playlists,
    currentDetail: currentDetail ?? this.currentDetail,
    stats: stats ?? this.stats,
    error: error,
  );

  @override
  List<Object?> get props => [loading, playlists, currentDetail, stats, error];
}

/// Lightweight playlist item used in [PlaylistState.playlists].
class PlaylistItem {
  final String id, name;
  final String? coverPath, createdAt, updatedAt;
  final int itemCount;

  const PlaylistItem({
    required this.id, required this.name,
    this.coverPath, this.createdAt, this.updatedAt,
    this.itemCount = 0,
  });

  factory PlaylistItem.fromJson(Map<String, dynamic> json) => PlaylistItem(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    coverPath: json['coverPath'] as String?,
    createdAt: json['createdAt'] as String?,
    updatedAt: json['updatedAt'] as String?,
    itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
  );
}

/// Converts a [PlaylistDomain] to a [PlaylistItem] for use in cubit state.
PlaylistItem _domainToItem(PlaylistDomain d) => PlaylistItem(
      id: d.id,
      name: d.name,
      coverPath: d.coverUrl,
      createdAt: d.createdAt?.toIso8601String(),
      updatedAt: d.updatedAt?.toIso8601String(),
      itemCount: d.trackCount,
    );

class PlaylistCubit extends Cubit<PlaylistState> {
  final PlaylistDomainService _domainService;

  PlaylistCubit(this._domainService) : super(const PlaylistState());

  Future<void> initialize() async {
    emit(state.copyWith(loading: true));
    await Future.wait([loadPlaylists(), loadStats()]);
    emit(state.copyWith(loading: false));
  }

  Future<void> loadPlaylists() async {
    try {
      final domains = await _domainService.getByUser();
      emit(state.copyWith(
        playlists: domains.map(_domainToItem).toList(),
      ));
    } catch (_) {}
  }

  Future<void> loadStats() async {
    try {
      final stats = await _domainService.getStats();
      if (stats != null) {
        emit(state.copyWith(stats: stats));
      }
    } catch (_) {}
  }

  Future<String?> createPlaylist(String name, {String? coverPath}) async {
    try {
      final domain = await _domainService.create(name);
      if (domain != null) {
        await loadPlaylists();
        return domain.id;
      }
    } catch (_) {}
    return null;
  }

  Future<void> addTrack(String playlistId, String trackId) async {
    try {
      await _domainService.addTrack(playlistId, trackId);
      if (state.currentDetail?.id == playlistId) await loadDetail(playlistId);
      await loadPlaylists();
    } catch (_) {}
  }

  Future<void> removeTrack(String playlistId, String trackId) async {
    try {
      await _domainService.removeTrack(playlistId, trackId);
      if (state.currentDetail?.id == playlistId) await loadDetail(playlistId);
      await loadPlaylists();
    } catch (_) {}
  }

  Future<void> loadDetail(String collectionId) async {
    try {
      final detail = await _domainService.getDetail(collectionId);
      if (detail != null) {
        emit(state.copyWith(currentDetail: detail));
      }
    } catch (_) {}
  }

  Future<void> updateCover(String playlistId, String coverPath) async {
    try {
      await _domainService.updateCover(playlistId, coverPath);
      await loadPlaylists();
    } catch (_) {}
  }

  Future<void> deletePlaylist(String playlistId) async {
    try {
      await _domainService.delete(playlistId);
      emit(state.copyWith(currentDetail: null));
      await loadPlaylists();
    } catch (_) {}
  }

  void clearDetail() => emit(state.copyWith(currentDetail: null));

  /// Export all tracks in the current playlist detail as playlist files.
  ///
  /// Prompts the user to pick an output directory, then generates
  /// M3U / M3U8 / CUE / NFO files for tracks that have local files.
  /// Returns the result of the export operation, or `null` if no detail is loaded.
  Future<PlaylistExportResult?> exportCurrentPlaylist({
    String? initialDirectory,
  }) async {
    final detail = state.currentDetail;
    if (detail == null || detail.tracks.isEmpty) return null;

    return PlaylistExportService.exportPlaylist(
      name: detail.name,
      tracks: detail.tracks,
      initialDirectory: initialDirectory,
    );
  }

  /// Export a specific playlist by ID.
  ///
  /// Loads the playlist detail, then prompts for export directory.
  Future<PlaylistExportResult?> exportPlaylistById(String playlistId,
      {String? initialDirectory}) async {
    try {
      await loadDetail(playlistId);
      return exportCurrentPlaylist(initialDirectory: initialDirectory);
    } catch (_) {
      return PlaylistExportResult(error: 'No se pudo cargar la playlist');
    }
  }
}


