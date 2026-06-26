import 'package:flutter/material.dart';
import '../../core/helpers/responsive.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/feed_models.dart';

void showAddToModal(BuildContext context, FeedItem item) {
  final r = Responsive(context);
  final loc = AppLocalizations.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToSheet(r: r, loc: loc, item: item),
  );
}

class _AddToSheet extends StatelessWidget {
  final Responsive r;
  final AppLocalizations loc;
  final FeedItem item;

  const _AddToSheet({required this.r, required this.loc, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final onBg = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: EdgeInsets.only(top: r.spacingM),
            width: 40, height: 4,
            decoration: BoxDecoration(color: onBg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
          ),
          SizedBox(height: r.spacingM),
          Text(loc.setup.addToTitle, style: TextStyle(fontSize: r.subtitleSize + 1, fontWeight: FontWeight.bold, color: onBg)),
          SizedBox(height: r.spacingS),
          Text(item.name, style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: r.spacingL),
          _option(r, onBg, Icons.playlist_add, loc.setup.addToPlaylist, () => Navigator.pop(context)),
          Divider(height: 1, color: onBg.withValues(alpha: 0.08)),
          _option(r, onBg, Icons.favorite_border, loc.setup.addToWishlist, () => Navigator.pop(context)),
          if (item.type == 'track') ...[
            Divider(height: 1, color: onBg.withValues(alpha: 0.08)),
            _option(r, onBg, Icons.queue_music, loc.setup.playNext, () => Navigator.pop(context)),
          ],
          SizedBox(height: r.bottomPadding),
        ]),
      ),
    );
  }

  Widget _option(Responsive r, Color onBg, IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spacingXL, vertical: r.spacingM),
          child: Row(children: [
            Icon(icon, size: r.subtitleSize + 2, color: onBg.withValues(alpha: 0.6)),
            SizedBox(width: r.spacingM),
            Text(label, style: TextStyle(fontSize: r.subtitleSize, color: onBg)),
          ]),
        ),
      ),
    );
  }
}
