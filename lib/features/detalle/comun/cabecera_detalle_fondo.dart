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

  // Intensidad del cover en el fondo: la carátula difuminada se apaga y el
  // gradiente con el color del cover se refuerza a medida que sube. Se aplica
  // 1:1, así cada punto porcentual vale lo mismo de punta a punta.
  final prefs = sl<ValueNotifier<PreferenciasEstilo>>().value;
  final nivel = prefs.fondoPrincipal;

  return [
    // Capa 1: base.
    Positioned.fill(child: Container(color: colorFondo)),

    // Capa 2: carátula difuminada, que se apaga con la intensidad.
    if (tienePortada)
      Positioned.fill(
        child: RepaintBoundary(
          child: Opacity(
            opacity: t * 0.65 * (1 - nivel),
            child: DesenfoqueHijo(
              // La carátula se va desenfocando con la intensidad, igual que en
              // el resto de los fondos (con su tope propio).
              sigma: EstiloHelper.sigmaPorNivel(efectosPesados ? 20 : 6, nivel),
              tope: EstiloHelper.topeSigma(efectosPesados ? 20 : 6),
              child: Transform.scale(scale: 1.5, child: _fondoBlur(st)),
            ),
          ),
        ),
      ),

    // Capa 3: gradiente con el color dominante, más fuerte cuanto más sube
    // la intensidad (cubre la carátula que se va).
    Positioned.fill(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                acento.withValues(alpha: (0.85 + 0.10 * nivel) * t),
                acento.withValues(alpha: (0.60 + 0.20 * nivel) * t),
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
