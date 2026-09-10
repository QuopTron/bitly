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
                child: Container(
                  color: (esOscuro ? Colors.black : Colors.white)
                      .withValues(alpha: esOscuro ? 0.74 : 0.55),
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