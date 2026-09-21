// ─────────────────────────────────────────────────────────────
// settings_sheet_nav.dart — PART de settings_sheet_new.dart: el
// navegador del menú de Ajustes.
//
// Elige cómo se muestran las 7 pestañas según la pantalla: RIEL vertical
// a la izquierda del contenido cuando hay ancho (PC, TV, tablet apaisada),
// y FILA de burbujas —que corre en horizontal y centra sola la activa—
// en celular o ventana angosta, para que ninguna etiqueta quede ilegible.
//
// El riel tiene DOS variantes: el de PC (settings_sheet_nav_riel.dart) y el de
// TV (settings_sheet_nav_riel_tv.dart), que va más ancho, con filas grandes y a
// toda la altura porque se navega a metros con el puntero. TV se pregunta
// primero: una tele ancha también entraría en el layout de escritorio.
//
// Se conecta con: settings_sheet_nav_riel.dart (riel de PC),
// settings_sheet_nav_riel_tv.dart (riel de TV), settings_sheet_nav_burbujas.dart
// (fila) y settings_sheet_entry.dart (los íconos y el orden de las pestañas).
// Parte del flujo: Ajustes → navegación entre pestañas.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Ancho mínimo de una burbuja: por debajo de esto la etiqueta deja de
/// leerse, así que en vez de encogerlas la fila se vuelve deslizable.
const double _anchoMinimoBurbuja = 62;

/// True cuando el menú de Ajustes usa el riel lateral. Se apoya en el
/// selector de layout de la app (PC, TV o ventana ancha), así el menú y
/// el resto de las vistas coinciden en dónde cambia el diseño.
bool ajustesUsaRiel(BuildContext context) => usarLayoutEscritorio(context);

/// Navegador del menú de Ajustes: riel en pantalla ancha, burbujas en el
/// resto. Mismo índice en las dos: el que toca el usuario es el de la
/// pestaña que se abre.
class _NavAjustes extends StatelessWidget {
  final int? currentIndex;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final void Function(int index) onTap;

  const _NavAjustes({
    required this.currentIndex,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (ajustesUsaRiel(context)) {
      if (usarLayoutTv(context)) {
        return _RielAjustesTv(
          currentIndex: currentIndex,
          glowColor: glowColor,
          onBg: onBg,
          r: r,
          onTap: onTap,
        );
      }
      return _RielAjustes(
        currentIndex: currentIndex,
        glowColor: glowColor,
        onBg: onBg,
        r: r,
        onTap: onTap,
      );
    }
    return _BubbleTabsRow(
      currentIndex: currentIndex,
      glowColor: glowColor,
      onBg: onBg,
      r: r,
      onTap: onTap,
    );
  }
}
