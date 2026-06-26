import 'package:flutter/material.dart';
import '../../core/helpers/responsive.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/feed_models.dart';

void showSongInfoModal(BuildContext context, FeedItem item) {
  final r = Responsive(context);
  final loc = AppLocalizations.of(context);

  final durationStr = item.durationMs != null
      ? '${(item.durationMs! ~/ 60000).toString().padLeft(2, '0')}:${((item.durationMs! % 60000) ~/ 1000).toString().padLeft(2, '0')}'
      : '--:--';

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SongInfoSheet(r: r, loc: loc, item: item, durationStr: durationStr),
  );
}

class _SongInfoSheet extends StatelessWidget {
  final Responsive r;
  final AppLocalizations loc;
  final FeedItem item;
  final String durationStr;

  const _SongInfoSheet({required this.r, required this.loc, required this.item, required this.durationStr});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final onBg = isDark ? Colors.white : Colors.black;

    return Container(
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: EdgeInsets.only(top: r.spacingM),
              width: 40, height: 4,
              decoration: BoxDecoration(color: onBg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
            ),
            SizedBox(height: r.spacingXL),
            if (item.coverUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(item.coverUrl!, width: r.width * 0.5, height: r.width * 0.5, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(width: r.width * 0.5, height: r.width * 0.5,
                    decoration: BoxDecoration(color: onBg.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.music_note, size: 48, color: onBg.withValues(alpha: 0.3))),
                ),
              ),
            SizedBox(height: r.spacingL),
            Text(item.name, style: TextStyle(fontSize: r.subtitleSize + 2, fontWeight: FontWeight.bold, color: onBg),
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            SizedBox(height: r.spacingXS),
            Text(item.artists ?? '', style: TextStyle(fontSize: r.subtitleSize, color: onBg.withValues(alpha: 0.6)),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: r.spacingL),
            _infoRow(r, onBg, Icons.music_note, loc.setup.feedSubtitleTrack, item.name),
            if (item.albumName != null)
              _infoRow(r, onBg, Icons.album, loc.setup.feedSubtitleAlbum, item.albumName!),
            _infoRow(r, onBg, Icons.timer_outlined, loc.setup.trackDuration, durationStr),
            if (item.type != 'track')
              _infoRow(r, onBg, Icons.category_outlined, loc.setup.trackType, item.type),
            SizedBox(height: r.spacingXL),
          ]),
        ),
      ),
    );
  }

  Widget _infoRow(Responsive r, Color onBg, IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL, vertical: r.spacingXS),
      child: Row(children: [
        Icon(icon, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.4)),
        SizedBox(width: r.spacingM),
        Text(label, style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5))),
        const Spacer(),
        Flexible(child: Text(value, style: TextStyle(fontSize: r.footerSize, fontWeight: FontWeight.w500, color: onBg),
          textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
