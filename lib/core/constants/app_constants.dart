class AppConstants {
  AppConstants._();

  static const String appName = 'Bitly';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.bitly.app';

  static const bool defaultDarkMode = true;
  static const bool defaultNotificationsEnabled = true;
  static const bool defaultOfflineMode = false;
  static const int defaultMaxDownloadRetries = 3;
  static const int defaultConcurrentDownloads = 2;

  static const Duration searchDebounceDuration = Duration(milliseconds: 500);
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);
}
