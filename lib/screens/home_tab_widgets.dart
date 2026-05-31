part of 'home_tab.dart';

/// Dropdown widget for quick search provider switching
class _SearchProviderDropdown extends ConsumerWidget {
  final VoidCallback? onProviderChanged;

  const _SearchProviderDropdown({this.onProviderChanged});

  Widget _buildFallbackIcon(Extension ext, ColorScheme colorScheme, {double size = 16}) {
    final fromBehavior = ext.searchBehavior?.icon;
    if (fromBehavior != null && fromBehavior.isNotEmpty) {
      final icon = searchBehaviorIcon(fromBehavior);
      if (icon != Icons.extension) {
        return Icon(icon, size: size, color: colorScheme.onSurfaceVariant);
      }
    }
    final fromSource = sourceIcon(ext.id);
    if (fromSource != Icons.extension) {
      return Icon(fromSource, size: size, color: colorScheme.onSurfaceVariant);
    }
    final fromName = sourceIcon(ext.displayName);
    if (fromName != Icons.extension) {
      return Icon(fromName, size: size, color: colorScheme.onSurfaceVariant);
    }
    final letter = initialLetterFor(ext.displayName);
    final color = initialColorFor(ext.displayName, colorScheme: colorScheme);
    return Center(
      child: Text(letter,
        style: TextStyle(
          fontSize: size * 0.9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Extension? _defaultSearchExtension(List<Extension> extensions) {
    return extensions
            .where(
              (ext) =>
                  ext.enabled &&
                  ext.hasCustomSearch &&
                  ext.searchBehavior?.primary == true,
            )
            .firstOrNull ??
        extensions
            .where((ext) => ext.enabled && ext.hasCustomSearch)
            .firstOrNull;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawCurrentProvider = ref.watch(
      settingsProvider.select((s) => s.searchProvider),
    );
    final extensions = ref.watch(extensionProvider.select((s) => s.extensions));
    final providerReadiness = ref.watch(
      extensionProvider.select(
        (s) => (isInitialized: s.isInitialized, error: s.error),
      ),
    );
    final colorScheme = Theme.of(context).colorScheme;

    final searchProviders = extensions
        .where((ext) => ext.enabled && ext.hasCustomSearch)
        .toList();
    final hasAnyProvider = searchProviders.isNotEmpty;
    final isProviderLoading =
        !providerReadiness.isInitialized && providerReadiness.error == null;

    if (!hasAnyProvider) {
      return Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: isProviderLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : Icon(
                    Icons.search_off,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
      );
    }

    final resolvedCurrentProvider =
        rawCurrentProvider != null &&
            rawCurrentProvider.isNotEmpty &&
            searchProviders.any((e) => e.id == rawCurrentProvider)
        ? rawCurrentProvider
        : _defaultSearchExtension(searchProviders)?.id;
    final currentProvider =
        resolvedCurrentProvider != null && resolvedCurrentProvider.isNotEmpty
        ? resolvedCurrentProvider
        : null;

    Extension? currentExt;
    if (currentProvider != null && currentProvider.isNotEmpty) {
      currentExt = searchProviders
          .where((e) => e.id == currentProvider)
          .firstOrNull;
    }

    String? iconPath = currentExt?.iconPath;

    return PopupMenuButton<String>(
      tooltip: context.l10n.homeChangeSearchProviderTooltip,
      offset: const Offset(0, 44),
      color: colorScheme.surface.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.10),
          width: 0.5,
        ),
      ),
      onSelected: (String providerId) {
        ref.read(settingsProvider.notifier).setSearchProvider(providerId);
        onProviderChanged?.call();
      },
      itemBuilder: (context) => [
        ...searchProviders.map(
          (ext) {
            return PopupMenuItem<String>(
              value: ext.id,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 52,
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: sourceIcon(ext.id) != Icons.extension || sourceIcon(ext.displayName) != Icons.extension
                        ? _buildFallbackIcon(ext, colorScheme, size: 16)
                        : ext.iconPath != null && ext.iconPath!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(ext.iconPath!),
                                  width: 32, height: 32,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, a, b) => _buildFallbackIcon(ext, colorScheme, size: 16),
                                ),
                              )
                            : _buildFallbackIcon(ext, colorScheme, size: 16),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      ext.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: currentProvider == ext.id
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: currentProvider == ext.id
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (currentProvider == ext.id)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, size: 13, color: colorScheme.primary),
                    ),
                ],
              ),
            );
          },
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18, height: 18,
              child: currentExt != null && (sourceIcon(currentExt.id) != Icons.extension || sourceIcon(currentExt.displayName) != Icons.extension)
                ? _buildFallbackIcon(currentExt, colorScheme, size: 14)
                : iconPath != null && iconPath.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(iconPath),
                          width: 18, height: 18,
                          fit: BoxFit.cover,
                          errorBuilder: (_, a, b) => currentExt != null
                            ? _buildFallbackIcon(currentExt, colorScheme, size: 14)
                            : Icon(Icons.search, size: 14, color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : currentExt != null
                      ? _buildFallbackIcon(currentExt, colorScheme, size: 14)
                      : Icon(Icons.search, size: 14, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _GlassFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme colorScheme;
  final IconData? icon;
  final VoidCallback onTap;

  const _GlassFilterChip({
    required this.label,
    required this.selected,
    required this.colorScheme,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.2)
              : colorScheme.surface.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.10),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.transparent),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon!, size: 16,
                      color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackItemWithStatus extends ConsumerStatefulWidget {
  final Track track;
  final int index;
  final VoidCallback onDownload;
  final String? searchExtensionId;
  final bool showLocalLibraryIndicator;
  final Map<String, (double, double)> thumbnailSizesByExtensionId;

  const _TrackItemWithStatus({
    super.key,
    required this.track,
    required this.index,
    required this.onDownload,
    required this.searchExtensionId,
    required this.showLocalLibraryIndicator,
    required this.thumbnailSizesByExtensionId,
  });

  @override
  ConsumerState<_TrackItemWithStatus> createState() => _TrackItemWithStatusState();
}

class _TrackItemWithStatusState extends ConsumerState<_TrackItemWithStatus> {
  late Track _currentTrack;

  @override
  void initState() {
    super.initState();
    _currentTrack = widget.track;
  }

  @override
  void didUpdateWidget(_TrackItemWithStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.track != oldWidget.track) {
      _currentTrack = widget.track;
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = _currentTrack;
    final queueItem = ref.watch(
      downloadQueueLookupProvider.select(
        (lookup) => lookup.byTrackId[track.id],
      ),
    );

    final historyLookup = historyLookupForTrack(track);
    final isInHistory = ref
        .watch(downloadHistoryExistsProvider(historyLookup))
        .maybeWhen(data: (exists) => exists, orElse: () => false);

    final isInLocalLibrary = widget.showLocalLibraryIndicator
        ? ref.watch(
            localLibraryProvider.select(
              (state) => state.existsInLibrary(
                isrc: track.isrc,
                trackName: track.name,
                artistName: track.artistName,
              ),
            ),
          )
        : false;

    double thumbWidth = 56;

    final extensionId = track.source ?? widget.searchExtensionId;
    final thumbSize = extensionId == null
        ? null
        : widget.thumbnailSizesByExtensionId[extensionId];
    if (thumbSize != null) {
      thumbWidth = thumbSize.$1;
    }

    final isQueued = queueItem != null;
    final hasLocalFile = isInHistory || isInLocalLibrary;
    final progress = isQueued ? 0.5 : (hasLocalFile ? 1.0 : 0.0);

    return TrackCard(
      track: track,
      coverSize: thumbWidth,
      downloadProgress: progress,
      showHeartButton: true,
      showInfoButton: true,
      showQualityBadge: true,
      showStatusDot: true,
      onDownload: hasLocalFile ? null : widget.onDownload,
      onTap: () => _handleTap(
        context,
        ref,
        isQueued: isQueued,
        isInHistory: isInHistory,
        isInLocalLibrary: isInLocalLibrary,
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    WidgetRef ref, {
    required bool isQueued,
    required bool isInHistory,
    required bool isInLocalLibrary,
  }) async {
    final track = _currentTrack;
    if (isQueued) return;

    ref.read(recentAccessProvider.notifier).recordTrackAccess(
      id: track.id,
      name: track.name,
      artistName: track.artistName,
      imageUrl: track.coverUrl,
      providerId: track.source ?? 'deezer',
    );

    if (isInHistory) {
      final hist = ref.read(downloadHistoryProvider).findByTrackAndArtist(track.name, track.artistName);
      if (hist != null) {
        final file = File(hist.filePath);
        if (await file.exists()) {
          await ref.read(playbackProvider.notifier).playLocalPath(path: hist.filePath, title: hist.trackName, artist: hist.artistName, album: hist.albumName, coverUrl: track.coverUrl ?? '');
          return;
        }
      }
    }
    if (isInLocalLibrary) {
      final local = ref.read(localLibraryProvider).allTracks.where((t) =>
        t.trackName == track.name && t.artistName == track.artistName
      ).firstOrNull;
      if (local != null && await File(local.filePath).exists()) {
        await ref.read(playbackProvider.notifier).playLocalPath(path: local.filePath, title: local.trackName, artist: local.artistName, album: local.albumName, coverUrl: track.coverUrl ?? '');
        return;
      }
    }

    final player = ref.read(audioPlayerProvider.notifier);
    debugPrint('[HomeTab] TAP: calling player.play(${track.name} - ${track.artistName})');
    await player.stop();

    // Reproducir INMEDIATAMENTE
    await player.play(
      trackId: track.id,
      trackName: track.name,
      artistName: track.artistName,
      albumName: track.albumName,
      coverUrl: track.coverUrl,
      provider: track.source ?? 'deezer',
      isrc: track.isrc,
    );

    // Pre-cargar video y letra EN PARALELO (sin bloquear el audio)
    Future(() {
      player.prefetchVideo(track.name, track.artistName);
      ref.read(lyricsProvider.notifier).fetchForTrack(
        trackId: track.id,
        trackName: track.name,
        artistName: track.artistName,
        durationMs: 0,
      );
    });
  }
}

/// Widget for displaying album/playlist items in search results
class _CollectionItemWidget extends StatelessWidget {
  final Track item;
  final bool showDivider;
  final VoidCallback onTap;

  const _CollectionItemWidget({
    required this.item,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPlaylist = item.isPlaylistItem;
    final isArtist = item.isArtistItem;

    IconData placeholderIcon = Icons.album;
    if (isPlaylist) placeholderIcon = Icons.playlist_play;
    if (isArtist) placeholderIcon = Icons.person;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          splashColor: colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: colorScheme.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(isArtist ? 28 : 10),
                  child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                      ? CachedCoverImage(
                          imageUrl: item.coverUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            placeholderIcon,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.artistName.isNotEmpty
                            ? item.artistName
                            : (isPlaylist
                                  ? 'Lista'
                                  : (isArtist ? 'Artista' : 'Álbum')),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 80,
            endIndent: 12,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

/// Widget for displaying artist items from search results
class _SearchArtistItemWidget extends ConsumerWidget {
  final SearchArtist artist;
  final bool showDivider;
  final VoidCallback onTap;

  const _SearchArtistItemWidget({
    required this.artist,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasValidImage =
        artist.imageUrl != null &&
        artist.imageUrl!.isNotEmpty &&
        Uri.tryParse(artist.imageUrl!)?.hasAuthority == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          splashColor: colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: colorScheme.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: hasValidImage
                      ? CachedCoverImage(
                          imageUrl: artist.imageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.person,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${artist.followers} followers',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 80,
            endIndent: 12,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

/// Widget for displaying album items from search results
class _SearchAlbumItemWidget extends ConsumerWidget {
  final SearchAlbum album;
  final bool showDivider;
  final VoidCallback onTap;

  const _SearchAlbumItemWidget({
    required this.album,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasValidImage =
        album.imageUrl != null &&
        album.imageUrl!.isNotEmpty &&
        Uri.tryParse(album.imageUrl!)?.hasAuthority == true;

    final historyState = ref.watch(downloadHistoryProvider);
    final isDownloaded = historyState.items.any((h) => h.albumName.toLowerCase() == album.name.toLowerCase());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          splashColor: colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: colorScheme.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      hasValidImage
                          ? CachedCoverImage(
                              imageUrl: album.imageUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.album,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                      if (isDownloaded)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(Icons.download_done, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      ClickableArtistName(
                        artistName: album.artists.isNotEmpty
                            ? album.artists
                            : 'Álbum',
                        coverUrl: album.imageUrl,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 80,
            endIndent: 12,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

/// Widget for displaying playlist items from default search (Deezer/Spotify)
class _SearchPlaylistItemWidget extends ConsumerWidget {
  final SearchPlaylist playlist;
  final bool showDivider;
  final VoidCallback onTap;

  const _SearchPlaylistItemWidget({
    required this.playlist,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasValidImage =
        playlist.imageUrl != null &&
        playlist.imageUrl!.isNotEmpty &&
        Uri.tryParse(playlist.imageUrl!)?.hasAuthority == true;

    final libraryState = ref.watch(libraryCollectionsProvider);
    final isLoved = libraryState.favoritePlaylists.any((p) => p.playlistId == playlist.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          splashColor: colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: colorScheme.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: hasValidImage
                      ? CachedCoverImage(
                          imageUrl: playlist.imageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.playlist_play,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        playlist.owner.isNotEmpty ? playlist.owner : 'Lista',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 80,
            endIndent: 12,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

class _DownloadedOrRemoteCover extends StatefulWidget {
  final String? downloadedFilePath;
  final String? imageUrl;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;
  final double fallbackIconSize;
  final ColorScheme colorScheme;

  const _DownloadedOrRemoteCover({
    required this.downloadedFilePath,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.fallbackIcon,
    required this.colorScheme,
    this.fallbackIconSize = 24,
  });

  @override
  State<_DownloadedOrRemoteCover> createState() =>
      _DownloadedOrRemoteCoverState();
}

class _DownloadedOrRemoteCoverState extends State<_DownloadedOrRemoteCover> {
  String? _embeddedCoverPath;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _embeddedCoverPath = _resolveEmbeddedCoverPath();
  }

  @override
  void didUpdateWidget(covariant _DownloadedOrRemoteCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.downloadedFilePath != widget.downloadedFilePath ||
        oldWidget.imageUrl != widget.imageUrl) {
      final nextPath = _resolveEmbeddedCoverPath();
      if (nextPath != _embeddedCoverPath) {
        setState(() => _embeddedCoverPath = nextPath);
      }
    }
  }

  String? _resolveEmbeddedCoverPath() {
    final filePath = widget.downloadedFilePath;
    if (filePath == null || filePath.isEmpty) return null;
    return DownloadedEmbeddedCoverResolver.resolve(
      filePath,
      onChanged: _onEmbeddedCoverChanged,
    );
  }

  void _onEmbeddedCoverChanged() {
    if (!mounted || _refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (!mounted) return;
      final nextPath = _resolveEmbeddedCoverPath();
      if (nextPath != _embeddedCoverPath) {
        setState(() => _embeddedCoverPath = nextPath);
      }
    });
  }

  Widget _fallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.colorScheme.surfaceContainerHighest,
      child: Icon(
        widget.fallbackIcon,
        color: widget.colorScheme.onSurfaceVariant,
        size: widget.fallbackIconSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (widget.width * 2).round();
    final cacheHeight = (widget.height * 2).round();

    Widget child;
    if (_embeddedCoverPath != null) {
      child = Image.file(
        File(_embeddedCoverPath!),
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => _fallback(),
      );
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      child = CachedCoverImage(
        imageUrl: widget.imageUrl!,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        errorWidget: (_, _, _) => _fallback(),
      );
    } else {
      child = _fallback();
    }

    return ClipRRect(borderRadius: widget.borderRadius, child: child);
  }
}

class ExtensionAlbumScreen extends ConsumerStatefulWidget {
  final String extensionId;
  final String albumId;
  final String albumName;
  final String? coverUrl;
  final String? initialAlbumType;
  final int? initialTotalTracks;

  const ExtensionAlbumScreen({
    super.key,
    required this.extensionId,
    required this.albumId,
    required this.albumName,
    this.coverUrl,
    this.initialAlbumType,
    this.initialTotalTracks,
  });

  @override
  ConsumerState<ExtensionAlbumScreen> createState() =>
      _ExtensionAlbumScreenState();
}

class _ExtensionAlbumScreenState extends ConsumerState<ExtensionAlbumScreen> {
  List<Track>? _tracks;
  bool _isLoading = true;
  String? _error;
  String? _artistId;
  String? _artistName;
  String? _albumType;
  int? _albumTotalTracks;

  @override
  void initState() {
    super.initState();
    _albumType = normalizeOptionalString(widget.initialAlbumType);
    _albumTotalTracks = widget.initialTotalTracks;
    _fetchTracks();
  }

  Future<void> _fetchTracks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await PlatformBridge.getProviderMetadata(
        widget.extensionId,
        'album',
        widget.albumId,
      );
      if (!mounted) return;

      final albumInfo = result['album_info'] as Map<String, dynamic>? ?? result;
      final trackList =
          result['track_list'] as List<dynamic>? ??
          result['tracks'] as List<dynamic>?;
      if (trackList == null) {
        setState(() {
          _error = context.l10n.errorNoTracksFound;
          _isLoading = false;
        });
        return;
      }

      final artistId = (albumInfo['artist_id'] ?? albumInfo['artistId'])
          ?.toString();
      final artistName = (albumInfo['artists'] ?? albumInfo['artist'])
          ?.toString();
      final albumType =
          normalizeOptionalString(albumInfo['album_type']?.toString()) ??
          _albumType;
      final totalTracks =
          albumInfo['total_tracks'] as int? ?? _albumTotalTracks;
      final tracks = trackList
          .map(
            (t) => _parseTrack(
              t as Map<String, dynamic>,
              albumTypeFallback: albumType,
              totalTracksFallback: totalTracks,
            ),
          )
          .toList();

      setState(() {
        _tracks = tracks;
        _artistId = artistId;
        _artistName = artistName;
        _albumType = albumType;
        _albumTotalTracks = totalTracks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.snackbarError(e.toString());
        _isLoading = false;
      });
    }
  }

  Track _parseTrack(
    Map<String, dynamic> data, {
    String? albumTypeFallback,
    int? totalTracksFallback,
  }) {
    int durationMs = 0;
    final durationValue = data['duration_ms'];
    if (durationValue is int) {
      durationMs = durationValue;
    } else if (durationValue is double) {
      durationMs = durationValue.toInt();
    }

    return Track(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      artistName: (data['artists'] ?? data['artist'] ?? '').toString(),
      albumName: (data['album_name'] ?? widget.albumName).toString(),
      albumArtist: normalizeOptionalString(data['album_artist']?.toString()),
      artistId:
          (data['artist_id'] ?? data['artistId'])?.toString() ?? _artistId,
      albumId: data['album_id']?.toString() ?? widget.albumId,
      coverUrl: _resolveCoverUrl(
        data['cover_url']?.toString(),
        widget.coverUrl,
      ),
      isrc: data['isrc']?.toString(),
      duration: (durationMs / 1000).round(),
      trackNumber: data['track_number'] as int?,
      discNumber: data['disc_number'] as int?,
      totalDiscs: data['total_discs'] as int?,
      releaseDate: data['release_date']?.toString(),
      albumType:
          normalizeOptionalString(data['album_type']?.toString()) ??
          albumTypeFallback ??
          _albumType,
      totalTracks:
          data['total_tracks'] as int? ??
          totalTracksFallback ??
          _albumTotalTracks,
      composer: data['composer']?.toString(),
      source: widget.extensionId,
      audioQuality: data['audio_quality']?.toString(),
      audioModes: data['audio_modes']?.toString(),
    );
  }

  String? _resolveCoverUrl(String? trackCover, String? albumCover) {
    if (trackCover != null && trackCover.isNotEmpty) return trackCover;
    return albumCover;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.albumName)),
        body: const AlbumTrackListSkeleton(
          itemCount: 10,
          showCoverHeader: true,
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.albumName)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchTracks,
                child: Text(context.l10n.dialogRetry),
              ),
            ],
          ),
        ),
      );
    }

    return AlbumScreen(
      albumId: widget.albumId,
      albumName: widget.albumName,
      coverUrl: widget.coverUrl,
      tracks: _tracks,
      extensionId: widget.extensionId,
      artistId: _artistId,
      artistName: _artistName,
    );
  }
}

/// Screen for viewing extension playlist with track fetching
class ExtensionPlaylistScreen extends ConsumerStatefulWidget {
  final String extensionId;
  final String playlistId;
  final String playlistName;
  final String? coverUrl;

  const ExtensionPlaylistScreen({
    super.key,
    required this.extensionId,
    required this.playlistId,
    required this.playlistName,
    this.coverUrl,
  });

  @override
  ConsumerState<ExtensionPlaylistScreen> createState() =>
      _ExtensionPlaylistScreenState();
}

class _ExtensionPlaylistScreenState
    extends ConsumerState<ExtensionPlaylistScreen> {
  List<Track>? _tracks;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTracks();
  }

  Future<void> _fetchTracks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await PlatformBridge.getProviderMetadata(
        widget.extensionId,
        'playlist',
        widget.playlistId,
      );
      if (!mounted) return;

      final trackList =
          result['track_list'] as List<dynamic>? ??
          result['tracks'] as List<dynamic>?;
      if (trackList == null) {
        setState(() {
          _error = context.l10n.errorNoTracksFound;
          _isLoading = false;
        });
        return;
      }

      final tracks = trackList
          .map((t) => _parseTrack(t as Map<String, dynamic>))
          .toList();

      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.snackbarError(e.toString());
        _isLoading = false;
      });
    }
  }

  Track _parseTrack(Map<String, dynamic> data) {
    int durationMs = 0;
    final durationValue = data['duration_ms'];
    if (durationValue is int) {
      durationMs = durationValue;
    } else if (durationValue is double) {
      durationMs = durationValue.toInt();
    }

    return Track(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      artistName: (data['artists'] ?? data['artist'] ?? '').toString(),
      albumName: (data['album_name'] ?? '').toString(),
      artistId: (data['artist_id'] ?? data['artistId'])?.toString(),
      albumId: data['album_id']?.toString(),
      coverUrl: _resolveCoverUrl(
        data['cover_url']?.toString(),
        widget.coverUrl,
      ),
      isrc: data['isrc']?.toString(),
      duration: (durationMs / 1000).round(),
      trackNumber: data['track_number'] as int?,
      discNumber: data['disc_number'] as int?,
      totalDiscs: data['total_discs'] as int?,
      releaseDate: data['release_date']?.toString(),
      totalTracks: data['total_tracks'] as int?,
      composer: data['composer']?.toString(),
      source: widget.extensionId,
      audioQuality: data['audio_quality']?.toString(),
      audioModes: data['audio_modes']?.toString(),
    );
  }

  String? _resolveCoverUrl(String? trackCover, String? playlistCover) {
    if (trackCover != null && trackCover.isNotEmpty) return trackCover;
    return playlistCover;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.playlistName)),
        body: const TrackListSkeleton(itemCount: 8, showCoverHeader: true),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.playlistName)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchTracks,
                child: Text(context.l10n.dialogRetry),
              ),
            ],
          ),
        ),
      );
    }

    return PlaylistScreen(
      playlistName: widget.playlistName,
      coverUrl: widget.coverUrl,
      tracks: _tracks!,
      recommendedService: widget.extensionId,
    );
  }
}

