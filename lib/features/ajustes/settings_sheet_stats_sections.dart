part of 'settings_sheet_new.dart';

/// Sección de resumen del perfil: banner de tier + grids de estadísticas
/// (reproducciones totales y canciones/descargas).
class _StatsSummarySection extends StatelessWidget {
  final EstadoPremium? premium;
  final String? trialRemaining;
  final Map<String, dynamic> stats;
  final String likedCount;
  final String downloadedCount;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _StatsSummarySection({
    required this.premium,
    required this.trialRemaining,
    required this.stats,
    required this.likedCount,
    required this.downloadedCount,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final glow = glowColor;

    final totalPlays = stats['totalPlays'] ?? 0;
    final uniqueTracks = stats['uniqueTracks'] ?? 0;
    final uniqueArtists = stats['uniqueArtists'] ?? 0;
    final totalDurationMs = stats['totalDuration'] ?? 0;
    final hours = (totalDurationMs / 3600000).floor();
    final mins = ((totalDurationMs % 3600000) / 60000).floor();
    final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsTierBanner(
          isPremium: premium?.esPremium ?? false,
          trialRemaining: trialRemaining,
          glowColor: glow,
          onBg: onBg,
          r: r,
          loc: loc,
        ),
        _sectionHeader(
          Icons.bar_chart_rounded,
          loc.setup.totalPlays,
          glow,
          onBg,
          r,
        ),
        SizedBox(height: r.spacingS),
        _statsGrid(
          [
            _statCard(
              Icons.play_circle_outline,
              loc.setup.totalPlays,
              '$totalPlays',
              glow,
              onBg,
              r,
            ),
            _statCard(
              Icons.music_note_rounded,
              loc.setup.uniqueTracks,
              '$uniqueTracks',
              glow,
              onBg,
              r,
            ),
            _statCard(
              Icons.people_outline,
              loc.setup.uniqueArtists,
              '$uniqueArtists',
              glow,
              onBg,
              r,
            ),
            _statCard(
              Icons.schedule_rounded,
              loc.setup.listeningTime,
              durationStr,
              glow,
              onBg,
              r,
            ),
          ],
          context,
          r,
        ),
        SizedBox(height: r.spacingM),
        _sectionHeader(
          Icons.library_music_rounded,
          loc.setup.likedSongs,
          glow,
          onBg,
          r,
        ),
        SizedBox(height: r.spacingS),
        _statsGrid(
          [
            _statCard(
              Icons.favorite_rounded,
              loc.setup.likedSongs,
              likedCount,
              glow,
              onBg,
              r,
            ),
            _statCard(
              Icons.download_done_rounded,
              loc.setup.downloadedSongs,
              downloadedCount,
              glow,
              onBg,
              r,
            ),
          ],
          context,
          r,
        ),
      ],
    );
  }
}

/// Sección de top de tracks más escuchados (solo si hay datos).
