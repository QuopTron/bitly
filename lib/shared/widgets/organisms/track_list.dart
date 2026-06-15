import 'package:flutter/material.dart';
import '../molecules/track_list_tile.dart';

class Track {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String? quality;
  final String? coverUrl;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    this.quality,
    this.coverUrl,
  });
}

class TrackList extends StatelessWidget {
  final List<Track> tracks;
  final String? playingTrackId;
  final void Function(Track track)? onTrackTap;
  final void Function(Track track)? onTrackMenu;

  const TrackList({
    super.key,
    required this.tracks,
    this.playingTrackId,
    this.onTrackTap,
    this.onTrackMenu,
  });

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return const Center(child: Text('No tracks'));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tracks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final track = tracks[index];
        return TrackListTile(
          title: track.title,
          artist: track.artist,
          duration: track.duration,
          quality: track.quality,
          coverUrl: track.coverUrl,
          isPlaying: track.id == playingTrackId,
          onTap: () => onTrackTap?.call(track),
          onMenu: () => onTrackMenu?.call(track),
        );
      },
    );
  }
}
