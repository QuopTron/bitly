import 'package:get_it/get_it.dart';
import '../../data/repositories/scan_repository.dart';
import '../entities/scan_progress.dart';

class ScanLibrary {
  final ScanRepository _repository;

  ScanLibrary() : _repository = GetIt.instance<ScanRepository>();

  Future<void> call(String path) async {
    await _repository.startScan(path);
  }

  Future<ScanProgress> getProgress() async {
    final pct = await _repository.getProgress();
    return ScanProgress(
      totalFiles: 0,
      scannedFiles: 0,
      currentFile: '',
      isScanning: pct < 1.0,
      percentage: pct,
    );
  }

  Future<void> cancel() async {
    await _repository.cancelScan();
  }
}
