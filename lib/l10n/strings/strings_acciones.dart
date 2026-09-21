// ─────────────────────────────────────────────────────────────
// strings_acciones.dart — Textos de las acciones de un ítem (lote/
// exportar): errores al cargar el detalle y feedback de exportación
// (título del diálogo nativo, resumen de lo exportado y motivos de
// fallo por código). Español primario, inglés secundario.
// Se conecta con: app_localizations.dart (lo expone como `acciones`) y
// acciones_item_detalle / exportacion_playlist_ui.
// Parte del flujo: acciones de ítem (descargas y exportación).
// ─────────────────────────────────────────────────────────────

class StringsAcciones {
  final String albumNoCargado;
  final String playlistNoCargada;
  final String coleccionVacia;
  final String abrirCarpeta;

  /// Título del diálogo nativo de "elegí la carpeta".
  final String exportarTitulo;
  final String _exportOk;
  final String exportSinDescargas;
  final String exportGeneracion;
  final String exportCarga;
  final String exportFallo;

  const StringsAcciones({
    required this.albumNoCargado,
    required this.playlistNoCargada,
    required this.coleccionVacia,
    required this.abrirCarpeta,
    required this.exportarTitulo,
    required String exportOk,
    required this.exportSinDescargas,
    required this.exportGeneracion,
    required this.exportCarga,
    required this.exportFallo,
  }) : _exportOk = exportOk;

  /// Resumen de una exportación exitosa: "✓ Exportados: M3U, NFO (2 archivos)".
  String exportOk({required String tipos, required int total}) =>
      _exportOk.replaceFirst('{tipos}', tipos).replaceFirst('{n}', '$total');

  /// Mensaje según sea álbum o playlist.
  String noCargado({required bool esAlbum}) =>
      esAlbum ? albumNoCargado : playlistNoCargada;

  static const es = StringsAcciones(
    albumNoCargado: 'No se pudo cargar el álbum',
    playlistNoCargada: 'No se pudo cargar la playlist',
    coleccionVacia: 'La colección está vacía',
    abrirCarpeta: 'Abrir carpeta',
    exportarTitulo: 'Exportar playlist',
    exportOk: '✓ Exportados: {tipos} ({n} archivos)',
    exportSinDescargas: 'No hay canciones descargadas para exportar',
    exportGeneracion: 'No se pudieron generar los archivos de la playlist',
    exportCarga: 'No se pudo cargar la playlist',
    exportFallo: 'No se pudo exportar la playlist',
  );

  static const en = StringsAcciones(
    albumNoCargado: "Couldn't load the album",
    playlistNoCargada: "Couldn't load the playlist",
    coleccionVacia: 'The collection is empty',
    abrirCarpeta: 'Open folder',
    exportarTitulo: 'Export playlist',
    exportOk: '✓ Exported: {tipos} ({n} files)',
    exportSinDescargas: 'No downloaded songs to export',
    exportGeneracion: "Couldn't generate the playlist files",
    exportCarga: "Couldn't load the playlist",
    exportFallo: "Couldn't export the playlist",
  );
}
