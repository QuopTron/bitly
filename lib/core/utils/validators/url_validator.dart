class UrlValidator {
  static bool isValid(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.hasScheme && uri.host.isNotEmpty && uri.path.isNotEmpty;
  }

  static bool isHttpUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }
}
