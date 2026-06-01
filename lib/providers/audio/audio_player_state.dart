import 'package:media_kit_video/media_kit_video.dart' show VideoController;

class VideoSource {
  final String name;
  final Future<String?> Function(String, String) fetchFunction;
  final int priority;
  
  VideoSource(this.name, this.fetchFunction, {this.priority = 99});
}

class AudioPlayerState {
  final bool isPlaying;
  final bool isLoading;
  final bool isDownloading;
  final int downloadProgress;
  final String? trackId;
  final String? trackName;
  final String? artistName;
  final String? albumName;
  final String? coverUrl;
  final String? source;
  final String? localPath;
  final Duration position;
  final Duration duration;
  final bool isVideoReady;
  final bool isLyricsReady;
  final bool isAudioVideoSynced;
  final Duration audioVideoOffset;
  final VideoController? videoController;

  const AudioPlayerState({
    this.isPlaying = false,
    this.isLoading = false,
    this.isDownloading = false,
    this.downloadProgress = 0,
    this.trackId,
    this.trackName,
    this.artistName,
    this.albumName,
    this.coverUrl,
    this.source,
    this.localPath,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isVideoReady = false,
    this.isLyricsReady = false,
    this.isAudioVideoSynced = false,
    this.audioVideoOffset = Duration.zero,
    this.videoController,
  });

  AudioPlayerState copyWith({
    bool? isPlaying,
    bool? isLoading,
    bool? isDownloading,
    int? downloadProgress,
    String? trackId,
    String? trackName,
    String? artistName,
    String? albumName,
    String? coverUrl,
    String? source,
    String? localPath,
    Duration? position,
    Duration? duration,
    bool? isVideoReady,
    bool? isLyricsReady,
    bool? isAudioVideoSynced,
    Duration? audioVideoOffset,
    VideoController? videoController,
    bool clearTrack = false,
  }) {
    if (clearTrack) {
      return const AudioPlayerState();
    }
    return AudioPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      trackId: trackId ?? this.trackId,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      coverUrl: coverUrl ?? this.coverUrl,
      source: source ?? this.source,
      localPath: localPath ?? this.localPath,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isVideoReady: isVideoReady ?? this.isVideoReady,
      isLyricsReady: isLyricsReady ?? this.isLyricsReady,
      isAudioVideoSynced: isAudioVideoSynced ?? this.isAudioVideoSynced,
      audioVideoOffset: audioVideoOffset ?? this.audioVideoOffset,
      videoController: videoController ?? this.videoController,
    );
  }
}