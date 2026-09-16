// ─────────────────────────────────────────────────────────────
// hoja_opciones_descarga_cuerpo.dart — PART de
// hoja_opciones_descarga.dart: arma el cuerpo de la hoja — tirador,
// cabecera del ítem, secciones LOSSLESS/LOSSY con sus opciones,
// banner de video/letras y el botón de descargar. Aplica el fondo
// desenfocado cuando hay un track reproduciéndose.
// Se conecta con: hoja_opciones_descarga.dart (misma library) +
// colores_app + cubit_cola + l10n.
// Parte del flujo: descargar (selección de calidad).
// ─────────────────────────────────────────────────────────────

part of 'hoja_opciones_descarga.dart';

/// Cuerpo completo de la hoja con fondo vidrio si hay track activo.
Widget _cuerpoHoja(_HojaOpcionesDescargaState st) {
  return _DescargaEstilo(st: st);
}

/// Widget wrapper that reacts to visual style for blur/dominant color.
class _DescargaEstilo extends StatefulWidget {
  final _HojaOpcionesDescargaState st;
  const _DescargaEstilo({required this.st});

  @override
  State<_DescargaEstilo> createState() => _DescargaEstiloState();
}

class _DescargaEstiloState extends State<_DescargaEstilo> {
  Color? _acento;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  Future<void> _extraerColor() async {
    final url = widget.st.widget.item.coverUrl;
    if (url == null || url.isEmpty) return;
    try {
      final paleta = await paletaParaPortada(url);
      if (mounted) setState(() => _acento = paleta?.dominante);
    } catch (e) { debugPrint("[Widget] $e"); }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    final r = Responsive(st.context);
    final loc = AppLocalizations.of(st.context);
    final onBg = st.widget.esOscuro ? Colors.white : Colors.black;
    final brillo =
        st.widget.esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final hayTrack = sl<CubitCola>().state.tieneActual;
    final baseBg = st.widget.esOscuro
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF5F5F5);
    final fondoHoja = hayTrack ? baseBg.withValues(alpha: 0.70) : baseBg;

    Widget hoja = Container(
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: fondoHoja,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: r.spacingM),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: r.spacingL),
              _cabeceraItem(st, r, onBg, brillo),
              SizedBox(height: r.spacingM),
              _cabeceraSeccion(r, 'LOSSLESS', onBg),
              ..._HojaOpcionesDescargaState._clavesLossless
                  .map((q) => _construirOpcion(st, r, q, brillo, onBg)),
              _cabeceraSeccion(r, 'LOSSY', onBg),
              ..._HojaOpcionesDescargaState._clavesLossy
                  .map((q) => _construirOpcion(st, r, q, brillo, onBg)),
              SizedBox(height: r.spacingM),
              if (st.widget.ajustes.videoHabilitado ||
                  st.widget.ajustes.letrasHabilitadas)
                _bannerInfo(st, r, loc, onBg, brillo),
              SizedBox(height: r.spacingM),
              _botonDescargar(st, r, loc, onBg, brillo),
              // + menú de navegación del sistema: el botón Descargar vive al
              // pie de la hoja, que se ancla al borde físico de la pantalla.
              SizedBox(
                height: r.spacingXL + insetInferiorSistema(st.context),
              ),
            ],
          ),
        ),
      ),
    );

    return ValueListenableBuilder<EstiloVisual>(
      valueListenable: sl<ValueNotifier<EstiloVisual>>(),
      builder: (context, estilo, _) {
        return ValueListenableBuilder<PreferenciasEstilo>(
          valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
          builder: (context, prefs, _) {
            final spotify =
                estilo == EstiloVisual.spotify && prefs.fondosModals;
            if (spotify && hayTrack && _acento != null) {
              final colorFinal = Color.lerp(
                baseBg,
                _acento!,
                st.widget.esOscuro ? 0.45 : 0.30,
              )!;
              return ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  color: colorFinal,
                  child: hoja,
                ),
              );
            }
            if (hayTrack) {
              return ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: DesenfoqueAdaptativo(sigma: 24, child: hoja),
              );
            }
            return hoja;
          },
        );
      },
    );
  }
}