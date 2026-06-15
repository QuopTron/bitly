import '../../../library/domain/entities/library_track.dart';

class PlaybackQueue {
  final List<LibraryTrack> tracks;
  final int currentIndex;
  final List<LibraryTrack> originalQueue;

  PlaybackQueue({
    required this.tracks,
    required this.currentIndex,
    required this.originalQueue,
  });

  LibraryTrack? get currentTrack =>
      tracks.isNotEmpty && currentIndex < tracks.length ? tracks[currentIndex] : null;
}
