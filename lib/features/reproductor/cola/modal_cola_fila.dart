// ─────────────────────────────────────────────────────────────
// modal_cola_fila.dart — PART de modal_cola.dart: fila de un track
// de la cola — handle/indicador, miniatura de carátula, nombre/
// artista, badge de fuente y botón de quitar. La fila actual se
// resalta con borde y tinte del color brillo. Las sub-piezas
// visuales viven en modal_cola_fila_piezas.dart.
// Se conecta con: modal_cola.dart (misma library) + imagen_portada.
// Parte del flujo: reproductor (modal de cola, fila).
// ─────────────────────────────────────────────────────────────

part of 'modal_cola.dart';

/// Fila de un track dentro de la lista reordenable de la cola.
class FilaTrackCola extends StatelessWidget {
  final Responsive r;
  final Color fg;
  final Color colorBrillo;
  final ItemFeed track;
  final int index;
  final bool esActual;
  final bool esReproducida;
  final VoidCallback? onTap;
  final VoidCallback? onQuitar;

  const FilaTrackCola({
    super.key,
    required this.r,
    required this.fg,
    required this.colorBrillo,
    required this.track,
    required this.index,
    required this.esActual,
    required this.esReproducida,
    this.onTap,
    this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.spacingL,
            vertical: r.spacingS,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: esActual ? colorBrillo : Colors.transparent,
                width: 3,
              ),
            ),
            color: esActual
                ? colorBrillo.withValues(alpha: 0.10)
                : (index.isOdd ? fg.withValues(alpha: 0.03) : null),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _indicadorFila(this),
              SizedBox(width: r.spacingS),
              _miniaturaFila(this),
              SizedBox(width: r.spacingM),
              _infoFila(this),
              _badgeFuenteFila(this),
              _botonQuitarFila(this),
            ],
          ),
        ),
      ),
    );
  }
}