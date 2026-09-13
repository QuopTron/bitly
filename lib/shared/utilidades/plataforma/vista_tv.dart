// ─────────────────────────────────────────────────────────────
// vista_tv.dart — Viewport de diseño para TV, independiente del DPI.
//
// El problema: cada televisor reporta una densidad distinta (y el usuario puede
// cambiarla en Ajustes → Pantalla). Eso cambia los dp de ancho que ve Flutter:
// una TV 1080p puede reportar 1920, 1280 o 960 dp según su densidad. Con el
// mismo código, un ancho chico entra en menos columnas de grilla y termina en
// una lista larguísima (mucho scroll), mientras que un ancho grande muestra
// todo apretado. El diseño queda a merced del panel.
//
// La solución: en TV la app se dibuja SIEMPRE en un lienzo lógico fijo
// ([anchoDisenoTv] de ancho, 16:9 por defecto) y ese lienzo se escala para
// llenar la pantalla. Así el layout es idéntico en cualquier televisor — mismas
// columnas, mismos tamaños relativos, mismo scroll — sin importar el DPI. El
// alto sale del aspecto REAL del panel, así que no hay deformación.
//
// Se conecta con: app.dart (lo aplica en el builder de MaterialApp cuando
// esSmartTV) y puntero_tv (que va por ENCIMA, para que el cursor se dibuje en
// píxeles reales y el clic caiga donde se ve).
// Parte del flujo: presentación (elección de layout global).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'deteccion_plataforma.dart';

/// Ancho del lienzo lógico de TV. Es el ancho al que está pensado el layout de
/// escritorio, así que las grillas y las columnas entran igual en todas las TV.
const double anchoDisenoTv = 1280;

/// Envuelve [child] en el lienzo de diseño de TV (no-op fuera de TV).
///
/// Presenta a la app un tamaño lógico fijo y la escala para llenar la pantalla:
/// el diseño deja de depender del DPI reportado por el televisor.
Widget vistaDisenoTv({
  required BuildContext context,
  required Widget child,
}) {
  if (!esSmartTV(context)) return child;

  final real = MediaQuery.of(context);
  final tam = real.size;
  if (!tam.width.isFinite || !tam.height.isFinite || tam.width <= 0) {
    return child;
  }

  // Mismo aspecto que el panel real → el escalado no deforma nada.
  final alto = anchoDisenoTv * tam.height / tam.width;
  final factor = tam.width / anchoDisenoTv;

  return MediaQuery(
    data: real.copyWith(
      size: Size(anchoDisenoTv, alto),
      // Los insets también se pasan al lienzo: si una TV reporta barras, la app
      // las sigue viendo en la misma proporción.
      padding: real.padding * factor,
      viewPadding: real.viewPadding * factor,
      viewInsets: real.viewInsets * factor,
    ),
    child: ClipRect(
      child: FittedBox(
        // El alto ya respeta el aspecto real, así que llenar no deforma.
        fit: BoxFit.fill,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: anchoDisenoTv,
          height: alto,
          child: child,
        ),
      ),
    ),
  );
}
