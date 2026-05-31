import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/library_collections_provider.dart';
import 'package:bitly/services/biblioteca/portadas/cover_cache_manager.dart';

Future<void> showAddTrackToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  return showAddTracksToPlaylistSheet(context, ref, [track]);
}

Future<void> showAddTracksToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  List<Track> tracks, {
  String? playlistNamePrefill,
}) async {
  if (tracks.isEmpty) return;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _PlaylistPickerSheetContent(
      tracks: tracks,
      playlistNamePrefill: playlistNamePrefill,
    ),
  );
}

class _PlaylistPickerSheetContent extends ConsumerStatefulWidget {
  final List<Track> tracks;
  final String? playlistNamePrefill;

  const _PlaylistPickerSheetContent({
    required this.tracks,
    this.playlistNamePrefill,
  });

  @override
  ConsumerState<_PlaylistPickerSheetContent> createState() =>
      _PlaylistPickerSheetContentState();
}

class _PlaylistPickerSheetContentState
    extends ConsumerState<_PlaylistPickerSheetContent> {
  late final PlaylistPickerSummaryRequest _summaryRequest;
  final Set<String> _selectedPlaylistIds = {};
  final Set<String> _committedPlaylistIds = {};

  @override
  void initState() {
    super.initState();
    _summaryRequest = PlaylistPickerSummaryRequest.fromTracks(widget.tracks);
  }

  void _handleDone(List<PlaylistPickerSummary> playlists) async {
    final notifier = ref.read(libraryCollectionsProvider.notifier);
    final effectiveDisabledIds = <String>{
      ..._committedPlaylistIds,
      for (final playlist in playlists)
        if (playlist.containsAllRequestedTracks) playlist.id,
    };
    final idsToAdd = _selectedPlaylistIds.difference(effectiveDisabledIds);
    final playlistNamesById = {
      for (final playlist in playlists) playlist.id: playlist.name,
    };
    final addedNames = <String>[];

    for (final playlistId in idsToAdd) {
      final playlistName = playlistNamesById[playlistId];
      if (playlistName != null && playlistName.isNotEmpty) {
        addedNames.add(playlistName);
      }
      await notifier.addTracksToPlaylist(playlistId, widget.tracks);
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    if (addedNames.isNotEmpty) {
      final name = addedNames.length == 1
          ? addedNames.first
          : addedNames.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.collectionAddedToPlaylist(name))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistSummariesValue = ref.watch(
      libraryPlaylistPickerSummariesProvider(_summaryRequest),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final firstTrack = widget.tracks.isNotEmpty ? widget.tracks.first : null;
    final coverUrl = firstTrack?.coverUrl;

    final String subtitle;
    if (widget.tracks.length == 1) {
      final track = widget.tracks.first;
      subtitle = '${track.name} • ${track.artistName}';
    } else {
      subtitle =
          '${widget.tracks.length} ${widget.tracks.length == 1 ? 'track' : 'tracks'}';
    }

    final resolvedPlaylists = playlistSummariesValue.asData?.value ?? const [];
    final effectiveDisabledIds = <String>{
      ..._committedPlaylistIds,
      for (final playlist in resolvedPlaylists)
        if (playlist.containsAllRequestedTracks) playlist.id,
    };
    final idsToAdd = _selectedPlaylistIds.difference(effectiveDisabledIds);
    final hasNewSelections = idsToAdd.isNotEmpty;

    return _GlassSheet(
      coverUrl: coverUrl,
      colorScheme: colorScheme,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // track header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  if (firstTrack != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: firstTrack.coverUrl != null && firstTrack.coverUrl!.isNotEmpty
                            ? _buildCoverThumb(firstTrack.coverUrl!, 40)
                            : Container(
                                width: 40,
                                height: 40,
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(Icons.music_note, size: 18, color: colorScheme.onSurfaceVariant),
                              ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.collectionAddToPlaylist,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
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
            // create playlist tile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: _GlassTile(
                onTap: () => _showCreatePlaylistModal(),
                colorScheme: colorScheme,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.add_circle_outline, size: 18, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.collectionCreatePlaylist,
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: colorScheme.primary),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: colorScheme.primary.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
            // playlists list
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: playlistSummariesValue.when(
                  data: (playlists) {
                    if (playlists.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Text(
                          context.l10n.collectionNoPlaylistsYet,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        final isAlreadyIn = effectiveDisabledIds.contains(playlist.id);
                        final isSelected = _selectedPlaylistIds.contains(playlist.id) || isAlreadyIn;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: _GlassTile(
                            onTap: !isAlreadyIn
                                ? () => setState(() {
                                      if (_selectedPlaylistIds.contains(playlist.id)) {
                                        _selectedPlaylistIds.remove(playlist.id);
                                      } else {
                                        _selectedPlaylistIds.add(playlist.id);
                                      }
                                    })
                                : null,
                            color: isSelected ? colorScheme.primary.withValues(alpha: 0.05) : null,
                            colorScheme: colorScheme,
                            child: Row(
                              children: [
                                _PlaylistPickerThumbnail(
                                  playlist: playlist,
                                  isSelected: isSelected,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        playlist.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                          color: isAlreadyIn ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        context.l10n.collectionPlaylistTracks(playlist.trackCount),
                                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isAlreadyIn)
                                  Icon(Icons.check_circle, size: 18, color: colorScheme.primary.withValues(alpha: 0.5))
                                else if (isSelected)
                                  Icon(Icons.check_circle, size: 18, color: colorScheme.primary)
                                else
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: colorScheme.outlineVariant, width: 2),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, _) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Text(
                      context.l10n.collectionNoPlaylistsYet,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (hasNewSelections) {
                      _handleDone(resolvedPlaylists);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(context.l10n.dialogDone),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverThumb(String url, double size) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheManager: CoverCacheManager.instance,
        errorWidget: (_, _, _) => Container(
          width: size, height: size,
          color: colorScheme.surfaceContainerHighest,
          child: Icon(Icons.music_note, size: size * 0.4, color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    return Image.file(
      File(url),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: size, height: size,
        color: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.music_note, size: size * 0.4, color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  void _showCreatePlaylistModal() async {
    final coverUrl = widget.tracks.isNotEmpty ? widget.tracks.first.coverUrl : null;
    final name = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CreatePlaylistSheet(
        coverUrl: coverUrl,
        prefill: widget.playlistNamePrefill,
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      if (!mounted) return;
      final notifier = ref.read(libraryCollectionsProvider.notifier);
      final playlist = await notifier.createPlaylist(name.trim());
      await notifier.addTracksToPlaylist(playlist.id, widget.tracks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.collectionAddedToPlaylist(name.trim()))),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _CreatePlaylistSheet extends StatefulWidget {
  final String? coverUrl;
  final String? prefill;

  const _CreatePlaylistSheet({
    this.coverUrl,
    this.prefill,
  });

  @override
  State<_CreatePlaylistSheet> createState() => _CreatePlaylistSheetState();
}

class _CreatePlaylistSheetState extends State<_CreatePlaylistSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.prefill ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _GlassSheet(
      coverUrl: widget.coverUrl,
      colorScheme: colorScheme,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.playlist_add, size: 28, color: colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.collectionCreatePlaylist,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.collectionPlaylistNameHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: context.l10n.collectionPlaylistNameHint,
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return context.l10n.collectionPlaylistNameRequired;
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (_formKey.currentState?.validate() != true) return;
                    Navigator.of(context).pop(_controller.text.trim());
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(context.l10n.dialogCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          if (_formKey.currentState?.validate() != true) return;
                          Navigator.of(context).pop(_controller.text.trim());
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(context.l10n.actionCreate),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final String? coverUrl;
  final ColorScheme colorScheme;
  final Widget child;

  const _GlassSheet({
    this.coverUrl,
    required this.colorScheme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Widget? coverWidget;
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      if (coverUrl!.startsWith('http://') || coverUrl!.startsWith('https://')) {
        coverWidget = CachedNetworkImage(
          imageUrl: coverUrl!,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          cacheManager: CoverCacheManager.instance,
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        );
      } else {
        coverWidget = Image.file(
          File(coverUrl!),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Stack(
        children: [
          if (coverWidget != null)
            Positioned.fill(child: coverWidget),
          Positioned.fill(
            child: ClipRRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(color: colorScheme.surface.withValues(alpha: 0.75)),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.5)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlassTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final ColorScheme colorScheme;

  const _GlassTile({
    required this.child,
    this.onTap,
    this.color,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color ?? colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PlaylistPickerThumbnail extends StatelessWidget {
  final PlaylistPickerSummary playlist;
  final bool isSelected;

  const _PlaylistPickerThumbnail({
    required this.playlist,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const double size = 44;
    final borderRadius = BorderRadius.circular(8);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: borderRadius,
            child: _buildCoverImage(colorScheme, size),
          ),
          if (isSelected) ...[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  borderRadius: borderRadius,
                ),
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary, width: 1.5),
                ),
                child: Icon(Icons.check, color: colorScheme.onPrimary, size: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoverImage(ColorScheme colorScheme, double size) {
    final customCoverPath = playlist.coverImagePath;
    if (customCoverPath != null && customCoverPath.isNotEmpty) {
      return Image.file(
        File(customCoverPath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _iconFallback(colorScheme, size),
      );
    }

    final firstCoverUrl = playlist.previewCover;
    if (firstCoverUrl != null) {
      final isLocalPath =
          !firstCoverUrl.startsWith('http://') &&
          !firstCoverUrl.startsWith('https://');

      if (isLocalPath) {
        return Image.file(
          File(firstCoverUrl),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _iconFallback(colorScheme, size),
        );
      }

      return CachedNetworkImage(
        imageUrl: firstCoverUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 2).toInt(),
        cacheManager: CoverCacheManager.instance,
        placeholder: (_, _) => _iconFallback(colorScheme, size),
        errorWidget: (_, _, _) => _iconFallback(colorScheme, size),
      );
    }

    return _iconFallback(colorScheme, size);
  }

  Widget _iconFallback(ColorScheme colorScheme, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.queue_music, color: colorScheme.onSurfaceVariant, size: 18),
    );
  }
}
