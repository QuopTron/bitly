// ─────────────────────────────────────────────────────────────
// modal_cola_hoja.dart — PART de modal_cola.dart: la hoja completa
// de la cola — altura 80% de pantalla, fondo (video o carátula
// desenfocada) con velo, handle, cabecera con conteo y chips de
// modo, y la lista reordenable de tracks.
// La cabecera y la lista viven en modal_cola_piezas.dart.
// Se conecta con: modal_cola.dart (misma library) + cubit_cola.
// Parte del flujo: reproductor (modal de cola, hoja).
// ─────────────────────────────────────────────────────────────

part of 'modal_cola.dart';

class _HojaCola extends StatelessWidget {
  final bool mostrarVideo;
  final VideoController? videoController;

  const _HojaCola({this.mostrarVideo = false, this.videoController});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final basePanel =
        esOscuro ? const Color(0xFF141414) : const Color(0xFFF6F6F6);
    final fg = mejorNeutro(basePanel);
    final colorBrillo = esOscuro
        ? ColoresApp.verdeBrillante
        : ColoresApp.verdeMedio;

    return BlocBuilder<CubitCola, EstadoCola>(
      builder: (context, cola) {
        // Carátula del actual (o primero) → el fondo desenfocado.
        final caratula = _resolverCaratula(cola);
        final alto = MediaQuery.sizeOf(context).height;
        final altoHoja = (alto * 0.8).clamp(380.0, alto * 0.88);

        return Container(
          height: altoHoja,
          decoration: BoxDecoration(
            color: basePanel,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // ── Fondo: video en vivo O carátula desenfocada ───────
              Positioned.fill(
                child: mostrarVideo && videoController != null
                    ? TexturaVideoFondo(controller: videoController!)
                    : _fondoCaratulaCola(caratula, esOscuro),
              ),
              // Velo de tema: filas legibles sobre cualquier arte.
              Positioned.fill(
                child: _VeloColaEstilo(
                  esOscuro: esOscuro,
                  caratula: caratula,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _handleCola(r, fg),
                  SizedBox(height: r.spacingM),
                  _cabeceraCola(context, r, cola, fg, colorBrillo),
                  SizedBox(height: r.spacingM),
                  Divider(height: 1, color: fg.withValues(alpha: 0.12)),
                  // ── Lista de tracks ──────────────────────────────────
                  Flexible(
                    child: cola.tracks.isEmpty
                        ? _estadoVacioCola(r, colorBrillo, fg)
                        : _listaCola(context, r, cola, fg, colorBrillo),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String? _resolverCaratula(EstadoCola cola) {
    try {
      if (cola.tieneActual && cola.actual != null) {
        return sl<CubitLikes>().caratulaLocalPara(cola.actual!) ??
            cola.actual!.coverUrl;
      }
      if (cola.tracks.isNotEmpty) {
        return cola.tracks.first.coverUrl;
      }
    } catch (_) {}
    return null;
  }
}

/// Velo that reacts to visual style for blur/dominant color.
class _VeloColaEstilo extends StatefulWidget {
  final bool esOscuro;
  final String? caratula;
  const _VeloColaEstilo({required this.esOscuro, required this.caratula});
  @override
  State<_VeloColaEstilo> createState() => _VeloColaEstiloState();
}

class _VeloColaEstiloState extends State<_VeloColaEstilo> {
  Color? _acento;
  @override
  void initState() {
    super.initState();
    _extraerColor();
  }
  @override
  void didUpdateWidget(covariant _VeloColaEstilo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caratula != widget.caratula) _extraerColor();
  }
  Future<void> _extraerColor() async {
    if (widget.caratula == null || widget.caratula!.isEmpty) return;
    try {
      final paleta = await paletaParaPortada(widget.caratula);
      if (mounted) setState(() => _acento = paleta?.dominante);
    } catch (_) {}
  }
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstiloVisual>(
      valueListenable: sl<ValueNotifier<EstiloVisual>>(),
      builder: (context, estilo, _) {
        return ValueListenableBuilder<PreferenciasEstilo>(
          valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
          builder: (context, prefs, _) {
            final spotify =
                estilo == EstiloVisual.spotify && prefs.fondosModals;
            if (spotify && _acento != null) {
              final defaultBg = widget.esOscuro
                  ? const Color(0xFF141414)
                  : const Color(0xFFF6F6F6);
              final colorFinal = Color.lerp(
                defaultBg,
                _acento!,
                widget.esOscuro ? 0.35 : 0.25,
              )!;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                color: colorFinal,
              );
            }
            return Container(
              color: (widget.esOscuro ? Colors.black : Colors.white)
                  .withValues(alpha: widget.esOscuro ? 0.74 : 0.55),
            );
          },
        );
      },
    );
  }
}