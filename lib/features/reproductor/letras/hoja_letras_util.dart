// ─────────────────────────────────────────────────────────────
// hoja_letras_util.dart — PART de hoja_letras.dart: utilidades de
// la hoja — color real del panel (fondo + velo + tono dominante de
// la carátula) para el contraste, sincronización del scroll con la
// línea activa y las letras planas como fallback sin timestamps.
// Se conecta con: hoja_letras.dart (misma library) + paleta_portada.
// Parte del flujo: reproductor (letras, utilidades).
// ─────────────────────────────────────────────────────────────

part of 'hoja_letras.dart';

/// Desfase aplicado a la posición del reproductor para el karaoke.
///
/// Las letras LRC suelen venir un pelo ADELANTADAS respecto de la voz (la marca
/// es de cuando arranca el verso, no de cuando se escucha), así que el resaltado
/// corría antes que el cantante. Con este retraso la línea se enciende ~0.5s
/// después de su marca y el karaoke sigue al cantante en vez de anticiparlo.
const Duration _retrasoLetras = Duration(milliseconds: 500);

/// Posición para el karaoke: la del reproductor menos el desfase, sin bajar de
/// cero (al inicio de la canción no hay nada que retrasar).
Duration _posicionLetras(Duration posicion) {
  if (posicion <= _retrasoLetras) return Duration.zero;
  return posicion - _retrasoLetras;
}

/// Centra la línea activa; solo cuando realmente cambia (una vez por línea).
///
/// Se centra por la POSICIÓN REAL de la línea (Scrollable.ensureVisible con
/// alignment 0.5): las líneas largas envuelven en dos renglones, así que un
/// alto fijo por índice (`indice * 56`) dejaba el centrado desplazado justo en
/// las líneas que más importan. La animación se agenda al frame siguiente
/// porque la clave de la línea activa se monta en el rebuild que viene.
void _sincronizarScroll(
  _HojaLetrasState st,
  int nuevoIndice,
  double altoViewport,
) {
  if (nuevoIndice == st._indiceActivo && altoViewport == st._altoViewport) {
    return;
  }
  final anterior = st._indiceActivo;
  st._indiceActivo = nuevoIndice;
  st._altoViewport = altoViewport;
  if (nuevoIndice == anterior) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Otra línea tomó el turno mientras se esperaba el frame: su propio aviso
    // se encarga; este ya no aplica.
    if (st._indiceActivo != nuevoIndice) return;
    final ctx = st._claveActiva.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _centrarPorEstimacion(st, nuevoIndice, altoViewport);
  });
}

/// Fallback cuando la línea activa aún no está montada (primer frame o índice
/// fuera del área construida por el ListView): centra con el alto estimado de
/// un renglón, igual que antes. El resultado es correcto para líneas de una
/// sola línea y aproximado para las que envuelven.
void _centrarPorEstimacion(
  _HojaLetrasState st,
  int indice,
  double altoViewport,
) {
  if (!st._scroll.hasClients) return;
  const altoLinea = 56.0;
  final tope = st._scroll.position.maxScrollExtent;
  final objetivo = (indice * altoLinea - altoViewport / 2 + altoLinea / 2)
      .clamp(0.0, tope);
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
  final fondo = esOscuro ? const Color(0xFF141414) : const Color(0xFFF6F6F6);
  final velo = (esOscuro ? Colors.black : Colors.white).withValues(
    alpha: esOscuro ? 0.68 : 0.5,
  );
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
        horizontal: r.spacingXL,
        vertical: r.spacingL,
      ),
      child: Text(
        st._textoPlano,
        textAlign: TextAlign.center,
        style: TextStyle(color: fg, fontSize: r.footerSize + 2, height: 1.7),
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
