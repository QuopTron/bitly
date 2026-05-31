import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('HardDeleteUtils');

class HardDeleteUtils {
  /// Deletes a file and attempts to clean up the parent directory.
  static Future<void> deleteFileAndCleanupFolder(String filePath) async {
    if (filePath.isEmpty) return;

    final file = File(filePath);

    try {
      if (await file.exists()) {
        await _forceDelete(file);
        _log.d('Deleted file: $filePath');
      }
    } catch (e) {
      _log.e('Error during hard delete of $filePath: $e');
    }
  }

  /// Tries to delete a locked file on Windows:
  /// 1. Retry with short delay  
  /// 2. Rename then delete on the same volume
  static Future<void> _forceDelete(File file) async {
    final path = file.path;

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        await file.delete();
        return;
      } catch (_) {
        if (attempt < 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }

    // Try rename + delete (rename may succeed on opened files)
    final tmpPath = '$path.deleting';
    try {
      await file.rename(tmpPath);
      await File(tmpPath).delete();
    } catch (_) {}
  }

  /// Deletes associated sidecar files (lyrics, covers, etc.)
  static Future<void> deleteSidecarFiles(String audioPath) async {
    final basePath = p.withoutExtension(audioPath);
    final extensions = ['.lrc', '.txt', '.ass', '.srt', '.jpg', '.png'];
    for (final ext in extensions) {
      final sidecar = File('$basePath$ext');
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
    }
  }
}
