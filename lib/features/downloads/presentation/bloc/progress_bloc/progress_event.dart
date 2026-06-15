import 'package:equatable/equatable.dart';
import '../../../data/models/download_progress_model.dart';

abstract class ProgressEvent extends Equatable {
  const ProgressEvent();

  @override
  List<Object?> get props => [];
}

class UpdateProgress extends ProgressEvent {
  final DownloadProgressModel progress;

  const UpdateProgress(this.progress);

  @override
  List<Object?> get props => [progress];
}

class StartMonitoring extends ProgressEvent {
  final String itemId;

  const StartMonitoring(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

class StopMonitoring extends ProgressEvent {}
