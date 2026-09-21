// ─────────────────────────────────────────────────────────────
// strings_biblioteca.dart — Textos de la tarjeta "Música local"
// (Ajustes → Más): título, explicación, botón de importar carpeta,
// el resumen del import y el error. Español primario, inglés.
// Se conecta con: app_localizations.dart (lo expone como `biblioteca`)
// y settings_sheet_biblioteca_local*.
// Parte del flujo: importación de música propia del usuario.
// ─────────────────────────────────────────────────────────────

class StringsBiblioteca {
  final String titulo;
  final String descripcion;
  final String importando;
  final String importarCarpeta;
  final String elegirCarpeta;
  final String _resumen;
  final String _importado;
  final String _errorImportar;

  const StringsBiblioteca({
    required this.titulo,
    required this.descripcion,
    required this.importando,
    required this.importarCarpeta,
    required this.elegirCarpeta,
    required String resumen,
    required String importado,
    required String errorImportar,
  }) : _resumen = resumen,
       _importado = importado,
       _errorImportar = errorImportar;

  /// Resumen del último import: archivos, con ISRC y guardados.
  String resumen(int archivos, int conIsrc, int guardados) => _resumen
      .replaceFirst('{a}', '$archivos')
      .replaceFirst('{c}', '$conIsrc')
      .replaceFirst('{g}', '$guardados');

  /// Línea "Importado: ..." con el resumen del import.
  String importado(String resumen) => _importado.replaceFirst('{r}', resumen);

  /// Error de importación con el detalle.
  String errorImportar(Object e) => _errorImportar.replaceFirst('{e}', '$e');

  static const es = StringsBiblioteca(
    titulo: 'Música local',
    descripcion:
        'Importá tu música propia (compras de Amazon, archivos de iTunes Match, '
        'FLAC sueltos). Se indexa por ISRC para que la app la reconozca y no la '
        'vuelva a descargar.',
    importando: 'Importando…',
    importarCarpeta: 'Importar carpeta',
    elegirCarpeta: 'Elegí la carpeta con tu música',
    resumen: '{a} archivos · {c} con ISRC · {g} en Mi Espacio',
    importado: 'Importado: {r}',
    errorImportar: 'No se pudo importar: {e}',
  );

  static const en = StringsBiblioteca(
    titulo: 'Local music',
    descripcion:
        'Import your own music (Amazon purchases, iTunes Match files, loose '
        'FLACs). It is indexed by ISRC so the app recognizes it and does not '
        'download it again.',
    importando: 'Importing…',
    importarCarpeta: 'Import folder',
    elegirCarpeta: 'Choose the folder with your music',
    resumen: '{a} files · {c} with ISRC · {g} in My Space',
    importado: 'Imported: {r}',
    errorImportar: "Couldn't import: {e}",
  );
}
