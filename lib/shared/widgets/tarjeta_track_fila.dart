// ─────────────────────────────────────────────────────────────
// tarjeta_track_fila.dart — PART de tarjeta_track.dart: fila de
// contenido interior de la tarjeta — miniatura con borde y sombra,
// columna de título/artista y el cluster de acciones a la derecha.
// Recibe la tarjeta y los colores ya calculados por el cuerpo.
// Se conecta con: tarjeta_track.dart (misma library) + imagen_portada.
// Parte del flujo: búsqueda, feed, mi espacio (listas de tracks).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_track.dart';

/// Fila con miniatura + textos + acciones de la tarjeta de track.
Widget _filaContenidoTrack(
  TarjetaTrack t,
  BuildContext context,
  Responsive r,
  AppLocalizations loc,
  Color fg,
  Color colorApagado,
  Color fondoFallback,
  Color colorIconoFallback,
  double tamanoIcono,
  double ts,
  bool esOscuro,
  bool efectosPesados,
) {
  return Padding(
    padding: EdgeInsets.all(r.spacingS),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: r.subtitleSize * 5.5,
            height: r.subtitleSize * 5.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: t.coverUrl == null ? fondoFallback : null,
              border: Border.all(
                color: ColoresApp.borde(esOscuro),
                width: 0.5,
              ),
              boxShadow: efectosPesados
                  ? [
                      BoxShadow(
                        color: ColoresApp.sombra(esOscuro).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: t.coverUrl != null
                ? imagenDesdeUrl(
                    t.coverUrl,
                    ajuste: BoxFit.cover,
                    fallback: Icon(
                      Icons.music_note,
                      color: colorIconoFallback,
                      size: 34,
                    ),
                  )
                : Icon(
                    Icons.music_note,
                    color: colorIconoFallback,
                    size: 34,
                  ),
          ),
        ),
        SizedBox(width: r.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.titulo,
                style: TextStyle(
                  fontSize: r.subtitleSize * ts,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: fg,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2),
              Text(
                t.subtitulo,
                style: TextStyle(
                  fontSize: (r.footerSize + 1) * ts,
                  color: colorApagado,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (t.mostrarAcciones)
          _clusterAccionesDe(
            t,
            context,
            r,
            loc,
            tamanoIcono,
            colorApagado,
            fg,
            esOscuro,
          ),
      ],
    ),
  );
}