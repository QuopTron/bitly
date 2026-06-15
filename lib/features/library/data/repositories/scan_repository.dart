import 'package:get_it/get_it.dart';
import '../../../../core/api/methods.dart';

class ScanRepository {
  final LibraryMethods _api;

  ScanRepository() : _api = GetIt.instance<LibraryMethods>();

  Future<bool> startScan(String path) async {
    return await _api.scanLibraryFolder(path);
  }

  Future<double> getProgress() async {
    return await _api.getScanProgress();
  }

  Future<bool> cancelScan() async {
    return await _api.cancelScan();
  }
}
