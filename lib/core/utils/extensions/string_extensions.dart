
extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }

  bool get isUrl {
    final uri = Uri.tryParse(this);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String? extractDomain() {
    final uri = Uri.tryParse(this);
    return uri?.host;
  }
}
