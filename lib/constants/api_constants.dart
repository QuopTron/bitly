class ApiConstants {
  static const int defaultTimeout = 60;
  static const int shortTimeout = 15;
  static const int longTimeout = 120;

  static const String deezerBaseUrl = 'https://api.deezer.com/2.0';
  static const String tidalBaseUrl = 'https://api.tidal.com/v1';
  static const String musicbrainzBaseUrl = 'https://musicbrainz.org/ws/2';
  static const String songlinkBaseUrl = 'https://api.song.link/v1-beta.1';
  static const String songstatsBaseUrl = 'https://api.songstats.com/v1';

  static const String defaultExtensionRegistry =
      'https://raw.githubusercontent.com/spotiflacapp/SpotiFLAC-Extension/main/registry.json';

  static const int maxSearchResults = 50;
  static const int defaultSearchLimit = 20;
}