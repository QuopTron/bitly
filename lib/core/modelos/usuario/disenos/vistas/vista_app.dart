// ─────────────────────────────────────────────────────────────
// vista_app.dart — Las VISTAS (ámbitos) que se personalizan por separado.
//
// Por qué existe: hasta hoy el diseño se elegía UNA vez para toda la app (un
// navbar, un miniplayer, una separación de cards). El salto de la v1.0.0 es
// que cada vista tenga su propio diseño y que lo que NO se toca lo HEREDE del
// estilo global — por eso las vistas son una lista cerrada y no una etiqueta
// suelta: el menú, el guardado y la herencia necesitan saber cuáles hay.
//
// El orden de [VistaApp.values] es el orden en que el menú las muestra.
// Los nombres NO viven acá: son texto localizado (StringsVistas), igual que
// en el cofre de las barras.
//
// Se conecta con: diseno_vista.dart (qué se cambia en cada una) +
// preferencias_vistas.dart (dónde se guarda) + apariencia_vistas_helper.dart
// (cómo se resuelve).
// Parte del flujo: presentación (personalización por vista).
// ─────────────────────────────────────────────────────────────

/// Una parte de la app con diseño propio.
enum VistaApp {
  /// Inicio: el feed de novedades (la pestaña con secciones del shell).
  feed('feed'),

  /// Pantalla de Búsqueda.
  busqueda('busqueda'),

  /// Mi Espacio (biblioteca del usuario).
  miEspacio('mi_espacio'),

  /// Detalle de álbum, artista o playlist.
  detalle('detalle'),

  /// Reproductor a pantalla completa.
  reproductor('reproductor'),

  /// Hoja de Ajustes (incluidas sus pestañas).
  ajustes('ajustes'),

  /// Tutorial interactivo (overlay de pasos).
  tutorial('tutorial');

  /// Identificador estable: es lo que se guarda en la base, NO el índice del
  /// enum (agregar una vista en el medio no debe romper lo ya guardado).
  final String clave;

  const VistaApp(this.clave);

  /// Resuelve una clave guardada. Devuelve null si esa vista ya no existe: una
  /// vista que se quitó de la app no puede romper el arranque.
  static VistaApp? desdeClave(String? clave) {
    if (clave == null || clave.isEmpty) return null;
    for (final v in VistaApp.values) {
      if (v.clave == clave) return v;
    }
    return null;
  }
}
