// ─────────────────────────────────────────────────────────────
// overlay_compartido_acciones.dart — PART de
// overlay_compartido_contenido.dart: las opciones de abajo.
//
// Dos píldoras chicas: la principal invierte los colores del tema
// (negra en tema claro, blanca en oscuro) y dice "Reproducir" o
// "Agregar a la cola" según lo que ya esté sonando; al lado, "Omitir".
// Las dos cierran la carta y los textos salen del l10n.
//
// Se conecta con: overlay_compartido_contenido.dart (misma library).
// Parte del flujo: enlace compartido → carta → reproducir/encolar.
// ─────────────────────────────────────────────────────────────

part of 'overlay_compartido_contenido.dart';

/// Opciones de la carta: acción principal + omitir.
Widget _accionesOverlay(
  ColorScheme cs,
  OverlayCompartidoContenido w,
  Responsive r,
  StringsSetup l,
) {
  return Wrap(
    alignment: WrapAlignment.center,
    spacing: r.spacingS + 2,
    runSpacing: r.spacingS,
    children: [
      _pildora(
        cs,
        r,
        texto: w.enCola ? l.agregarACola : l.reproducir,
        icono: w.enCola
            ? Icons.playlist_add_rounded
            : Icons.play_arrow_rounded,
        onTap: w.onAccion,
        relleno: true,
      ),
      _pildora(
        cs,
        r,
        texto: l.notificationSkip,
        icono: Icons.close_rounded,
        onTap: w.onDismiss,
        relleno: false,
      ),
    ],
  );
}

/// Píldora de acción: llena (principal) o translúcida (secundaria).
Widget _pildora(
  ColorScheme cs,
  Responsive r, {
  required String texto,
  required IconData icono,
  required VoidCallback onTap,
  required bool relleno,
}) {
  final colorTexto = relleno ? cs.surface : cs.onSurface;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      constraints: BoxConstraints(minHeight: r.continueButtonHeight - 8),
      padding: EdgeInsets.symmetric(
        horizontal: r.spacingM + 4,
        vertical: r.spacingS,
      ),
      decoration: BoxDecoration(
        color: relleno ? cs.onSurface : cs.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: relleno
              ? Colors.transparent
              : cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: r.footerSize + 4, color: colorTexto),
          SizedBox(width: r.spacingS),
          Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.footerSize + 1,
              fontWeight: FontWeight.w700,
              color: colorTexto,
            ),
          ),
        ],
      ),
    ),
  );
}
