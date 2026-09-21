// ─────────────────────────────────────────────────────────────
// strings_letras.dart — Textos del modal karaoke: traducción de
// la letra (botón, selector de idioma, estados) y los nombres de
// los idiomas destino, ya localizados.
// Español primario, inglés secundario (se elige por el locale).
// Se conecta con: app_localizations.dart (lo expone como `letras`)
// y features/reproductor/letras/hoja_letras_*.dart.
// Parte del flujo: reproductor → letras (traducción).
// ─────────────────────────────────────────────────────────────

class StringsLetras {
  final String traducirBoton;
  final String tituloSelector;
  final String ayudaSelector;
  final String traduciendo;
  final String errorTraduccion;
  final String ocultarTraduccion;
  final String detectadoPrefijo;

  /// Idiomas ofrecidos como destino: código ISO → nombre ya localizado.
  /// La lista es corta a propósito (los más pedidos en LATAM y el resto del
  /// mundo): un desplegable con 130 idiomas en un modal de media pantalla es
  /// peor de usar que uno con los que se eligen de verdad.
  final Map<String, String> idiomas;

  const StringsLetras({
    required this.traducirBoton,
    required this.tituloSelector,
    required this.ayudaSelector,
    required this.traduciendo,
    required this.errorTraduccion,
    required this.ocultarTraduccion,
    required this.detectadoPrefijo,
    required this.idiomas,
  });

  static const es = StringsLetras(
    traducirBoton: 'Traducir letra',
    tituloSelector: 'Traducir a',
    ayudaSelector:
        'El idioma de la letra se detecta solo. Se traduce línea por línea y '
        'el karaoke sigue igual.',
    traduciendo: 'Traduciendo…',
    errorTraduccion: 'No se pudo traducir la letra',
    ocultarTraduccion: 'Ocultar traducción',
    detectadoPrefijo: 'Idioma detectado:',
    idiomas: {
      'es': 'Español',
      'en': 'Inglés',
      'pt': 'Portugués',
      'fr': 'Francés',
      'it': 'Italiano',
      'de': 'Alemán',
      'ja': 'Japonés',
      'ko': 'Coreano',
      'zh-cn': 'Chino (simplificado)',
      'ru': 'Ruso',
      'hi': 'Hindi',
      'ar': 'Árabe',
    },
  );

  static const en = StringsLetras(
    traducirBoton: 'Translate lyrics',
    tituloSelector: 'Translate to',
    ayudaSelector:
        'The lyric language is detected automatically. Lines are translated '
        'one by one and the karaoke keeps working the same way.',
    traduciendo: 'Translating…',
    errorTraduccion: 'Could not translate the lyrics',
    ocultarTraduccion: 'Hide translation',
    detectadoPrefijo: 'Detected language:',
    idiomas: {
      'es': 'Spanish',
      'en': 'English',
      'pt': 'Portuguese',
      'fr': 'French',
      'it': 'Italian',
      'de': 'German',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh-cn': 'Chinese (Simplified)',
      'ru': 'Russian',
      'hi': 'Hindi',
      'ar': 'Arabic',
    },
  );
}
