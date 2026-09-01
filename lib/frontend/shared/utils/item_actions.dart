import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/cache/settings_cache.dart';
import '../../../../backend/services/batch_download_helper.dart';
import '../../../../backend/services/download_cubit.dart';
import '../../../../backend/services/like_cubit.dart';
import '../../../../backend/services/playlist_export_service.dart';
import '../../../../backend/services/queue_cubit.dart';
import '../../../../injection.dart';
import '../playlist/utils.dart';
import '../widgets/add_to_modal.dart';
import '../widgets/download_options_sheet.dart';
import '../widgets/song_info_modal.dart';
import '../widgets/page_transitions.dart';
import '../../features/detail/album_detail_page.dart';
import '../../features/detail/artist_detail_page.dart';
import '../../features/detail/playlist_detail_page.dart';
import '../models/feed_models.dart';

/// Centraliza los handlers de acción de ítems (like, download, batch, delete,
/// export, navegación) para que Feed, Search y MiEspacio compartan la misma
/// lógica en lugar de duplicarla por vista.
class ItemActions {
  ItemActions._();

  static void toggleLike(BuildContext context, FeedItem item) {
    context.read<LikeCubit>().toggleLike(item);
  }

  static void startDownload(BuildContext context, FeedItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDownloadOptions(context, item, isDark);
  }

  static Future<void> startBatchDownload(BuildContext context, FeedItem item) async {
    if (item.type == 'album') {
      await BatchDownloadHelper.startAlbumBatch(
        context, item.id, item.source, item.artists ?? '',
        coverUrl: item.coverUrl,
      );
    } else if (item.type == 'playlist') {
      await BatchDownloadHelper.startPlaylistBatch(
        context, item.id, item.source,
        coverUrl: item.coverUrl,
      );
    }
  }

  static void showInfo(BuildContext context, FeedItem item) => showSongInfoModal(context, item);
  static void showMore(BuildContext context, FeedItem item) => showAddToModal(context, item);

  static Future<void> exportPlaylist(BuildContext context, FeedItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final isAlbum = item.type == 'album';
    try {
      final result = await fetchDetail(
        type: item.type,
        id: item.id,
        source: item.source ?? '',
      );
      if (result == null) {
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text(isAlbum
                ? 'No se pudo cargar el álbum'
                : 'No se pudo cargar la playlist'),
            duration: const Duration(seconds: 2),
          ));
        }
        return;
      }
      final (name, tracks) = result;
      await PlaylistExportService.exportWithSnack(
        // ignore: use_build_context_synchronously
        context: context,
        name: name,
        tracks: tracks,
        initialDirectory: await sl<SettingsCache>().getDownloadPath(),
      );
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Error al exportar'),
          duration: Duration(seconds: 2),
        ));
      }
    }
  }

  static void batchDelete(BuildContext context, FeedItem item) {
    final src = item.source ?? '';
    if (item.type == 'album') {
      context.read<DownloadCubit>().deleteAlbumDownload(item.id, src);
    } else if (item.type == 'playlist') {
      context.read<DownloadCubit>().deletePlaylistDownload(item.id, src);
    }
  }

  static void deleteTrack(BuildContext context, FeedItem item) {
    context.read<DownloadCubit>().deleteTrackDownload(item.id, item.source ?? '');
  }

  static void navigateToItem(BuildContext context, FeedItem item) {
    final src = item.source ?? '';
    Widget wrap(Widget child) =>
        BlocProvider.value(
          value: context.read<LikeCubit>(),
          child: BlocProvider.value(
            value: context.read<DownloadCubit>(),
            child: child,
          ),
        );
    switch (item.type) {
      case 'album':
        Navigator.push(context, FadeSlideUpRoute(page: wrap(
          BlocProvider.value(
            value: sl<QueueCubit>(),
            child: AlbumDetailPage(albumId: item.id, source: src, coverUrl: item.coverUrl),
          ),
        )));
      case 'playlist':
        Navigator.push(context, FadeSlideUpRoute(page: wrap(
          PlaylistDetailPage(collectionId: item.id, playlistName: item.name, source: src, coverUrl: item.coverUrl),
        )));
      case 'artist':
        Navigator.push(context, FadeSlideUpRoute(page: wrap(
          BlocProvider.value(
            value: sl<QueueCubit>(),
            child: ArtistDetailPage(artistId: item.id, artistName: item.name, source: src),
          ),
        )));
    }
  }
}
