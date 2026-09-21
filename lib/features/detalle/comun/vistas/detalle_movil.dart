// ─────────────────────────────────────────────────────────────
// detalle_movil.dart — PART de cabecera_detalle.dart: la cabecera del
// detalle vista en CELULAR.
//
// Es la disposición de siempre: capa 4 del Stack con un ListView a todo el
// ancho —portada (Hero + glow), título, subtítulo, badge, acciones y los
// children— y el espacio inferior para el chrome flotante global MÁS las 3
// teclas del sistema. En una PC esa columna estirada de punta a punta se ve
// mal, así que ahí entra detalle_escritorio.dart, con el contenido centrado y
// acotado.
//
// Se conecta con: cabecera_detalle.dart (misma library).
// Parte del flujo: Detalle (variante celular).
// ─────────────────────────────────────────────────────────────

part of '../cabecera/cabecera_detalle.dart';

/// Celular: ListView a todo el ancho (portada + textos + acciones + hijos).
Widget _contenidoDetalleMovil(
  _CabeceraDetalleState st,
  double t,
  Color acento,
  double tamanoPortada,
  double barraEstado,
) {
  final w = st.widget;
  final r = Responsive(st.context);
  return Positioned.fill(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(height: barraEstado),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spacingS),
          child: Column(
            children: [
              // Portada con Hero + glow.
              Hero(
                tag: w.heroTag ?? w.titulo,
                child: Container(
                  width: tamanoPortada,
                  height: tamanoPortada,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: acento.withValues(alpha: 0.7 * t),
                        blurRadius: 50,
                        spreadRadius: 4,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: _imgPortada(st, tamanoPortada),
                ),
              ),
              SizedBox(height: r.spacingM),
              Text(
                w.titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.subtitleSize * 1.3,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                w.subtitulo,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.subtitleSize * 0.9,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              if (w.badge != null) ...[
                SizedBox(height: 6),
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
        // Espacio inferior para el chrome flotante global (miniplayer +
        // navbar) MÁS el menú de navegación del celular: sin él, el último
        // botón de la lista queda debajo de las 3 teclas del sistema.
        SizedBox(height: insetInferiorSistema(st.context) + 176),
      ],
    ),
  );
}
