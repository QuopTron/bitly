// ─────────────────────────────────────────────────────────────
// reproductor_tv.dart — PART de reproductor_pagina.dart: cuerpo del
// reproductor para TV.
//
// En una tele no hay mouse ni dedo: hay un puntero del control remoto y se mira
// a metros. Por eso:
//   1. DOS COLUMNAS —portada o video a la izquierda, controles a la derecha—
//      en vez de una columna centrada: aprovecha el ancho y deja los controles
//      en una zona fija;
//   2. el CONTROL DE VOLUMEN va más ancho que en PC (ver
//      controles/volumen_reproductor): es lo que se toca desde el sillón;
//   3. el gesto de arrastrar para cerrar NO se aplica (lo decide el marco, ver
//      reproductor_pagina_build): en una tele se sale con la tecla de atrás.
//
// Se conecta con: vistas/vista_reproductor (misma library) +
// controles/volumen_reproductor.
// Parte del flujo: reproductor (variante TV).
// ─────────────────────────────────────────────────────────────

part of '../pagina/base/reproductor_pagina.dart';

/// Cuerpo de TV: dos columnas, controles a la derecha y volumen ancho.
Widget _cuerpoReproductorTv(_VistaReproductor v) {
  final r = v.r;
  return Padding(
    padding: const EdgeInsets.fromLTRB(34, 8, 34, 26),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Center(
            child: _areaPortadaVideo(
              v.st,
              v.context,
              r,
              v.esOscuro,
              v.track,
              v.caratula,
            ),
          ),
        ),
        const SizedBox(width: 34),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _metadataTrack(v.context, r, v.track, v.activo),
              SizedBox(height: r.spacingL),
              _barraSeek(v.context, r, v.esOscuro),
              SizedBox(height: r.spacingM),
              _filaControles(v.st, v.context, r, v.esOscuro, v.cola, v.track),
              SizedBox(height: r.spacingM),
              // Volumen: solo PC y TV, y acá más ancho que en PC.
              const Center(child: VolumenReproductor(anchoDeslizador: 220)),
              SizedBox(height: r.spacingL),
              _selectorVelocidad(v.context, r, v.esOscuro, v.reproductor),
            ],
          ),
        ),
      ],
    ),
  );
}
