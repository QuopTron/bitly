import 'package:flutter/foundation.dart';

class AppInfo {
  static const String version = '1.2.0';
  static const String buildNumber = '1';
  static const String fullVersion = '$version+$buildNumber';
  static String get displayVersion => kDebugMode ? 'Internal' : version;
  static const String appName = 'Bitly';
  static const String copyright = '(c) 2026 Bitly';
  static const String githubRepo = 'QuopTron/bitly';
  static const String githubUrl = 'https://github.com/$githubRepo';
  static const String kofiUrl = 'https://ko-fi.com/QuopTron';
  static const String githubSponsorsUrl = 'https://github.com/sponsors/QuopTron/';
}