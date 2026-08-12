import 'package:equatable/equatable.dart';

enum DownloadState { none, inProgress, completed, interrupted }

class DownloadStateData {
  final DownloadState state;
  final double progress;
  final String? errorMessage;

  const DownloadStateData({
    this.state = DownloadState.none,
    this.progress = 0.0,
    this.errorMessage,
  });
}

class DownloadCubitState extends Equatable {
  final Map<String, DownloadStateData> downloads;
  final Set<String> downloadedFingerprints;
  final bool loading;

  /// Set to true when the Go backend restarted while downloads were in-progress.
  /// UI can show a one-time banner/snackbar when this flips to true.
  final bool backendRestarted;

  /// Non-null when a completed download was encrypted/DRM and the client could
  /// not decrypt it (e.g. ffmpeg-kit unavailable). The UI shows a one-time
  /// notice while this is set, then clears it via [DownloadCubit.acknowledgeDecryptError].
  final String? decryptError;

  const DownloadCubitState({
    this.downloads = const {},
    this.downloadedFingerprints = const {},
    this.loading = false,
    this.backendRestarted = false,
    this.decryptError,
  });

  DownloadCubitState copyWith({
    Map<String, DownloadStateData>? downloads,
    Set<String>? downloadedFingerprints,
    bool? loading,
    bool? backendRestarted,
    String? decryptError,
    bool clearDecryptError = false,
  }) =>
      DownloadCubitState(
        downloads: downloads ?? this.downloads,
        downloadedFingerprints: downloadedFingerprints ?? this.downloadedFingerprints,
        loading: loading ?? this.loading,
        backendRestarted: backendRestarted ?? this.backendRestarted,
        decryptError: clearDecryptError ? null : (decryptError ?? this.decryptError),
      );

  @override
  List<Object?> get props => [downloads, downloadedFingerprints, loading, backendRestarted, decryptError];
}
