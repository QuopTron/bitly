class BitrateFormatter {
  static String format(int? bitrate) {
    if (bitrate == null || bitrate <= 0) return 'Unknown';
    if (bitrate < 1000) return '$bitrate bps';
    return '${(bitrate / 1000).toStringAsFixed(0)} kbps';
  }

  static String formatFromBytes(int bytesPerSecond) {
    return format(bytesPerSecond * 8);
  }
}
