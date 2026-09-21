// ─────────────────────────────────────────────────────────────
// detalle_escritorio.dart — PART de cabecera_detalle.dart: la
// cabecera del detalle vista en PC.
//
// Por qué no reusa la de celular: en un teléfono el ListView va a
// todo el ancho porque la pantalla mide lo que mide, pero en un
// monitor esa misma columna se estira de punta a punta —el título
// queda a un metro del borde y la portada se ve chica y sola en el
// medio—. Acá el contenido se CENTRA con un ancho máximo y la portada
// toma un tamaño fijo, así la cabecera se ve igual de bien en una
// ventana de 1280 que en una de 2560.
//
// Las de TV no están acá: esa es otra cosa (dos columnas y superficie
// plana, ver detalle_tv.dart) y la eligen las páginas.
//
// Se conecta con: cabecera_detalle.dart (misma library).
// Parte del flujo: Detalle (variante PC).
// ─────────────────────────────────────────────────────────────

part of '../cabecera/cabecera_detalle.dart';

/// Ancho máximo del contenido en PC: más allá, los textos se estiran de más.
const double _anchoMaximoDetallePc = 780;

/// Alto reservado abajo para el chrome flotante (miniplayer + barra).
const double _chromeInferiorDetallePc = 150;

/// PC: contenido centrado y acotado (portada + textos + acciones + hijos).
Widget _contenidoDetalleEscritorio(
  _CabeceraDetalleState st,
  double t,
  Color acento,
  double tamanoPortada,
  double barraEstado,
) {
  final w = st.widget;
  final r = Responsive(st.context);
  // Tamaño fijo: en PC el ancho de la ventana no debe decidir la portada.
  final lado = tamanoPortada.clamp(170.0, 220.0);
  return Positioned.fill(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _anchoMaximoDetallePc),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(height: barraEstado + r.spacingM),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingL),
              child: Column(
                children: [
                  Hero(
                    tag: w.heroTag ?? w.titulo,
                    child: Container(
                      width: lado,
                      height: lado,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: acento.withValues(alpha: 0.65 * t),
                            blurRadius: 60,
                            spreadRadius: 2,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: _imgPortada(st, lado),
                    ),
                  ),
                  SizedBox(height: r.spacingM),
                  Text(
                    w.titulo,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.titleSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    w.subtitulo,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.subtitleSize,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  if (w.badge != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      w.badge!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: r.footerSize + 1,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                  if (w.acciones != null) ...[
                    SizedBox(height: r.spacingS),
                    w.acciones!,
                  ],
                  SizedBox(height: r.spacingS),
                ],
              ),
            ),
            ...w.children,
            const SizedBox(height: _chromeInferiorDetallePc),
          ],
        ),
      ),
    ),
  );
}
