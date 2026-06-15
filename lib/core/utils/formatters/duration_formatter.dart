class DurationFormatter {
  static String format(Duration duration, {bool showHours = false}) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0 || showHours) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  static String formatSeconds(int totalSeconds, {bool showHours = false}) {
    return format(Duration(seconds: totalSeconds), showHours: showHours);
  }

  static String formatMilliseconds(int ms, {bool showHours = false}) {
    return format(Duration(milliseconds: ms), showHours: showHours);
  }
}
