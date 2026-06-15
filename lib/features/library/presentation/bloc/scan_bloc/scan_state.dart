import 'package:equatable/equatable.dart';
import '../../../domain/entities/scan_progress.dart';

class ScanState extends Equatable {
  final ScanProgress? progress;
  final bool isScanning;
  final String? error;

  const ScanState({
    this.progress,
    this.isScanning = false,
    this.error,
  });

  ScanState copyWith({
    ScanProgress? progress,
    bool? isScanning,
    String? error,
  }) {
    return ScanState(
      progress: progress ?? this.progress,
      isScanning: isScanning ?? this.isScanning,
      error: error,
    );
  }

  @override
  List<Object?> get props => [progress, isScanning, error];
}
