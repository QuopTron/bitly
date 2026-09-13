// ─────────────────────────────────────────────────────────────
// acordeon_fuente_overlay.dart — PART de acordeon_fuente.dart:
// lógica de apertura/cierre del overlay del selector de fuentes —
// calcula la posición del panel (debajo del botón si cabe, si no
// arriba; recortado horizontalmente para no desbordar), crea el
// OverlayEntry con el panel flotante y el fondo que cierra al tocar.
// Se conecta con: acordeon_fuente.dart (misma library) + part panel.
// Parte del flujo: búsqueda (selector de extensión).
// ─────────────────────────────────────────────────────────────

part of 'acordeon_fuente.dart';

/// Abre el popup flotante anclado bajo el botón del selector.
void _abrirOverlaySt(_AcordeonFuenteState st) {
  final box = st._botonKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return;
  final overlay = Overlay.of(st.context, rootOverlay: true);
  final rectBoton = box.localToGlobal(Offset.zero) & box.size;
  final tamano = MediaQuery.of(st.context).size;
  final pad = 8.0;
  final filas = st._filas;
  final altoPanel = math.min(
    tamano.height * 0.55,
    filas.length * _AcordeonFuenteState._altoFila + (filas.isNotEmpty ? 4 : 0) + 12,
  );
  final disponibleAbajo = tamano.height - rectBoton.bottom;
  final colocarAbajo = disponibleAbajo >= altoPanel + pad + 8;

  final top = colocarAbajo
      ? rectBoton.bottom + 6
      : math.max(pad, rectBoton.top - altoPanel - 6);

  // Recorta el panel horizontalmente para que nunca desborde la pantalla
  // (el trigger puede quedar cerca del borde derecho en el header del feed).
  final anchoPanel = math
      .min(math.max(rectBoton.width, 200), tamano.width - 2 * pad)
      .toDouble();
  final left = rectBoton.left.clamp(pad, tamano.width - anchoPanel - pad).toDouble();

  final entrada = OverlayEntry(builder: (context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: st._cerrarOverlay,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: anchoPanel,
          child: PanelFuenteFlotante(
            esOscuro: st._esOscuro,
            onBg: st.widget.onBg,
            colorBrillo: st.widget.colorBrillo,
            filas: filas,
            fuenteSeleccionada: st.widget.fuenteSeleccionada,
            onSeleccionar: (v) {
              st.widget.onCambiada(v);
              st._cerrarOverlay();
            },
          ),
        ),
      ],
    );
  });

  st._entrada = entrada;
  st._aplicar(() => st._abierto = true);
  overlay.insert(entrada);
}