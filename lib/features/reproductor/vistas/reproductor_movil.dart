// ─────────────────────────────────────────────────────────────
// reproductor_movil.dart — PART de reproductor_pagina.dart: cuerpo del
// reproductor para CELULAR.
//
// Es la disposición de siempre: una columna a pantalla completa con la portada
// o el video, la metadata, la barra de seek, los controles y la velocidad.
//
// Lo que NO tiene, a propósito: **control de volumen**. En un teléfono el
// volumen lo manejan las teclas del aparato, así que un deslizador en pantalla
// sería un segundo volumen (el de la app) peleando con el del sistema. Ese
// control vive aparte y solo lo usan las variantes de PC y TV.
//
// Se conecta con: vistas/vista_reproductor (misma library) +
// reproductor_pagina_piezas (las piezas).
// Parte del flujo: reproductor (variante celular).
// ─────────────────────────────────────────────────────────────

part of '../pagina/base/reproductor_pagina.dart';

/// Cuerpo de celular: columna a pantalla completa, sin volumen en pantalla.
Widget _cuerpoReproductorMovil(_VistaReproductor v) {
  final r = v.r;
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
    child: Column(
      children: [
        const Spacer(flex: 1),
        _areaPortadaVideo(v.st, v.context, r, v.esOscuro, v.track, v.caratula),
        const Spacer(flex: 1),
        _metadataTrack(v.context, r, v.track, v.activo),
        const Spacer(flex: 1),
        _barraSeek(v.context, r, v.esOscuro),
        SizedBox(height: r.spacingM),
        _filaControles(v.st, v.context, r, v.esOscuro, v.cola, v.track),
        SizedBox(height: r.spacingL),
        _selectorVelocidad(v.context, r, v.esOscuro, v.reproductor),
        SizedBox(height: r.spacingXL),
      ],
    ),
  );
}