class ExtensionArtistScreen extends ConsumerStatefulWidget {
  final String extensionId;
  final String artistId;
  final String artistName;
  final String? coverUrl;

  const ExtensionArtistScreen({
    super.key,
    required this.extensionId,
    required this.artistId,
    required this.artistName,
    this.coverUrl,
  });

  @override
  ConsumerState<ExtensionArtistScreen> createState() =>
      _ExtensionArtistScreenState();
}

class _ExtensionArtistScreenState extends ConsumerState<ExtensionArtistScreen> {
  List<ArtistAlbum>? _albums;
  List<Track>? _topTracks;
  String? _headerImageUrl;
  int? _monthlyListeners;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchArtist();
  }

  Future<void> _fetchArtist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await PlatformBridge.getProviderMetadata(
        widget.extensionId,
        'artist',
        widget.artistId,
      );
      if (!mounted) return;

      final artistInfo =
          result['artist_info'] as Map<String, dynamic>? ?? result;
      final albumList = result['albums'] as List<dynamic>?;
      final albums =
          albumList
              ?.map((a) => _parseAlbum(a as Map<String, dynamic>))
              .toList() ??
          [];

      final topTracksList = result['top_tracks'] as List<dynamic>?;
      List<Track>? topTracks;
      if (topTracksList != null && topTracksList.isNotEmpty) {
        topTracks = topTracksList
            .map((t) => _parseTrack(t as Map<String, dynamic>))
            .toList();
      }

      final headerImage =
          artistInfo['images'] as String? ??
          artistInfo['header_image'] as String? ??
          artistInfo['cover_url'] as String? ??
          result['header_image'] as String?;
      final listeners =
          artistInfo['listeners'] as int? ?? result['listeners'] as int?;

      setState(() {
        _albums = albums;
        _topTracks = topTracks;
        _headerImageUrl = headerImage;
        _monthlyListeners = listeners;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.snackbarError(e.toString());
        _isLoading = false;
      });
    }
  }

  ArtistAlbum _parseAlbum(Map<String, dynamic> data) {
    return ArtistAlbum(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      artists: (data['artists'] ?? '').toString(),
      releaseDate: (data['release_date'] ?? '').toString(),
      totalTracks: data['total_tracks'] as int? ?? 0,
      coverUrl: normalizeCoverReference(data['cover_url']?.toString()),
      albumType: (data['album_type'] ?? 'album').toString(),
      providerId: (data['provider_id'] ?? widget.extensionId).toString(),
    );
  }

  Track _parseTrack(Map<String, dynamic> data) {
    int durationMs = 0;
    final durationValue = data['duration_ms'];
    if (durationValue is int) {
      durationMs = durationValue;
    } else if (durationValue is double) {
      durationMs = durationValue.toInt();
    }

    return Track(
      id: (data['id'] ?? data['spotify_id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      artistName: (data['artists'] ?? data['artist'] ?? '').toString(),
      albumName: (data['album_name'] ?? data['album'] ?? '').toString(),
      albumArtist: data['album_artist']?.toString(),
      artistId:
          (data['artist_id'] ?? data['artistId'])?.toString() ??
          widget.artistId,
      albumId: data['album_id']?.toString(),
      coverUrl: normalizeCoverReference(
        (data['cover_url'] ?? data['images'])?.toString(),
      ),
      isrc: data['isrc']?.toString(),
      duration: (durationMs / 1000).round(),
      trackNumber: data['track_number'] as int?,
      discNumber: data['disc_number'] as int?,
      totalDiscs: data['total_discs'] as int?,
      releaseDate: data['release_date']?.toString(),
      totalTracks: data['total_tracks'] as int?,
      composer: data['composer']?.toString(),
      source: (data['provider_id'] ?? widget.extensionId).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.artistName)),
        body: const ArtistScreenSkeleton(),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.artistName)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchArtist,
                child: Text(context.l10n.dialogRetry),
              ),
            ],
          ),
        ),
      );
    }

    return ArtistScreen(
      artistId: widget.artistId,
      artistName: widget.artistName,
      coverUrl: widget.coverUrl,
      headerImageUrl: _headerImageUrl,
      monthlyListeners: _monthlyListeners,
      albums: _albums,
      topTracks: _topTracks,
      extensionId: widget.extensionId, // Skip Spotify/Deezer fetch
    );
  }
}

