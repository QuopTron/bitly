import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../backend/cache/settings_cache.dart';
import '../../shared/utils/download_strategy.dart';
import '../../../backend/cache/download_cache.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utils/responsive.dart';
import '../../shared/utils/item_actions.dart';
import '../../shared/theme/app_colors.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/download_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../backend/services/playlist_cubit.dart';
import '../../../backend/services/batch_download_helper.dart';
import '../../../backend/services/playlist_domain_service.dart';
import '../../shared/widgets/glass_container.dart';
import '../detail/album_detail_page.dart';
import '../detail/playlist_detail_page.dart';
import '../detail/artist_detail_page.dart';
import '../../shared/widgets/song_info_modal.dart';
import '../../shared/models/feed_models.dart';
import '../../../injection.dart';
import 'mi_espacio_profile.dart';
import 'mi_espacio_tabs.dart';
import 'mi_espacio_content.dart';
import 'mi_espacio_data.dart';

class MiEspacioPage extends StatefulWidget {
  const MiEspacioPage({super.key});

  @override
  State<MiEspacioPage> createState() => _MiEspacioPageState();
}

class _MiEspacioPageState extends State<MiEspacioPage> {
  String _username = '';
  bool _loading = true;
  int _selectedTab = 0;
  List<Item> _playlists = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _initLoad();
  }

  Future<void> _initLoad() async {
    // Carga defensiva de datos: si Mi Espacio se abre sin pasar por
    // HomePage.initState (deep link / navegación directa), los cubits quedan
    // inicializados y restauran likes + descargas desde la BD. Si ya estaban
    // cargados, estos llamados son no-ops.
    unawaited(context.read<LikeCubit>().initialize());
    unawaited(context.read<DownloadCubit>().initialize());
    unawaited(context.read<PlaylistCubit>().initialize());
    final u = await loadUsername();
    final p = await loadOwnPlaylists();
    await sl<PlaylistCubit>().loadStats();
    if (mounted) {
      setState(() {
        _username = u;
        _playlists = p;
        _loading = false;
      });
    }
  }

  void _onTabChanged(int i) {
    setState(() => _selectedTab = i);
    // Recargar playlists creadas al volver al tab: si se creó/borró una desde
    // otra pantalla mientras Mi Espacio estaba cargado, se refleja al volver.
    if (i == 1) {
      loadOwnPlaylists().then((p) {
        if (mounted) setState(() => _playlists = p);
      });
    }
  }

  void _onThemeChanged(bool isDark) {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    sl<ValueNotifier<ThemeMode>>().value = mode;
    sl<SettingsCache>().saveThemeMode(
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  void _onLanguageChanged() {
    final current = sl<ValueNotifier<Locale>>().value;
    final next =
        current.languageCode == 'es' ? const Locale('en') : const Locale('es');
    sl<ValueNotifier<Locale>>().value = next;
    sl<SettingsCache>().saveLanguage(next.languageCode);
  }

  FeedItem _feedItemFor(Item item) {
    final type =
        item.type == ItemType.album
            ? 'album'
            : item.type == ItemType.playlist
            ? 'playlist'
            : item.type == ItemType.artist
            ? 'artist'
            : 'track';
    return FeedItem(
      id: item.realId,
      type: type,
      name: item.title,
      artists: item.subtitle,
      coverUrl: item.coverUrl,
      source: _resolveSource(item),
    );
  }

  void _onLike(Item item) {
    if (item.realId.isEmpty) return;
    context.read<LikeCubit>().toggleLike(_feedItemFor(item));
  }

  static String _resolveSource(Item item) {
    if (item.source.isNotEmpty) return item.source;
    final lastSep = item.realId.lastIndexOf('/');
    final lastColon = item.realId.lastIndexOf(':');
    final sep = lastSep > lastColon ? lastSep : lastColon;
    if (sep > 0 && sep < item.realId.length - 1) {
      return item.realId.substring(0, sep);
    }
    return '';
  }

  void _onItemTap(Item item) {
    if (item.realId.isEmpty) return;
    final src = _resolveSource(item);
    switch (item.type) {
      case ItemType.album:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => BlocProvider.value(
                  value: context.read<LikeCubit>(),
                  child: BlocProvider.value(
                    value: context.read<DownloadCubit>(),
                    child: BlocProvider.value(
                      value: sl<QueueCubit>(),
                      child: AlbumDetailPage(
                        albumId: item.realId,
                        source: src,
                        coverUrl: item.coverUrl,
                      ),
                    ),
                  ),
                ),
          ),
        );
      case ItemType.playlist:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => BlocProvider.value(
                  value: context.read<LikeCubit>(),
                  child: BlocProvider.value(
                    value: context.read<DownloadCubit>(),
                    child: PlaylistDetailPage(
                      collectionId: item.realId,
                      playlistName: item.title,
                      source: src,
                      coverUrl: item.coverUrl,
                    ),
                  ),
                ),
          ),
        );
      case ItemType.artist:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => BlocProvider.value(
                  value: context.read<LikeCubit>(),
                  child: BlocProvider.value(
                    value: context.read<DownloadCubit>(),
                    child: BlocProvider.value(
                      value: sl<QueueCubit>(),
                      child: ArtistDetailPage(
                        artistId: item.realId,
                        artistName: item.title,
                        source: item.source,
                      ),
                    ),
                  ),
                ),
          ),
        );
      case ItemType.song:
        showSongInfoModal(
          context,
          FeedItem(
            id: item.realId,
            type: 'track',
            name: item.title,
            artists: item.subtitle,
            coverUrl: item.coverUrl,
            source: item.source,
          ),
        );
    }
  }

  Future<void> _onCreatePlaylist() async {
    _playlists = await loadOwnPlaylists();
    if (mounted) setState(() {});
  }

  Future<void> _onCreatePlaylistFromLiked() async {
    final loc = AppLocalizations.of(context);
    final playlistSvc = sl<PlaylistDomainService>();
    final likedCubit = context.read<LikeCubit>();
    final tracks = likedCubit.tracks;
    if (tracks.isEmpty) return;

    final name =
        '${loc.setup.likedSongs} (${DateTime.now().toString().substring(0, 10)})';
    final created = await playlistSvc.create(name);
    if (created == null) return;

    for (final t in tracks) {
      await playlistSvc.addTrack(created.id, t.id);
    }
    await playlistSvc.ensureCover(
      created.id,
      tracks.map((t) => t.coverUrl).toList(),
    );

    await _onCreatePlaylist();
    if (mounted) {
      _showSnack(
        '${loc.setup.miSpacePlaylist} "$name" ${loc.setup.downloaded}',
      );
    }
  }

  Future<void> _onCreatePlaylistFromDownloaded() async {
    final loc = AppLocalizations.of(context);
    final playlistSvc = sl<PlaylistDomainService>();
    try {
      final historyJson = await sl<DownloadCache>().getDownloadHistory();
      if (historyJson.isEmpty || historyJson == '[]') return;
      final list = jsonDecode(historyJson) as List;
      if (list.isEmpty) return;

      final name =
          '${loc.setup.downloaded} (${DateTime.now().toString().substring(0, 10)})';
      final created = await playlistSvc.create(name);
      if (created == null) return;

      final covers = <String?>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final trackId = (m['track_id'] ?? m['id'] ?? '').toString();
        if (trackId.isNotEmpty) {
          await playlistSvc.addTrack(created.id, trackId);
        }
        final cover =
            (m['coverUrl'] ?? m['cover_url'] ?? m['coverPath'] ?? '')
                .toString();
        if (cover.isNotEmpty) covers.add(cover);
      }
      await playlistSvc.ensureCover(created.id, covers);

      await _onCreatePlaylist();
      if (mounted) {
        _showSnack(
          '${loc.setup.miSpacePlaylist} "$name" ${loc.setup.downloaded}',
        );
      }
    } catch (_) {}
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _onExportPlaylist(Item item) async =>
      ItemActions.exportPlaylist(context, _feedItemFor(item));

  Future<void> _onBatchDownload(Item item) async {
    final src = _resolveSource(item);
    if (src.isEmpty) return;
    try {
      if (item.type == ItemType.album) {
        await BatchDownloadHelper.startAlbumBatch(
          context,
          item.realId,
          src,
          item.subtitle,
          coverUrl: item.coverUrl,
        );
      } else if (item.type == ItemType.playlist) {
        await BatchDownloadHelper.startPlaylistBatch(
          context,
          item.realId,
          src,
          coverUrl: item.coverUrl,
        );
      }
    } catch (_) {
      // Fallthrough: the batch helper already surfaces load errors.
    }
  }

  void _onRetryBatch(Item item) {
    final type = item.type == ItemType.album ? 'album' : 'playlist';
    final batchKey = '${type}_${normalizeTrackId(item.realId)}_${item.source}';
    context.read<DownloadCubit>().retryFailedBatchTracks(batchKey);
  }

  void _onBatchDelete(Item item) =>
      ItemActions.batchDelete(context, _feedItemFor(item));

  Widget _retryBanner(
    BuildContext context,
    Responsive r,
    Color onBg,
    Color glowColor,
    int count,
  ) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingM),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingM,
          vertical: r.spacingS,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFFFA726).withValues(alpha: 0.12),
          border: Border.all(
            color: const Color(0xFFFFA726).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: r.footerSize + 4,
              color: const Color(0xFFFFA726),
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: Text(
                count > 1
                    ? loc.setup.downloadInterruptedMany.replaceAll(
                      '{count}',
                      '$count',
                    )
                    : loc.setup.downloadInterruptedOne,
                style: TextStyle(
                  fontSize: r.footerSize,
                  color: onBg.withValues(alpha: 0.85),
                ),
              ),
            ),
            SizedBox(width: r.spacingS),
            GestureDetector(
              onTap: () => context.read<DownloadCubit>().retryAllInterrupted(),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.spacingM,
                  vertical: r.spacingXS,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFFFA726).withValues(alpha: 0.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh,
                      size: r.footerSize - 2,
                      color: const Color(0xFFFFA726),
                    ),
                    SizedBox(width: 4),
                    Text(
                      loc.setup.retryInterrupted,
                      style: TextStyle(
                        fontSize: r.footerSize - 1,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFFA726),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;
    final loc = AppLocalizations.of(context);

    final likeState = context.watch<LikeCubit>().state;
    final dlState = context.watch<DownloadCubit>().state;
    final playerStats = context.watch<PlaylistCubit>().state.stats;

    final interruptedCount =
        dlState.downloads.values
            .where((d) => d.state == DownloadState.interrupted)
            .length;
    final hasRetryableBatches = dlState.downloads.entries.any(
      (e) =>
          e.value.state == DownloadState.interrupted &&
          (e.key.startsWith('album_') || e.key.startsWith('playlist_')),
    );
    // Conteo real de descargas completadas: sin subtareas (_audio/_lyrics/_video)
    // que inflarían el número del perfil (1 track con letra+video = 3 entradas).
    final completedCount =
        dlState.downloads.entries
            .where(
              (e) =>
                  e.value.state == DownloadState.completed &&
                  !e.key.endsWith('_audio') &&
                  !e.key.endsWith('_lyrics') &&
                  !e.key.endsWith('_video'),
            )
            .length;

    return SafeArea(
      child: Column(
        children: [
          SizedBox(height: r.spacingM),
          MiEspacioProfile(
            username: _username,
            lovedSongsCount: tracksCount(
              likeState,
              downloadCubit: context.read<DownloadCubit>(),
            ),
            playlistsCount: _playlists.length,
            downloadedCount: completedCount,
            level: playerStats?.level ?? 0,
            levelProgress: playerStats?.progress ?? 0.0,
            nextLevel: playerStats?.nextLevel ?? 1,
            onBg: onBg,
            glowColor: glowColor,
            onThemeChanged: _onThemeChanged,
            onLanguageChanged: _onLanguageChanged,
          ),
          SizedBox(height: r.spacingM),

          // ── Retry interrupted downloads banner ──────────────────
          if (hasRetryableBatches)
            _retryBanner(context, r, onBg, glowColor, interruptedCount),

          SizedBox(height: r.spacingS),
          Expanded(
            child: GlassContainer(
              borderRadius: 16,
              borderColor: glowColor.withValues(alpha: 0.15),
              bgColor: onBg.withValues(alpha: 0.02),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MiEspacioTabBar(
                    selectedTab: _selectedTab,
                    onTabChanged: _onTabChanged,
                    onBg: onBg,
                    glowColor: glowColor,
                  ),
                  SizedBox(height: r.spacingS),
                  Expanded(
                    child: MiEspacioContent(
                      loading: _loading,
                      items: itemsForTab(
                        likeState,
                        _selectedTab,
                        _playlists,
                        downloadCubit: context.read<DownloadCubit>(),
                      ),
                      selectedTab: _selectedTab,
                      emptyMessage: emptyMessage(loc, _selectedTab),
                      likedIds: likeState.allLiked.keys.toSet(),
                      downloadStates: dlState.downloads.map(
                        (k, v) => MapEntry(k, v.state),
                      ),
                      downloadedFingerprints: dlState.downloadedFingerprints,
                      onUnlike:
                          (item) => unlikeItem(item, context, _selectedTab),
                      onLike: _onLike,
                      onItemTap: _onItemTap,
                      onCreatePlaylist: _onCreatePlaylist,
                      onCreateFromLiked: _onCreatePlaylistFromLiked,
                      onCreateFromDownloaded: _onCreatePlaylistFromDownloaded,
                      onBatchDownload: _onBatchDownload,
                      onBatchDelete: _onBatchDelete,
                      onRetryBatch: _onRetryBatch,
                      onExportPlaylist: _onExportPlaylist,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
