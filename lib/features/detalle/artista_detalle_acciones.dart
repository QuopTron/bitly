// ─────────────────────────────────────────────────────────────
// artista_detalle_acciones.dart — PART de artista_detalle_pagina.dart:
// acciones de cabecera — fila de botones vidrio con el botón de
// reproducir (relleno) que inicia la reproducción de los top tracks.
// Se conecta con: artista_detalle_pagina.dart (misma library) +
// boton_accion_vidrio + cubit_cola.
// Parte del flujo: Detalle → artista (acciones).
// ─────────────────────────────────────────────────────────────

part of 'artista_detalle_pagina.dart';

/// Fila de botones de la cabecera: reproducir los top tracks.
Widget _filaAccionesArtista(
  _ArtistaDetallePaginaState st,
  BuildContext context,
  DatosVistaArtista d,
) {
  final r = Responsive(context);
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      BotonAccionVidrio(
        icono: Icons.play_arrow_rounded,
        relleno: true,
        onTap: d.tracks.isNotEmpty
            ? () => sl<CubitCola>().reproducirConContexto(d.tracks, d.tracks.first)
            : null,
      ),
      SizedBox(width: r.spacingS),
    ],
  );
}