/// Swipeable Quick Picks widget with page indicator
class _QuickPicksPageView extends StatefulWidget {
  final ExploreSection section;
  final ColorScheme colorScheme;
  final int itemsPerPage;
  final int totalPages;
  final String localizedTitle;
  final void Function(ExploreItem) onItemTap;
  final void Function(ExploreItem) onItemMenu;

  const _QuickPicksPageView({
    required this.section,
    required this.colorScheme,
    required this.itemsPerPage,
    required this.totalPages,
    required this.localizedTitle,
    required this.onItemTap,
    required this.onItemMenu,
  });

  @override
  State<_QuickPicksPageView> createState() => _QuickPicksPageViewState();
}

class _QuickPicksPageViewState extends State<_QuickPicksPageView> {
  int _currentPage = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            widget.localizedTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: widget.itemsPerPage * 64.0,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.totalPages,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
            },
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * widget.itemsPerPage;
              final endIndex = (startIndex + widget.itemsPerPage).clamp(
                0,
                widget.section.items.length,
              );
              final pageItemCount = endIndex - startIndex;

              return Column(
                children: List.generate(pageItemCount, (index) {
                  final item = widget.section.items[startIndex + index];
                  return KeyedSubtree(
                    key: ValueKey(
                      'quick-pick-${item.type}-${item.id}-${item.uri}',
                    ),
                    child: _buildQuickPickItem(item),
                  );
                }),
              );
            },
          ),
        ),
        if (widget.totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.totalPages, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isActive ? 8 : 6,
                  height: isActive ? 8 : 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? widget.colorScheme.primary
                        : widget.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.3,
                          ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickPickItem(ExploreItem item) {
    return InkWell(
      onTap: () => widget.onItemTap(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                  ? CachedCoverImage(
                      imageUrl: item.coverUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        width: 48,
                        height: 48,
                        color: widget.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.music_note,
                          color: widget.colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: widget.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.music_note,
                        color: widget.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: widget.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (item.description != null && item.description!.isNotEmpty)
                    Text(
                      item.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              icon: Icon(
                Icons.more_vert,
                color: widget.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () => widget.onItemMenu(item),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}
