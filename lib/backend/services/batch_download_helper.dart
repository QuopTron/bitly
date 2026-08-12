import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../frontend/shared/models/detail_models.dart';
import '../../frontend/shared/models/download_settings.dart';
import '../../frontend/shared/models/feed_models.dart';
import '../cache/settings_cache.dart';
import 'download_cubit.dart';
import 'like_cubit.dart';
import 'album_domain_service.dart';
import 'playlist_domain_service.dart';
import '../../frontend/shared/widgets/download_options_sheet.dart';
import '../../injection.dart';

/// Shared utility for the batch download flow (fetch detail → show modal).
///
/// Eliminates the duplicated `_startBatchDownload`/`_onBatchDownload` +
/// `_showAlbumBatchModal`/`_showPlaylistBatchModal` across [FeedPage],
/// [SearchPage] and [MiEspacioPage].
class BatchDownloadHelper {
  /// Show the album batch download bottom sheet.
  /// [fallbackCover] is the cover URL from the navigation source (e.g. feed item),
  /// used as a last resort when the detail response has no coverUrl.
  static void showAlbumModal(
    BuildContext context,
    AlbumDetail album,
    String source,
    String artistName,
    DownloadSettings settings,
    bool isDark, {
    String? fallbackCover,
  }) {
    final likedCubit = context.read<LikeCubit>();
    final likedAlbum = likedCubit.state.allLiked[album.id];
    final likedCover = likedAlbum?.localCoverPath ?? likedAlbum?.coverUrl;
    final albumCoverUrl = likedCover ?? likedCubit.resolveCoverFor(FeedItem(
      id: album.id, type: 'album', name: album.name,
      artists: album.artistName ?? artistName, coverUrl: album.coverUrl,
      source: source,
    )) ?? album.coverUrl ?? fallbackCover;

    final tracks = album.tracks.map((t) => <String, dynamic>{
      'track_id': t.trackId,
      'track_title': t.name,
      'artist_name': (t.artistName?.isNotEmpty == true)
          ? t.artistName!
          : ((album.artistName?.isNotEmpty == true)
              ? album.artistName!
              : artistName),
      'album_name':
          (t.albumName?.isNotEmpty == true) ? t.albumName! : album.name,
      'source': source,
      'isrc': t.isrc,
      'duration_ms': t.durationMs,
      'cover_url': (t.coverUrl?.isNotEmpty == true) ? t.coverUrl! : albumCoverUrl,
    }).toList();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DownloadOptionsSheet(
        item: FeedItem(
          id: album.id,
          type: 'album',
          name: album.name,
          artists: album.artistName ?? artistName,
          coverUrl: album.coverUrl,
          source: source,
        ),
        isDark: isDark,
        dlSettings: settings,
        onQualitySelected: (quality) {
          context.read<DownloadCubit>().startAlbumDownload(
                album.id,
                tracks,
                settings: settings,
                source: source,
                qualityOverride: quality,
              );
        },
      ),
    );
  }

  /// Show the playlist batch download bottom sheet.
  /// [fallbackCover] is the cover URL from the navigation source,
  /// used as a last resort when the detail response has no coverPath.
  static void showPlaylistModal(
    BuildContext context,
    PlaylistDetail playlist,
    String source,
    DownloadSettings settings,
    bool isDark, {
    String? fallbackCover,
  }) {
    final playlistCover = playlist.coverPath ?? fallbackCover;
    final tracks = playlist.tracks.map((t) => <String, dynamic>{
      'track_id': t.trackId,
      'track_title': t.name,
      'artist_name': t.artistName ?? '',
      'album_name': t.albumName ?? '',
      'source': source,
      'isrc': t.isrc,
      'duration_ms': t.durationMs,
      'cover_url': (t.coverUrl?.isNotEmpty == true) ? t.coverUrl! : playlistCover,
    }).toList();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DownloadOptionsSheet(
        item: FeedItem(
          id: playlist.id,
          type: 'playlist',
          name: playlist.name,
          source: source,
        ),
        isDark: isDark,
        dlSettings: settings,
        onQualitySelected: (quality) {
          context.read<DownloadCubit>().startPlaylistDownload(
                playlist.id,
                tracks,
                settings: settings,
                source: source,
                qualityOverride: quality,
              );
        },
      ),
    );
  }

  /// Fetch album detail and show batch download modal.
  /// [coverUrl] is the cover from the navigation source (e.g. feed item),
  /// used as a last resort when the detail response has no coverUrl.
  static Future<void> startAlbumBatch(
    BuildContext context,
    String id,
    String? source,
    String artistName, {
    String? coverUrl,
  }) async {
    try {
      final detail = await sl<AlbumDomainService>()
          .getDetail(id, source: source ?? '');
      if (detail == null || detail.tracks.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load album. Make sure it was saved from a source (Spotify, Deezer, etc).')),
          );
        }
        return;
      }
      final settings = await sl<SettingsCache>().getDownloadSettings();
      if (!context.mounted) return;
      showAlbumModal(
        context,
        detail,
        source ?? '',
        artistName,
        settings,
        Theme.of(context).brightness == Brightness.dark,
        fallbackCover: coverUrl,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load album. Make sure it was saved from a source (Spotify, Deezer, etc).')),
        );
      }
    }
  }

  /// Fetch playlist detail and show batch download modal.
  /// [coverUrl] is the cover from the navigation source (e.g. feed item),
  /// used as a last resort when the detail response has no coverPath.
  static Future<void> startPlaylistBatch(
    BuildContext context,
    String id,
    String? source, {
    String? coverUrl,
  }) async {
    try {
      final detail = await sl<PlaylistDomainService>()
          .getDetail(id, source: source ?? '');
      if (detail == null || detail.tracks.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load playlist. Make sure it was saved from a source (Spotify, Deezer, etc).')),
          );
        }
        return;
      }
      final settings = await sl<SettingsCache>().getDownloadSettings();
      if (!context.mounted) return;
      showPlaylistModal(
        context,
        detail,
        source ?? '',
        settings,
        Theme.of(context).brightness == Brightness.dark,
        fallbackCover: coverUrl,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load playlist. Make sure it was saved from a source (Spotify, Deezer, etc).')),
        );
      }
    }
  }
}


