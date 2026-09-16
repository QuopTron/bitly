// ─────────────────────────────────────────────────────────────
// overlay_compartido_fondo.dart — PART de
// overlay_compartido_contenido.dart: el fondo del overlay.
//
// No tapa la app: solo la DESENFOCA y le pone un velo del color de la
// superficie (claro u oscuro, según el tema) para que la carta se lea.
// El desenfoque pasa por DesenfoqueAdaptativo, que en gama baja
// devuelve el fondo sin blur: ahí queda solo el velo, que es gratis.
//
// Tocar el fondo (fuera de la carta) cierra el overlay.
//
// Se conecta con: overlay_compartido_contenido.dart (misma library) +
// desenfoque_adaptativo.
// Parte del flujo: enlace compartido → carta → reproducir/encolar.
// ─────────────────────────────────────────────────────────────

part of 'overlay_compartido_contenido.dart';

/// Fondo: desenfoque de lo que hay detrás + velo suave; tocar cierra.
Widget _fondoOverlay(BuildContext context, VoidCallback onDismiss) {
  final cs = Theme.of(context).colorScheme;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onDismiss,
    child: ClipRect(
      child: DesenfoqueAdaptativo(
        sigma: 16,
        child: ColoredBox(
          color: cs.surface.withValues(alpha: 0.34),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}
