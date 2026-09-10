part of 'settings_sheet_new.dart';

String _downloadQualityLabel(String q, AppLocalizations loc) {
  switch (q) {
    case 'flac':
      return loc.setup.flac;
    case 'hifi':
      return loc.setup.hifi;
    case 'high':
      return loc.setup.high;
    case 'medium':
      return loc.setup.medium;
    case 'low':
      return loc.setup.low;
    default:
      return q;
  }
}

String _downloadVideoLabel(String q) {
  switch (q) {
    case '1080p':
      return 'Full HD (1080p)';
    case '720p':
      return 'HD (720p)';
    case '480p':
      return 'SD (480p)';
    default:
      return q;
  }
}

String _downloadLyricsLabel(String q) {
  switch (q) {
    case 'lrclib':
      return 'LRCLib';
    case 'genius':
      return 'Genius';
    case 'musixmatch':
      return 'Musixmatch';
    default:
      return q;
  }
}
