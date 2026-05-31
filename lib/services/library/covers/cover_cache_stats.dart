/// Modelo de estadísticas de la caché de carátulas.
/// Almacena el recuento de archivos y el tamaño total en bytes,
/// y proporciona un formato legible para mostrar.
library;

class CacheStats {
  final int fileCount;
  final int totalSizeBytes;

  const CacheStats({
    required this.fileCount,
    required this.totalSizeBytes,
  });

  String get formattedSize {
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
