part of 'settings_sheet_new.dart';

/// Una fila del top de tracks más escuchados.
class _StatsTopTrackTile extends StatelessWidget {
  final dynamic track;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _StatsTopTrackTile({
    required this.track,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final name = track is Map ? (track['name'] ?? '') : '';
    final artist = track is Map ? (track['artist'] ?? '') : '';
    final id = track is Map ? (track['trackId'] ?? '') : '';
    final count = track is Map ? (track['count'] ?? 0) : 0;
    final glow = glowColor;
    return Container(
      margin: EdgeInsets.only(bottom: r.spacingXS),
      padding: EdgeInsets.symmetric(
        horizontal: r.spacingM,
        vertical: r.spacingS,
      ),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.music_note_rounded,
            size: r.footerSize,
            color: glow.withValues(alpha: 0.6),
          ),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : id,
                  style: TextStyle(fontSize: r.subtitleSize - 1, color: onBg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (artist.isNotEmpty)
                  Text(
                    artist,
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color: onBg.withValues(alpha: 0.4),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: glow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: r.footerSize - 2,
                color: glow,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
