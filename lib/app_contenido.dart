// ─────────────────────────────────────────────────────────────
// app_contenido.dart — Construye el contenido raíz de la app: el
// router, el overlay "te compartieron" de deep links y las capas
// de TV (lienzo de diseño fijo + puntero del control remoto) y la
// protección de layout para todas las pantallas.
// Se conecta con: app.dart (lo usa en el builder de MaterialApp).
// Parte del flujo: arranque (capa visual raíz).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'core/plataforma/sistema/servicio_deep_link.dart';
import 'shared/utilidades/plataforma/deteccion_plataforma.dart';
import 'shared/utilidades/plataforma/escala_texto.dart';
import 'shared/utilidades/plataforma/vista_tv.dart';
import 'shared/widgets/base/overlay_compartido.dart';
import 'shared/widgets/tv/puntero_tv.dart';

/// Arma el contenido raíz: el hijo del router, el overlay de deep link y las
/// capas de TV / protección de layout.
Widget construirContenidoApp({
  required BuildContext context,
  required Widget? hijo,
  required DatosDeepLink? linkCompartido,
  required VoidCallback onDismiss,
  required VoidCallback onPlay,
  required VoidCallback onAgregar,
  bool hayReproduccion = false,
}) {
  Widget contenido = Stack(
    textDirection: TextDirection.ltr,
    children: [
      if (hijo != null) hijo,
      if (linkCompartido != null)
        Positioned.fill(
          child: OverlayCompartido(
            link: linkCompartido,
            onDismiss: onDismiss,
            onPlay: onPlay,
            onAgregar: onAgregar,
            enCola: hayReproduccion,
          ),
        ),
    ],
  );

  final enTv = esSmartTV(context);

  // TV: la app se dibuja en un lienzo lógico FIJO y se escala para llenar la
  // pantalla. Con el lienzo fijo el layout es idéntico en cualquier TV.
  if (enTv) {
    contenido = vistaDisenoTv(context: context, child: contenido);
  }
  // Protección de layout para TODAS las pantallas: acota la escala de texto
  // del sistema y, si el ancho lógico quedó muy chico, escala la UI.
  contenido = protegerLayout(context: context, child: contenido);

  // En TV no hay dedo: el cursor del control remoto hace de puntero. Va por
  // ENCIMA del lienzo (fuera del escalado) para que el clic caiga donde se ve.
  if (enTv) {
    contenido = PunteroTv(child: contenido);
  }
  return contenido;
}
