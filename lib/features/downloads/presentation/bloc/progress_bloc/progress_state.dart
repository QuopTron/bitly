import 'package:equatable/equatable.dart';
import '../../../data/models/download_progress_model.dart';

class ProgressState extends Equatable {
  final Map<String, DownloadProgressModel> progress;
  final List<String> activeDownloads;

  const ProgressState({
    this.progress = const {},
    this.activeDownloads = const [],
  });

  ProgressState copyWith({
    Map<String, DownloadProgressModel>? progress,
    List<String>? activeDownloads,
  }) =>
      ProgressState(
        progress: progress ?? this.progress,
        activeDownloads: activeDownloads ?? this.activeDownloads,
      );

  @override
  List<Object?> get props => [progress, activeDownloads];
}
