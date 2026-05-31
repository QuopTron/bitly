import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/library_collections_provider.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/local_library_provider.dart';
import 'package:bitly/widgets/cached_cover_image.dart';

class PlaylistCreatorSheet extends ConsumerStatefulWidget {
  const PlaylistCreatorSheet({super.key});

  @override
  ConsumerState<PlaylistCreatorSheet> createState() => _PlaylistCreatorSheetState();
}

class _PlaylistCreatorSheetState extends ConsumerState<PlaylistCreatorSheet> {
  final _nameController = TextEditingController();
  final Set<String> _selectedTrackKeys = {};
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final collections = ref.watch(libraryCollectionsProvider);
    final localLibrary = ref.watch(localLibraryProvider);
    final downloads = ref.watch(downloadHistoryProvider);

    // Build unified track list from liked + downloaded + local
    final allTracks = <_SelectableTrack>[];
    final seenKeys = <String>{};

    void addTrack(Track track, {String? localPath, bool isLiked = false}) {
      final key = track.isrc?.isNotEmpty == true
          ? 'isrc:${track.isrc}'
          : '${track.source ?? "unknown"}:${track.id}';
      if (seenKeys.contains(key)) return;
      seenKeys.add(key);
      allTracks.add(_SelectableTrack(
        track: track,
        localPath: localPath,
        isLiked: isLiked,
        key: key,
      ));
    }

    // Add liked tracks
    for (final entry in collections.loved) {
      addTrack(entry.track, localPath: entry.audioPath, isLiked: true);
    }

    // Add downloaded tracks
    for (final item in downloads.items) {
      final track = Track(
        id: item.spotifyId ?? 'hist_${item.id}',
        name: item.trackName,
        artistName: item.artistName,
        albumName: item.albumName,
        coverUrl: item.coverUrl,
        isrc: item.isrc,
        duration: item.duration ?? 0,
        source: item.service,
      );
      addTrack(track, localPath: item.filePath);
    }

    // Add local library tracks
    for (final item in localLibrary.items) {
      final track = Track(
        id: 'local_${item.filePath.hashCode}',
        name: item.trackName,
        artistName: item.artistName,
        albumName: item.albumName,
        coverUrl: item.coverPath,
        duration: item.duration ?? 0,
        source: 'local',
      );
      addTrack(track, localPath: item.filePath);
    }

    // Filter by search
    final filteredTracks = _searchQuery.isEmpty
        ? allTracks
        : allTracks.where((t) {
            final query = _searchQuery.toLowerCase();
            return t.track.name.toLowerCase().contains(query) ||
                t.track.artistName.toLowerCase().contains(query) ||
                t.track.albumName.toLowerCase().contains(query);
          }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Crear Lista de Reproducción',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la lista',
                        hintText: 'Mi lista increíble',
                        prefixIcon: const Icon(Icons.playlist_add),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        labelText: 'Buscar canciones',
                        hintText: 'Escribe para filtrar...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${_selectedTrackKeys.length} seleccionadas',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedTrackKeys.length == filteredTracks.length) {
                            _selectedTrackKeys.clear();
                          } else {
                            _selectedTrackKeys.addAll(filteredTracks.map((t) => t.key));
                          }
                        });
                      },
                      child: Text(
                        _selectedTrackKeys.length == filteredTracks.length
                            ? 'Deseleccionar todo'
                            : 'Seleccionar todo',
                      ),
                    ),
                  ],
                ),
              ),

              // Track list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filteredTracks.length,
                  itemBuilder: (context, index) {
                    final item = filteredTracks[index];
                    final isSelected = _selectedTrackKeys.contains(item.key);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedTrackKeys.add(item.key);
                          } else {
                            _selectedTrackKeys.remove(item.key);
                          }
                        });
                      },
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: item.track.coverUrl != null
                            ? CachedCoverImage(
                                imageUrl: item.track.coverUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 48,
                                height: 48,
                                color: colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.music_note),
                              ),
                      ),
                      title: Text(
                        item.track.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.track.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (item.isLiked)
                            Icon(Icons.favorite, size: 14, color: colorScheme.error),
                          if (item.localPath != null)
                            Icon(Icons.folder, size: 14, color: colorScheme.primary),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                        child: FilledButton(
                          onPressed: _nameController.text.trim().isEmpty
                              ? null
                              : () => _createPlaylist(filteredTracks),
                          child: Text('Crear (${_selectedTrackKeys.length} canciones)'),
                        ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _createPlaylist(List<_SelectableTrack> filteredTracks) {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final selectedTracks = filteredTracks
        .where((t) => _selectedTrackKeys.contains(t.key))
        .map((t) => t.track)
        .toList();

    ref.read(libraryCollectionsProvider.notifier).createPlaylist(name, tracks: selectedTracks);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        selectedTracks.isEmpty
            ? 'Lista "$name" creada'
            : 'Lista "$name" creada con ${selectedTracks.length} canciones',
      )),
    );
  }
}

class _SelectableTrack {
  final Track track;
  final String? localPath;
  final bool isLiked;
  final String key;

  _SelectableTrack({
    required this.track,
    this.localPath,
    required this.isLiked,
    required this.key,
  });
}
