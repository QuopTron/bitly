// ─────────────────────────────────────────────────────────────
// cabecera_detalle_fondo.dart — PART de cabecera_detalle.dart:
// capas de fondo de la cabecera (base sólida, carátula difuminada
// con blur según el perfil de rendimiento y gradiente con el color
// dominante) más el botón de retroceso circular flotante.
// En modo Spotify, oculta el cover borroso y usa gradiente del
// color dominante.
// Se conecta con: cabecera_detalle.dart (misma library).
// Parte del flujo: Detalle (fondo + navegación).
// ─────────────────────────────────────────────────────────────

part of 'cabecera_detalle.dart';

/// Capas 1-3 del Stack: base, carátula difuminada y gradiente.
/// En modo Spotify, oculta el cover borroso.
List<Widget> _capasFondo(
  _CabeceraDetalleState st,
  double t,
  Color acento,
  Color colorFondo,
  bool efectosPesados,
) {
  final tienePortada =
      st.widget.coverUrl != null && st.widget.coverUrl!.isNotEmpty;

  // Check Spotify mode for detail header
  final estilo = sl<ValueNotifier<EstiloVisual>>().value;
  final prefs = sl<ValueNotifier<PreferenciasEstilo>>().value;
  final spotify = estilo == EstiloVisual.spotify && prefs.fondoPrincipal;

  return [
    // Capa 1: base.
    Positioned.fill(child: Container(color: colorFondo)),

    // Capa 2: carátula difuminada (solo en Clásico o cuando Spotify no aplica).
    if (!spotify && tienePortada)
      Positioned.fill(
        child: RepaintBoundary(
          child: Opacity(
            opacity: t * 0.65,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: efectosPesados ? 20 : 6,
                sigmaY: efectosPesados ? 20 : 6,
              ),
              child: Transform.scale(scale: 1.5, child: _fondoBlur(st)),
            ),
          ),
        ),
      ),

    // Capa 3: gradiente con el color dominante.
    // En Spotify, el gradiente es más fuerte y cubre todo.
    Positioned.fill(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                acento.withValues(alpha: (spotify ? 0.95 : 0.85) * t),
                acento.withValues(alpha: (spotify ? 0.80 : 0.6) * t),
                colorFondo.withValues(alpha: 0.95),
                colorFondo,
              ],
              stops: const [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
      ),
    ),
  ];
}

/// Botón circular de retroceso flotante sobre la cabecera.
Widget _botonRetroceso(BuildContext context, double barraEstado) {
  return Positioned(
    top: barraEstado + 4,
    left: 8,
    child: GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    ),
  );
}
