import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/audio/audio_player_provider.dart';
import 'package:bitly/providers/download/download_queue_provider.dart';
import 'package:bitly/providers/local_library/local_library_provider.dart';
import 'package:bitly/providers/playback/playback_state.dart';
import 'package:bitly/services/library/library_database.dart';
import 'package:bitly/utils/file_access.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('PlaybackProvider');

class PlaybackController extends Notifier<PlaybackState> {
  @override
  PlaybackState build() => const PlaybackState();

  Future<void> playLocalPath({
    required String path,
    required String title,
    required String artist,
    String album = '',
    String coverUrl = '',
    Track? track,
  }) async {
    if (isCueVirtualPath(path)) {
      throw Exception(cueVirtualTrackRequiresSplitMessage);
    }
    _log.d('Opening internal player for "$title" by $artist: $path');
    await ref.read(audioPlayerProvider.notifier).playLocalFile(
      filePath: path,
      trackName: title,
      artistName: artist,
      albumName: album.isNotEmpty ? album : null,
      coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
    );
  }

  Future<void> playTrackList(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;

    final DownloadHistoryState historyState = ref.read(downloadHistoryProvider);
    final DownloadHistoryNotifier historyNotifier = ref.read(downloadHistoryProvider.notifier);
    final LocalLibraryNotifier libraryNotifier = ref.read(localLibraryProvider.notifier);

    final List<Track> orderedTracks = this._orderedTracksFromStartIndex(tracks, startIndex);
    var skippedCueVirtualTrack = false;
    for (final track in orderedTracks) {
      final String? resolvedPath = await this._resolveTrackPath(
        track,
        historyState,
        historyNotifier,
        libraryNotifier,
      );
      if (resolvedPath == null) {
        continue;
      }
      if (isCueVirtualPath(resolvedPath)) {
        skippedCueVirtualTrack = true;
        continue;
      }

      _log.d(
        'Opening first available track for list playback: '
        '"${track.name}" by ${track.artistName} -> $resolvedPath',
      );
      await ref.read(audioPlayerProvider.notifier).playLocalFile(
        filePath: resolvedPath,
        trackName: track.name,
        artistName: track.artistName,
        albumName: track.albumName,
        coverUrl: track.coverUrl,
      );
      return;
    }

    if (skippedCueVirtualTrack) {
      throw Exception(cueVirtualTrackRequiresSplitMessage);
    }

    throw Exception(
      'No local audio file is available to open. Download the track first.',
    );
  }

  List<Track> _orderedTracksFromStartIndex(List<Track> inputTracks, int startIndex) {
    final safeStart = startIndex.clamp(0, inputTracks.length - 1);
    if (safeStart == 0) return List<Track>.from(inputTracks, growable: false);
    return <Track>[...inputTracks.sublist(safeStart), ...inputTracks.sublist(0, safeStart)];
  }

  Future<String?> _resolveTrackPath(
    Track track,
    DownloadHistoryState historyState,
    DownloadHistoryNotifier historyNotifier,
    LocalLibraryNotifier libraryNotifier,
  ) async {
    final LocalLibraryItem? localItem = await this._findLocalLibraryItemForTrack(track, libraryNotifier);
    if (localItem != null && await fileExists(localItem.filePath)) return localItem.filePath;

    final DownloadHistoryItem? historyItem = await this._findDownloadHistoryItemForTrack(track, historyState, historyNotifier);
    if (historyItem != null) {
      if (await fileExists(historyItem.filePath)) return historyItem.filePath;
      historyNotifier.removeFromHistory(historyItem.id);
    }
    return null;
  }

  Future<LocalLibraryItem?> _findLocalLibraryItemForTrack(
    Track track,
    LocalLibraryNotifier libraryNotifier,
  ) async {
    final bool isLocalSource = (track.source ?? '').toLowerCase() == 'local';
    if (isLocalSource) {
      final LocalLibraryItem? byId = await libraryNotifier.getById(track.id);
      if (byId != null) return byId;
    }
    final String? isrc = track.isrc?.trim();
    return libraryNotifier.findExistingAsync(isrc: isrc, trackName: track.name, artistName: track.artistName);
  }

  Future<DownloadHistoryItem?> _findDownloadHistoryItemForTrack(
    Track track,
    DownloadHistoryState historyState,
    DownloadHistoryNotifier historyNotifier,
  ) async {
    final List<String> candidates = this._spotifyIdLookupCandidates(track.id);
    for (final String candidateId in candidates) {
      final DownloadHistoryItem? bySpotifyId = historyState.getBySpotifyId(candidateId);
      if (bySpotifyId != null) {
        if (await fileExists(bySpotifyId.filePath)) return bySpotifyId;
        historyNotifier.removeFromHistory(bySpotifyId.id);
      }
      final DownloadHistoryItem? bySpotifyIdAsync = await historyNotifier.getBySpotifyIdAsync(candidateId);
      if (bySpotifyIdAsync != null) return bySpotifyIdAsync;
    }
    final String? isrc = track.isrc?.trim();
    if (isrc != null && isrc.isNotEmpty) {
      final DownloadHistoryItem? byIsrc = historyState.getByIsrc(isrc);
      if (byIsrc != null) {
        if (await fileExists(byIsrc.filePath)) return byIsrc;
        historyNotifier.removeFromHistory(byIsrc.id);
      }
      final DownloadHistoryItem? byIsrcAsync = await historyNotifier.getByIsrcAsync(isrc);
      if (byIsrcAsync != null) return byIsrcAsync;
    }
    return historyNotifier.findByTrackAndArtistAsync(track.name, track.artistName);
  }

  List<String> _spotifyIdLookupCandidates(String rawId) {
    final String trimmed = rawId.trim();
    if (trimmed.isEmpty) return const [];
    final Set<String> candidates = {trimmed};
    final String lowered = trimmed.toLowerCase();
    if (lowered.startsWith('spotify:track:')) {
      final String compact = trimmed.split(':').last.trim();
      if (compact.isNotEmpty) candidates.add(compact);
    } else if (!trimmed.contains(':')) {
      candidates.add('spotify:track:$trimmed');
    }
    final Uri? uri = Uri.tryParse(trimmed);
    final List<String> segments = uri?.pathSegments ?? const <String>[];
    final int trackIndex = segments.indexOf('track');
    if (trackIndex >= 0 && trackIndex + 1 < segments.length) {
      final String pathId = segments[trackIndex + 1].trim();
      if (pathId.isNotEmpty) {
        candidates.add(pathId);
        candidates.add('spotify:track:$pathId');
      }
    }
    return candidates.toList(growable: false);
  }

}

final playbackProvider = NotifierProvider<PlaybackController, PlaybackState>(
  PlaybackController.new,
);