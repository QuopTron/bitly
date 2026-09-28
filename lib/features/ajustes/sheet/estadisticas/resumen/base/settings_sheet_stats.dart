// ─────────────────────────────────────────────────────────────
// settings_sheet_stats.dart — Bloque de estadísticas del perfil (likes, descargas y estado Premium o
// trial) con su animación de entrada.
//
// Se conecta con: settings_sheet_new.dart (misma library) + settings_sheet_stats_widgets.
// Parte del flujo: Ajustes → estadísticas del perfil.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

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
    } catch (e) {
      debugPrint('[Stats] no se pudo leer el perfil de escucha: $e');
    }
    try {
      final top = await sl<ReproduccionStats>().getTopTracksConNombres(5);
      if (mounted) _topTracks = top;
    } catch (e) {
      debugPrint('[Stats] no se pudieron leer los temas más escuchados: $e');
    }
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
            if (mounted) {
              final loc = AppLocalizations.of(context);
              _trialRemaining = loc.ajustes.trialRestante(
                h,
                m,
                en: loc.locale.languageCode == 'en',
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[Stats] no se pudo leer el restante de la prueba: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final glow = widget.glowColor;

    // Mientras llegan los números se muestra un esqueleto con LA FORMA de lo
    // que va a aparecer (el resumen de contadores arriba y las filas de las
    // más escuchadas abajo) y no una ruedita: la ruedita no dice qué esperar y
    // el contenido después "salta" de la nada. Las medidas son las mismas de
    // las piezas reales, así el cambio no mueve nada de lugar.
    if (_loading) {
      return _EsqueletoStats(glowColor: glow, onBg: onBg, r: r);
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

/// Esqueleto de las estadísticas: la silueta del resumen y de las filas.
///
/// No inventa formas nuevas: repite la estructura de `_StatsSummarySection`
/// (un bloque de contadores) y de `_StatsTopTracksSection` (filas de canción),
/// con los mismos paddings del contenido real.
class _EsqueletoStats extends StatelessWidget {
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _EsqueletoStats({
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(r.spacingL),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Los contadores: cuatro tubos, como los números reales.
        EsqueletoCarga(alto: r.spacingL, radioBorde: 10),
        SizedBox(height: r.spacingS),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) SizedBox(width: r.spacingS),
              Expanded(
                child: EsqueletoCarga(alto: r.spacingL * 2, radioBorde: 12),
              ),
            ],
          ],
        ),
        SizedBox(height: r.spacingM),
        // Y las filas de "más escuchadas": carátula + dos líneas.
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) SizedBox(height: r.spacingS),
          Row(
            children: [
              EsqueletoCarga(
                ancho: r.spacingL * 1.4,
                alto: r.spacingL * 1.4,
                radioBorde: 10,
              ),
              SizedBox(width: r.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EsqueletoCarga(alto: r.footerSize, radioBorde: 6),
                    SizedBox(height: r.spacingXS),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.55,
                      child: EsqueletoCarga(alto: r.footerSize, radioBorde: 6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
