// ─────────────────────────────────────────────────────────────
// hoja_letras_util.dart — PART de hoja_letras.dart: utilidades de
// la hoja — color real del panel (fondo + velo + tono dominante de
// la carátula) para el contraste, sincronización del scroll con la
// línea activa y las letras planas como fallback sin timestamps.
// Se conecta con: hoja_letras.dart (misma library) + paleta_portada.
// Parte del flujo: reproductor (letras, utilidades).
// ─────────────────────────────────────────────────────────────

part of 'hoja_letras.dart';

/// Centra la línea activa; solo cuando realmente cambia (una vez por línea).
void _sincronizarScroll(_HojaLetrasState st, int nuevoIndice, double altoViewport) {
  if (nuevoIndice == st._indiceActivo && altoViewport == st._altoViewport) {
    return;
  }
  final altoLinea = 56.0;
  final anterior = st._indiceActivo;
  st._indiceActivo = nuevoIndice;
  st._altoViewport = altoViewport;
  if (nuevoIndice == anterior) return;
  if (!st._scroll.hasClients) return;
  final objetivo = (nuevoIndice * altoLinea -
          altoViewport / 2 +
          altoLinea / 2)
      .clamp(0.0, double.infinity);
  st._scroll.animateTo(
    objetivo,
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeOutCubic,
  );
}

/// Color real del panel detrás del texto: el fondo sólido mezclado con el
/// velo (y, si hay, el tono dominante de la carátula desenfocada). El
/// contraste corre contra ESTO para que las letras se lean sobre cualquier
/// arte.
Color _colorPanel(bool esOscuro, PaletaPortada? paleta) {
  final fondo =
      esOscuro ? const Color(0xFF141414) : const Color(0xFFF6F6F6);
  final velo = (esOscuro ? Colors.black : Colors.white)
      .withValues(alpha: esOscuro ? 0.68 : 0.5);
  final conVelo = Color.lerp(fondo, velo, 0.5)!;
  if (paleta == null) return conVelo;
  return Color.lerp(conVelo, paleta.dominante, esOscuro ? 0.30 : 0.22)!;
}

/// Letras planas (sin timestamps) como fallback del karaoke.
Widget _letrasPlanas(_HojaLetrasState st, Responsive r, bool esOscuro) {
  final panelBg = _colorPanel(esOscuro, null);
  final fg = mejorNeutro(panelBg);
  return Center(
    child: SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: r.spacingXL, vertical: r.spacingL),
      child: Text(
        st._textoPlano,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontSize: r.footerSize + 2,
          height: 1.7,
        ),
      ),
    ),
  );
}

/// Formatea una duración como m:ss o h:mm:ss.
String _formatearDuracion(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}