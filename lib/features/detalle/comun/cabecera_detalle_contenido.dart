// ─────────────────────────────────────────────────────────────
// cabecera_detalle_contenido.dart — PART de cabecera_detalle.dart:
// capa 4 del Stack: ListView con la portada (Hero + glow), título,
// subtítulo, badge, acciones, los children del detalle y el
// espacio inferior para el chrome flotante global.
// Se conecta con: cabecera_detalle.dart (misma library).
// Parte del flujo: Detalle (contenido de la cabecera).
// ─────────────────────────────────────────────────────────────

part of 'cabecera_detalle.dart';

/// Capa 4: contenido en ListView (portada + textos + acciones + hijos).
Widget _contenidoDetalle(
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
        // Espacio inferior para el chrome flotante global
        // (miniplayer + navbar) sobre las páginas de detalle.
        SizedBox(height: MediaQuery.paddingOf(st.context).bottom + 176),
      ],
    ),
  );
}