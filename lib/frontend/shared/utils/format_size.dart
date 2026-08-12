/// Formats raw bytes into a human-readable string (KB / MB).
/// Shows one decimal place for MB values (e.g. "3.2 MB").
String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  if (mb >= 100) return '${mb.round()} MB';
  return '${mb.toStringAsFixed(1)} MB';
}

