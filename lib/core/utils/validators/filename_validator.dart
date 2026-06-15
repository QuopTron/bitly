class FilenameValidator {
  static final _invalidChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  static bool isValid(String filename) {
    if (filename.isEmpty || filename.length > 255) return false;
    if (filename == '.' || filename == '..') return false;
    return !_invalidChars.hasMatch(filename);
  }

  static String sanitize(String filename) {
    return filename.replaceAll(_invalidChars, '_').trim();
  }
}
