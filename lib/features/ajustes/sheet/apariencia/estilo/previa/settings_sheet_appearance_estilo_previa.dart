// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_estilo_previa.dart — PART de
// settings_sheet_new.dart: la VISTA PREVIA en vivo del estilo con
// cover, dentro del bloque.
//
// Por qué existe: el control mueve la carátula y el color de TODA la app,
// pero desde Ajustes casi no se ve (el sheet tapa las pantallas y, si no hay
// canción sonando, su fondo no tiene carátula que mostrar). Los tres paneles
// —fondo, card y modal— se pintan con LA MISMA cuenta que la app, así cada
// porcentaje se ve al arrastrar y cada zona del "Avanzado" tiene su panel.
//
// La carátula y su color salen de la canción actual; sin canción se usa una
// de ejemplo. Los paneles viven en ..._estilo_previa_panel.dart.
//
// Se conecta con: estilo_helper + paleta_portada + la cola.
// Parte del flujo: Ajustes → Apariencia → Estilo con cover.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Los tres paneles de la vista previa, con la cuenta real del estilo.
class _PreviaEstilo extends StatefulWidget {
  final PreferenciasEstilo prefs;
  final Color onBg;
  final Responsive r;
  final StringsAparienciaEstilo textos;

  const _PreviaEstilo({
    required this.prefs,
    required this.onBg,
    required this.r,
    required this.textos,
  });

  @override
  State<_PreviaEstilo> createState() => _PreviaEstiloState();
}

class _PreviaEstiloState extends State<_PreviaEstilo> {
  String? _cover;
  Color _acento = acentoDeEjemplo;

  @override
  void initState() {
    super.initState();
    _leerCancion();
  }

  /// Canción actual y su color dominante (o queda la carátula de ejemplo).
  Future<void> _leerCancion() async {
    String? cover;
    try {
      final track = sl<CubitCola>().state.actual;
      if (track != null) {
        cover = sl<CubitLikes>().caratulaLocalPara(track) ?? track.coverUrl;
      }
    } catch (e) {
      debugPrint('[PreviaEstiloState] $e');
      cover = null;
    }
    if (cover == null || cover.isEmpty) return;
    final paleta = await paletaParaPortada(cover);
    if (!mounted) return;
    setState(() {
      _cover = cover;
      _acento = paleta?.dominante ?? acentoDeEjemplo;
    });
  }

  /// El arte: la carátula de la canción o el degradado de ejemplo.
  Widget _arte() =>
      _cover != null
          ? imagenDesdeUrl(_cover, ajuste: BoxFit.cover, ancho: 128, alto: 128)
          : arteDeEjemplo();

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final t = widget.textos;
    final prefs = widget.prefs;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final arte = _arte();

    /// Un panel, con la cuenta de su zona.
    Widget panel({
      required String titulo,
      required double nivel,
      required double velo,
      required bool apagaArte,
      bool conMiniCard = false,
    }) => _PanelPrevia(
      titulo: titulo,
      nivel: nivel,
      velo: velo,
      apagaArte: apagaArte,
      acento: _acento,
      arte: arte,
      esOscuro: esOscuro,
      onBg: widget.onBg,
      r: r,
      conMiniCard: conMiniCard,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.estiloVistaPrevia,
          style: TextStyle(
            fontSize: r.footerSize - 2,
            fontWeight: FontWeight.w600,
            color: widget.onBg.withValues(alpha: 0.45),
          ),
        ),
        SizedBox(height: r.spacingXS),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: panel(
                titulo: t.compFondoPrincipal,
                nivel: prefs.fondoPrincipal,
                velo: 0.55,
                apagaArte: true,
              ),
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: panel(
                titulo: t.compCancion,
                nivel: prefs.cardsCancion,
                velo: 0.30,
                apagaArte: false,
                conMiniCard: true,
              ),
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: panel(
                titulo: t.compModals,
                nivel: prefs.fondosModals,
                velo: 0.60,
                apagaArte: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
