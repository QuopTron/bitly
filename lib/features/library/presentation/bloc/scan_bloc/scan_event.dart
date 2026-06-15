import 'package:equatable/equatable.dart';
import '../../../domain/entities/scan_progress.dart';

abstract class ScanEvent extends Equatable {
  const ScanEvent();

  @override
  List<Object?> get props => [];
}

class StartScan extends ScanEvent {
  final String path;
  const StartScan([this.path = '']);

  @override
  List<Object?> get props => [path];
}

class CancelScan extends ScanEvent {
  const CancelScan();
}

class UpdateProgress extends ScanEvent {
  final ScanProgress progress;
  const UpdateProgress(this.progress);

  @override
  List<Object?> get props => [progress];
}

class CheckStatus extends ScanEvent {
  const CheckStatus();
}
