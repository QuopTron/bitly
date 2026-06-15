extension DateTimeExtensions on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  String formatRelative() {
    final now = DateTime.now();
    final diff = now.difference(this);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return formatDate();
  }

  String formatDate({String separator = '/'}) {
    return '${year.toString().padLeft(4, '0')}$separator'
        '${month.toString().padLeft(2, '0')}$separator'
        '${day.toString().padLeft(2, '0')}';
  }
}
