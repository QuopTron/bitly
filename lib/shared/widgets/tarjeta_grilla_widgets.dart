// ─────────────────────────────────────────────────────────────
// tarjeta_grilla_widgets.dart — PART de tarjeta_grilla.dart:
// sub-widgets visuales de la tarjeta de grilla — fondo con portada
// borrosa o gradiente, portada nítida (circular para artistas) con
// badge de esquina, bloque de info (título/subtítulo/contador) y
// fila de acciones (like/descarga/más). Reciben la tarjeta para
// acceder a sus campos (tipo, coverUrl, callbacks, estados).
// Se conecta con: tarjeta_grilla.dart (misma library) + shared
// (imagen, indicador, colores, haptico, responsive, l10n).
// Parte del flujo: feed, búsqueda, mi espacio (tarjetas de grilla).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_grilla.dart';

/// Cuerpo completo de la tarjeta: calcula el espacio de la portada
/// reservando primero el bloque de info y compone el stack de capas
/// (fondo borroso, scrim, gradiente, portada + info).
Widget _cuerpoTarjeta(
  TarjetaGrilla t,
  BuildContext context,
  BoxConstraints constraints,
  Responsive r,
  bool esOscuro,
  Color fondoFallback,
  Color fg,
  double ts,
  bool efectosPesados,
) {
  final w = constraints.maxWidth;
  final h = constraints.maxHeight;
  final pad = r.spacingS;
  final anchoEnvoltura = w - 2 * pad;
  final altoInfo = t._altoInfo(r, ts, t.mostrarAcciones);
  final ladoPortada =
      math.min(anchoEnvoltura, math.max(40.0, h - altoInfo - pad)).toDouble();
  final hayEspacioPortada = ladoPortada >= 40;

  return GestureDetector(
    onTap: t.onTap,
    behavior: HitTestBehavior.translucent,
    child: Container(
      width: w,
      height: h.isFinite ? h : w + altoInfo + pad,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: t.estadoDescarga == EstadoDescarga.completado
              ? fg.withValues(alpha: 0.2)
              : ColoresApp.bordeSutil(esOscuro),
          width: t.estadoDescarga == EstadoDescarga.completado ? 1.0 : 0.6,
        ),
        boxShadow: t.estadoDescarga == EstadoDescarga.completado
            ? [
                BoxShadow(
                  color: ColoresApp.sombra(esOscuro),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
        color: fondoFallback,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Portada borrosa de fondo + scrim + gradiente ascendente.
          Positioned.fill(
            child: _fondoTarjeta(t, context, efectosPesados, esOscuro),
          ),
          Positioned.fill(
            child: Container(
              color: ColoresApp.velo(esOscuro).withValues(alpha: 0.45),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    ColoresApp.velo(esOscuro).withValues(alpha: 1.0),
                    ColoresApp.velo(esOscuro).withValues(alpha: 0.65),
                    ColoresApp.velo(esOscuro).withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),
          // Primer plano: portada nítida + bloque de info debajo.
          Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hayEspacioPortada)
                  _portadaNitidaDe(
                    t,
                    context,
                    ladoPortada,
                    esOscuro,
                    efectosPesados,
                  ),
                if (hayEspacioPortada) SizedBox(height: r.spacingS),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      key: ValueKey('info_${t.tipo}'),
                      physics: const NeverScrollableScrollPhysics(),
                      child: _bloqueInfoDe(t, context, r, ts),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
