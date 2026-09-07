import 'package:share_plus/share_plus.dart';
import '../models/feed_models.dart';

/// Generates a shareable text with a deep link that opens Bitly and shows
/// the TikTok-style "shared with you" overlay for the item.
class ShareHelper {
  static const _baseUrl = 'https://bitly.app/open';

  static Future<void> shareItem(FeedItem item) async {
    final type = item.type;
    final query = Uri.encodeComponent('${item.name} ${item.artists ?? ''}');
    final link = '$_baseUrl?type=$type&id=${Uri.encodeComponent(item.id)}&q=$query';

    String emoji;
    switch (type) {
      case 'album':  emoji = '\u{1F4BF}'; break;
      case 'artist': emoji = '\u{1F3B6}'; break;
      case 'playlist': emoji = '\u{1F3B5}'; break;
      default: emoji = '\u{1F3B5}';
    }

    final parts = <String>[
      '$emoji ${item.name}',
      if (item.artists != null && item.artists!.isNotEmpty) 'by ${item.artists}',
      if (item.albumName != null) '\u{1F4BF} ${item.albumName}',
      '',
      link,
    ];

    await SharePlus.instance.share(ShareParams(text: parts.join('\n')));
  }
}
