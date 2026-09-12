// estilo_visual.dart — Estilos visuales disponibles: Clásico
// (monocromático actual) y Spotify (colores dinámicos del cover).

/// Estilo visual de la interfaz.
enum EstiloVisual {
  /// Diseño actual: monocromático (negro/blanco/neutros).
  clasico,

  /// Diseño Spotify: colores dinámicos extraídos del cover en cards,
  /// backgrounds y reproductor.
  spotify,
}

/// Extensiones de utilidad para [EstiloVisual].
extension EstiloVisualExt on EstiloVisual {
  /// Clave de persistencia en la base de datos.
  String get clave {
    switch (this) {
      case EstiloVisual.clasico:
        return 'clasico';
      case EstiloVisual.spotify:
        return 'spotify';
    }
  }

  /// Nombre legible para UI.
  String get nombre {
    switch (this) {
      case EstiloVisual.clasico:
        return 'Clásico';
      case EstiloVisual.spotify:
        return 'Spotify';
    }
  }

  /// Descripción corta para UI.
  String get descripcion {
    switch (this) {
      case EstiloVisual.clasico:
        return 'Diseño monocromático limpio';
      case EstiloVisual.spotify:
        return 'Colores dinámicos del cover';
    }
  }

  /// Convierte una clave de BD a [EstiloVisual].
  static EstiloVisual desdeClave(String? clave) {
    if (clave == 'spotify') return EstiloVisual.spotify;
    return EstiloVisual.clasico;
  }
}
