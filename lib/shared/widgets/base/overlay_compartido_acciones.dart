// ─────────────────────────────────────────────────────────────
// overlay_compartido_acciones.dart — PART de
// overlay_compartido_contenido.dart: botones del overlay "te
// compartieron" — reproducir ya (círculo con glow) y omitir
// (píldora translúcida).
// Se conecta con: overlay_compartido_contenido.dart (misma library).
// Parte del flujo: arranque / llegada de deep links.
// ─────────────────────────────────────────────────────────────

part of 'overlay_compartido_contenido.dart';

/// Botón circular de reproducir el ítem compartido.
Widget _botonPlayOverlay(OverlayCompartidoContenido w, Color brillo) {
  return GestureDetector(
    onTap: w.onPlay,
    child: Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: brillo,
        boxShadow: [
          BoxShadow(
            color: brillo.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white),
    ),
  );
}

/// Botón de omitir (cierra el overlay sin reproducir).
Widget _botonOmitirOverlay(OverlayCompartidoContenido w, Responsive r) {
  return GestureDetector(
    onTap: w.onDismiss,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        'Omitir',
        style: TextStyle(
          fontSize: r.subtitleSize - 1,
          color: Colors.white.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
