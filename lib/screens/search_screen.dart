import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/providers/lyrics_provider.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/track_provider.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/theme/app_theme.dart';
import 'package:bitly/widgets/animation_utils.dart';
import 'package:bitly/widgets/network_status.dart';
import 'package:bitly/widgets/track_card.dart';
import 'package:bitly/widgets/glass_container.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String query;

  const SearchScreen({super.key, required this.query});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
    if (widget.query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(trackProvider.notifier).search(widget.query);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(trackProvider.notifier).search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimaryLight,
      appBar: AppBar(
        backgroundColor: isDark 
            ? AppTheme.surfaceDark.withOpacity(0.8) 
            : AppTheme.surfaceLight.withOpacity(0.8),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppTheme.glassBorderDark : AppTheme.glassBorderLight,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: context.l10n.searchTracksHint,
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => _search(),
                  autofocus: widget.query.isEmpty,
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  child: Icon(
                    Icons.clear,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          const NetworkStatusIcon(),
          IconButton(
            tooltip: MaterialLocalizations.of(context).searchFieldLabel,
            icon: Icon(
              Icons.search,
              color: colorScheme.primary,
              size: 24,
            ),
            onPressed: _search,
          ),
        ],
      ),
      body: _SearchResultsBody(),
    );
  }
}

class _SearchResultsBody extends ConsumerWidget {
  const _SearchResultsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(trackProvider.select((s) => s.tracks));
    final isLoading = ref.watch(trackProvider.select((s) => s.isLoading));
    final error = ref.watch(trackProvider.select((s) => s.error));
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.gradientDark : AppTheme.gradientLight,
      ),
      child: Column(
        children: [
          if (isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                color: colorScheme.primary,
                backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: NeonCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.error,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: AnimatedStateSwitcher(
              child: isLoading && tracks.isEmpty
                  ? const TrackListSkeleton(key: ValueKey('loading'))
                  : tracks.isEmpty
                  ? _SearchEmptyState(
                      key: const ValueKey('empty'),
                      colorScheme: colorScheme,
                      isDark: isDark,
                    )
                  : ListView.builder(
                      key: const ValueKey('results'),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: tracks.length,
                      itemBuilder: (context, index) => StaggeredListItem(
                        key: ValueKey('search-track-${tracks[index].id}-$index'),
                        index: index,
                        child: _SearchTrackTile(track: tracks[index]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool isDark;

  const _SearchEmptyState({super.key, required this.colorScheme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: NeonCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: colorScheme.onSurfaceVariant,
              shadows: [
                Shadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.2) : AppTheme.primaryLight.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.searchTracksEmptyPrompt,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchTrackTile extends ConsumerWidget {
  final Track track;

  const _SearchTrackTile({required this.track});

  void _handleTap(BuildContext context, WidgetRef ref) {
    // Reproducir INMEDIATAMENTE
    ref.read(audioPlayerProvider.notifier).play(
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
      ref.read(audioPlayerProvider.notifier).prefetchVideo(track.name, track.artistName);
      ref.read(lyricsProvider.notifier).fetchForTrack(
        trackId: track.id,
        trackName: track.name,
        artistName: track.artistName,
        durationMs: 0,
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Download history check
    final historyState = ref.watch(downloadHistoryProvider);
    final isLocal = historyState.findByNormalizedName(
      track.name, track.artistName,
    ) != null;

    // Queue check
    final queueLookup = ref.watch(downloadQueueLookupProvider);
    var isQueued = queueLookup.byTrackId.containsKey(track.id);
    if (!isQueued) {
      isQueued = queueLookup.byNormalizedName.containsKey(
        '${normalizeForMatch(track.name)}|${normalizeForMatch(track.artistName)}',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TrackCard(
        track: track,
        showHeartButton: true,
        showInfoButton: false,
        showQualityBadge: true,
        showStatusDot: true,
        downloadProgress: isLocal ? 1.0 : (isQueued ? 0.5 : 0.0),
        onTap: () => _handleTap(context, ref),
      ),
    );
  }
}
