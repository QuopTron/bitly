part of 'settings_sheet_new.dart';

class _StatsTopTracksSection extends StatelessWidget {
  final List<dynamic> topTracks;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _StatsTopTracksSection({
    required this.topTracks,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final glow = glowColor;

    if (topTracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.spacingM),
        _sectionHeader(
          Icons.leaderboard_rounded,
          loc.setup.mostPlayed,
          glow,
          onBg,
          r,
        ),
        SizedBox(height: r.spacingS),
        ...topTracks.map(
          (t) =>
              _StatsTopTrackTile(track: t, glowColor: glow, onBg: onBg, r: r),
        ),
      ],
    );
  }
}
