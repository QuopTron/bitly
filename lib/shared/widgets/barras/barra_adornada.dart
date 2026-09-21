// ─────────────────────────────────────────────────────────────
// barra_adornada.dart — El ADORNO de una barra: le da forma al borde de
// arriba (esquinas o OLAS) y le dibuja encima su calcomanía (sticker).
//
// Existe para que el navbar y el miniplayer no repitan el mismo Stack,
// ClipPath y CustomPaint: los dos envuelven su contenido con este widget y
// listo. Con esquinas hace lo de siempre (ClipRRect); con olas recorta el
// borde ondulado y pinta su trazo siguiendo la ola (ver olas_barra).
//
// El adorno es del COFRE de diseños (Ajustes → Apariencia → Barras) y la
// cantidad de olas sale del control, así que el usuario pone más o menos.
//
// Se conecta con: barra_navegacion_flotante + miniplayer (lo usan) +
// catalogo_disenos_barra (AdornoBarra) + olas_barra + sticker_barra.
// Parte del flujo: presentación (navbar y miniplayer).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/modelos/usuario/catalogo_disenos_barra.dart';
import 'olas_barra.dart';
import 'sticker_barra.dart';

/// Envuelve el contenido de una barra con su adorno y su calcomanía.
class BarraAdornada extends StatelessWidget {
  final Widget child;

  /// Cómo se dibuja el borde de arriba (esquinas u olas).
  final AdornoBarra adorno;

  /// Cantidad de olas (solo se usa con [AdornoBarra.olas]).
  final int olas;

  /// Redondeo de las esquinas de arriba (solo con esquinas).
  final double radioArriba;

  /// Color del trazo que sigue la ola.
  final Color colorBorde;

  /// Id de la calcomanía ('' = ninguna) y su color.
  final String sticker;
  final Color colorSticker;

  const BarraAdornada({
    super.key,
    required this.child,
    required this.adorno,
    required this.olas,
    required this.radioArriba,
    required this.colorBorde,
    this.sticker = '',
    required this.colorSticker,
  });

  bool get _esOlas => adorno == AdornoBarra.olas;

  @override
  Widget build(BuildContext context) {
    var contenido = child;
    if (sticker.isNotEmpty) {
      contenido = Stack(
        fit: StackFit.passthrough,
        children: [
          contenido,
          Positioned(
            top: 2,
            right: 8,
            child: StickerBarra(id: sticker, color: colorSticker),
          ),
        ],
      );
    }
    if (!_esOlas) {
      return ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radioArriba)),
        child: contenido,
      );
    }
    // Con olas: se pinta el trazo del borde ANTES de recortar, así sigue la
    // ola en vez de quedar como una línea recta arriba.
    final dibujado = Stack(
      fit: StackFit.passthrough,
      children: [
        contenido,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: PintorOlas(olas, colorBorde)),
          ),
        ),
      ],
    );
    return ClipPath(clipper: ClipperOlas(olas), child: dibujado);
  }
}
