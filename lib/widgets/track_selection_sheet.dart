import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/widgets/cached_cover_image.dart';
import 'package:bitly/widgets/playlist_picker_sheet.dart';

/// Shows a bottom sheet with selectable tracks and adds selected ones to a playlist.
Future<void> showTrackSelectionForPlaylist(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required List<Track> tracks,
  String? subtitle,
}) async {
  final selected = await showModalBottomSheet<List<Track>>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (_) => _TrackSelectionSheet(
      title: title,
      subtitle: subtitle,
      tracks: tracks,
    ),
  );
  if (selected == null || selected.isEmpty) return;
  if (!context.mounted) return;
  showAddTracksToPlaylistSheet(context, ref, selected);
}

class _TrackSelectionSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<Track> tracks;

  const _TrackSelectionSheet({
    required this.title,
    this.subtitle,
    required this.tracks,
  });

  @override
  State<_TrackSelectionSheet> createState() => _TrackSelectionSheetState();
}

class _TrackSelectionSheetState extends State<_TrackSelectionSheet> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.tracks.map((t) => t.id).toSet();
  }

  bool get _allSelected => _selectedIds.length == widget.tracks.length;

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds = widget.tracks.map((t) => t.id).toSet();
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final selectedTracks = widget.tracks
        .where((t) => _selectedIds.contains(t.id))
        .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (widget.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Row(
              children: [
                Text(
                  '${selectedTracks.length} / ${widget.tracks.length} ${l10n.searchSongs.toLowerCase()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _toggleAll(!_allSelected),
                  icon: Icon(
                    _allSelected
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 18,
                  ),
                  label: Text(
                    _allSelected
                        ? l10n.actionDeselect
                        : l10n.actionSelectAll,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: widget.tracks.length,
              itemBuilder: (context, index) {
                final track = widget.tracks[index];
                final isSelected = _selectedIds.contains(track.id);
                return CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  secondary: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CachedCoverImage(
                        imageUrl: track.coverUrl ?? '',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  title: Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : null,
                    ),
                  ),
                  subtitle: Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: isSelected,
                  onChanged: (_) => _toggle(track.id),
                  controlAffinity: ListTileControlAffinity.trailing,
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selectedTracks.isEmpty
                    ? null
                    : () => Navigator.pop(context, selectedTracks),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: Text(
                  '${l10n.tooltipAddToPlaylist} (${selectedTracks.length})',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
