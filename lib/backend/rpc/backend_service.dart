import '../../frontend/shared/models/feed_models.dart';

abstract class BackendService {
  Future<bool> healthCheck();
  Future<List<FeedSection>> getHomeFeed({String locale = 'en'});
  /// Lists all available sources/providers (independent of feed content).
  Future<List<String>> getSources();
  Future<List<FeedItem>> search({
    required String query,
    String source = '',
    String type = '',
    int limit = 20,
  });
  /// Starts a streaming search (providers run in parallel, results accumulate
  /// incrementally). Returns a generation ID for this search session.
  Future<int> searchStreaming({
    required String query,
    String source = '',
    String type = '',
    int limit = 20,
  });
  /// Returns accumulated results from the current streaming search session.
  Future<SearchStreamResults> getSearchStreamResults();
  /// Returns the search category bubbles declared by each source's manifest
  /// (searchBehavior.filters), the SpotiFLAC source of truth for the search UI.
  Future<List<SourceSearchConfig>> getSearchConfig();
  Future<void> likeItem(String itemId, bool liked);
  Future<void> downloadItem(String itemId);
  Future<String> getAllDownloadProgress();
  /// Removes a download progress entry from the Go tracker so it stops being
  /// reported by [getAllDownloadProgress]. Called after the client deletes a
  /// download (otherwise the completed entry stays in the tracker forever and
  /// the next poll re-saves it).
  Future<void> cancelDownload(String itemId);
  /// Dispatches a download (audio/video/lyrics) to the Go backend.
  /// Returns the backend JSON result (a String or Map) or null on failure;
  /// fire-and-forget callers may ignore the return value.
  Future<dynamic> downloadByStrategy(String json);
  Future<void> initItemProgress(String itemId, {String trackName = '', String artistName = ''});
  Future<String> estimateTrackFileSize(int durationMs, String quality);
  /// Fetch album detail from extension API (not local DB). Returns '{}' if not found.
  Future<String> fetchAlbumDetail(String albumId, String source);

  /// Fetch playlist detail from extension API (not local DB). Returns '{}' if not found.
  Future<String> fetchPlaylistDetail(String collectionId, String source);

  /// Fetch artist detail from extension API (not local DB). Returns '{}' if not found.
  Future<String> fetchArtistDetail(String artistId, String source);

  // ── Cover Cache ────────────────────────────────────────────────────
  Future<String?> saveCover(String coverUrl);
  Future<void> deleteCover(String coverUrl);
  /// Looks up a local cover path from downloaded/library tracks by ISRC or track+artist.
  Future<String?> getCoverPathForTrack({
    required String trackId,
    String? isrc,
    String? trackName,
    String? artistName,
    String? coverUrl,
  });

  // ── Stream Cache ──────────────────────────────────────────────────────
  /// Returns current stream cache stats: size, file count, max, level limit, hits/misses.
  Future<Map<String, dynamic>> getStreamCacheStats();

  /// Clears all files in .stream_cache/. Returns {removed: int, ok: bool}.
  Future<Map<String, dynamic>> clearStreamCache();

  /// Sets the max cache size in MB, capped by user plan level.
  /// Returns {mb: int, level_limit_mb: int, ok: bool} or throws.
  Future<Map<String, dynamic>> setStreamCacheMaxMb(int mb);

  // ── Config sync (Flutter → Go in-memory) ─────────────────────────────
  /// Tells Go the user's download directory (set via [setDownloadDirectory] RPC).
  Future<void> syncDownloadDir(String path);

  /// Syncs user mode (free/premium) and other config to Go's in-memory config.
  Future<void> syncBackendConfig({String? mode, int? streamCacheMaxMb, int? downloadConcurrency, int? streamChunkSize});

  /// Sets the ordered list of download providers used for fallback (best-first),
  /// mirroring SpotiFLAC's SetProviderPriority. Empty restores the default order.
  Future<void> syncDownloadProviderPriority(List<String> providers);

  // ── Signed Session ───────────────────────────────────────────────────
  /// Returns the pending verification auth URL for an extension, or empty string.
  Future<String> getPendingVerificationUrl(String extensionId);

  /// Completes the signed session grant flow after the user passes the Turnstile captcha.
  Future<bool> completeSignedSessionGrant(String extensionId, String grantCode);

  /// Returns whether an extension's signed session is currently usable
  /// (authenticated and not expired), plus the record's expiry/install/session ids.
  Future<SignedSessionStatus> getSignedSessionStatus(String extensionId);

  /// Proactively triggers signed session verification (bootstrap + challenge URL)
  /// for the given extension. Returns the auth URL, or empty string if not needed.
  Future<String> triggerExtensionVerification(String extensionId);

  // ── Generic RPC ──────────────────────────────────────────────────────
  /// Execute an arbitrary RPC method on the backend.
  /// Returns the raw result (typically a JSON string or null).
  /// [timeout] overrides the default defensive per-call timeout; streaming
  /// calls that download a full track (getStreamPackage) pass a longer one.
  Future<dynamic> rpcCall(String method, [Map<String, dynamic>? params, Duration? timeout]);

  // ── Reset ────────────────────────────────────────────────────────────
  /// Deletes ALL data (DB, settings, favorites, downloads, library) and
  /// resets the app to factory state. User will need to go through setup.
  Future<bool> resetAllData();

  // ── Tag Editor ────────────────────────────────────────────────────────
  /// Reads metadata tags from an audio file. Returns JSON string.
  Future<String> readFileMetadata(String filePath);

  /// Writes metadata tags to an audio file. [meta] is a map of field→value.
  Future<bool> writeFileMetadata(String filePath, Map<String, String> meta);

  // ── Provider Health ───────────────────────────────────────────────────
  /// Returns cooldown status of all providers as JSON string.
  Future<String> getProviderHealthStatus();
}

/// Snapshot of an extension's signed-session record as reported by the Go
/// backend (`getSignedSessionStatus`). Used to decide whether a source already
/// has a usable (non-expired) session and can skip verification.
class SignedSessionStatus {
  final bool authenticated;
  final String? expiresAt;
  final String? installId;
  final String? sessionId;
  final String? error;

  const SignedSessionStatus({
    this.authenticated = false,
    this.expiresAt,
    this.installId,
    this.sessionId,
    this.error,
  });

  factory SignedSessionStatus.fromJson(Map<String, dynamic> json) {
    return SignedSessionStatus(
      authenticated: json['authenticated'] == true,
      expiresAt: json['expires_at'] as String?,
      installId: json['install_id'] as String?,
      sessionId: json['session_id'] as String?,
      error: json['error'] as String?,
    );
  }
}

/// Result of a streaming search poll. [items] are accumulated results from
/// all providers that have finished so far. [done] is true when the search
/// is complete (all providers finished or timed out). [generation] matches
/// the generation returned by [searchStreaming] — if it changes, the results
/// belong to a superseded search and should be discarded.
class SearchStreamResults {
  final List<FeedItem> items;
  final bool done;
  final int generation;

  const SearchStreamResults({
    required this.items,
    required this.done,
    required this.generation,
  });
}

