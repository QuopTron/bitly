// ─────────────────────────────────────────────────────────────
// reproductor_escritorio.dart — PART de reproductor_pagina.dart: cuerpo del
// reproductor para PC.
//
// Dos diferencias con el celular, pensadas para una ventana con mouse:
//   1. el contenido va CENTRADO con ancho máximo (en un monitor ancho, una
//      columna estirada de punta a punta se ve mal y aleja los controles);
//   2. suma el CONTROL DE VOLUMEN (ver controles/volumen_reproductor): en una
//      PC no hay teclas de volumen del aparato a mano, y el usuario espera
//      poder bajarlo sin salir de la app.
//
// Se conecta con: vistas/vista_reproductor (misma library) +
// controles/volumen_reproductor.
// Parte del flujo: reproductor (variante PC).
// ─────────────────────────────────────────────────────────────

part of '../pagina/base/reproductor_pagina.dart';

/// Ancho máximo del contenido en PC: más allá, los controles quedan lejos.
const double _anchoMaximoReproductorPc = 660;

/// Cuerpo de PC: columna centrada con ancho máximo y control de volumen.
Widget _cuerpoReproductorEscritorio(_VistaReproductor v) {
  final r = v.r;
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _anchoMaximoReproductorPc),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
        child: Column(
          children: [
            const Spacer(flex: 1),
            _areaPortadaVideo(
              v.st,
              v.context,
              r,
              v.esOscuro,
              v.track,
              v.caratula,
            ),
            const Spacer(flex: 1),
            _metadataTrack(v.context, r, v.track, v.activo),
            const Spacer(flex: 1),
            _barraSeek(v.context, r, v.esOscuro),
            SizedBox(height: r.spacingM),
            _filaControles(v.st, v.context, r, v.esOscuro, v.cola, v.track),
            SizedBox(height: r.spacingS),
            // Volumen: solo PC y TV.
            const Center(child: VolumenReproductor()),
            SizedBox(height: r.spacingS),
            _selectorVelocidad(v.context, r, v.esOscuro, v.reproductor),
            SizedBox(height: r.spacingXL),
          ],
        ),
      ),
    ),
  );
}
