// Parte del split de settings_sheet_new.dart — _ProfileStatsView.
// Extraído del archivo original (ver git log). No editar a mano.
part of 'settings_sheet_new.dart';

class _ProfileStatsView extends StatefulWidget {
  final Color glowColor;
  final String likedCount;
  final String downloadedCount;
  final EstadoPremium? premium;
  const _ProfileStatsView({
    required this.glowColor,
    required this.likedCount,
    required this.downloadedCount,
    this.premium,
  });
  @override
  State<_ProfileStatsView> createState() => _ProfileStatsViewState();
}

class _ProfileStatsViewState extends State<_ProfileStatsView> {
  Map<String, dynamic> _stats = {};
  List<dynamic> _topTracks = [];
  bool _loading = true;
  String? _trialRemaining;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Stats come from the LOCAL Drift tables
    try {
      final stats = await sl<ReproduccionCache>().getStatsPerfil();
      if (mounted) _stats = stats;
    } catch (_) {}
    try {
      final top = await sl<ReproduccionStats>().getTopTracksConNombres(5);
      if (mounted) _topTracks = top;
    } catch (_) {}
    // Load trial remaining time for free users
    try {
      final setup = await sl<CacheAjustes>().cargarDatosSetup();
      if (setup != null &&
          setup.mode == 'free' &&
          setup.trialExpiraEn != null) {
        final expires = DateTime.tryParse(setup.trialExpiraEn!);
        if (expires != null) {
          final diff = expires.difference(DateTime.now());
          if (diff.isNegative) {
            if (mounted) _trialRemaining = 'EXPIRADO';
          } else {
            final h = diff.inHours;
            final m = (diff.inMinutes % 60);
            if (mounted) _trialRemaining = '${h}h ${m}m restantes';
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final glow = widget.glowColor;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: glow),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsSummarySection(
            premium: widget.premium,
            trialRemaining: _trialRemaining,
            stats: _stats,
            likedCount: widget.likedCount,
            downloadedCount: widget.downloadedCount,
            glowColor: glow,
            onBg: onBg,
            r: r,
          ),
          _StatsTopTracksSection(
            topTracks: _topTracks,
            glowColor: glow,
            onBg: onBg,
            r: r,
          ),
        ],
      ),
    );
  }
}
