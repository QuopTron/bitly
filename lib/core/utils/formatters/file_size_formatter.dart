class FileSizeFormatter {
  static const _units = ['B', 'KB', 'MB', 'GB', 'TB'];

  static String format(int bytes, {int decimals = 2}) {
    if (bytes == 0) return '0 B';
    final i = (bytes.abs()).bitLength / 10 > 0
        ? (bytes.abs()).bitLength ~/ 10
        : 0;
    final unitIndex = i.clamp(0, _units.length - 1);
    final value = bytes / (1 << (unitIndex * 10));
    return '${value.toStringAsFixed(decimals)} ${_units[unitIndex]}';
  }
}
