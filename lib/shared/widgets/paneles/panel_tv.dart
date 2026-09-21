// ─────────────────────────────────────────────────────────────
// panel_tv.dart — Panel de contenido de TV: la superficie sobre la que se
// apoya cada sección en una tele.
//
// Por qué no reusa el vidrio de PC: la TV se mira a metros y su lienzo lógico
// (ver vista_tv) se escala a 1080p/4K, así que un desenfoque de fondo se
// recompone en cada frame sin que se note —y en TV ya está apagado (ver
// inyeccion_perfil)—. Acá se resuelve con una superficie PLANA, márgenes
// grandes y esquinas amplias: se ve mejor de lejos y cuesta menos GPU.
//
// Es el molde de TODAS las variantes de TV (búsqueda, inicio, mi espacio,
// splash y setup), así que el look de la tele queda en un solo lugar.
//
// Se conecta con: busqueda_tv, feed_tv, mi_espacio_tv, splash_tv, setup_tv.
// Parte del flujo: presentación (variantes de TV).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../tema/colores_app.dart';

/// Ancho útil del panel de TV: el lienzo lógico mide 1280 (ver vista_tv), así
/// que deja un margen parejo de 40 por lado en cualquier televisor.
const double anchoMaximoPanelTv = 1200;

/// Margen del panel contra los bordes del lienzo.
const double margenPanelTv = 22;

/// Panel de TV: superficie plana, márgenes grandes y esquinas amplias.
class PanelTv extends StatelessWidget {
  final Widget child;

  /// Relleno interno (por defecto, el de una pantalla a 3 metros).
  final EdgeInsetsGeometry? padding;

  /// Margen contra los bordes (por defecto, [margenPanelTv]).
  final EdgeInsetsGeometry? margin;

  /// Tope de ancho (para paneles que no deben estirarse, como el splash).
  final double anchoMaximo;

  const PanelTv({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.anchoMaximo = anchoMaximoPanelTv,
  });

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(esOscuro);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoMaximo),
        child: Container(
          margin: margin ?? const EdgeInsets.all(margenPanelTv),
          padding: padding ?? const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: ColoresApp.superficie(esOscuro).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: onBg.withValues(alpha: 0.07)),
          ),
          child: child,
        ),
      ),
    );
  }
}
