// ─────────────────────────────────────────────────────────────
// reproductor_video_local.dart — PART de cubit_reproductor.dart:
// archivos locales del reproductor: refresh del mapa de archivos
// locales (con TTL), registro inmediato de descargas nuevas y la
// resolución de la URI local de un track (historial + fingerprints
// de nombre/ISRC + escaneo por id). El directorio de caché y el
// borrado de temp viven en reproductor_archivos_temp.dart; el video
// de fondo en reproductor_video_fondo.dart.
// Se conecta con: reproductor_archivos_temp.dart (misma library).
// Parte del flujo: reproducción (local-first).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Archivos locales. Mixin aplicado en CubitReproductor.
mixin ReproductorVideoLocal on ReproductorArchivosTemp {
  /// Carga de archivos locales — la implementación concreta vive en
  /// ReproductorLocales (arriba en la cadena); aquí solo la declaración.
  Future<void> _loadLocalFiles();

  /// Recarga los archivos locales SOLO si el caché expiró (TTL), para no
  /// llamar a getDownloadHistory en cada cambio de track.
  Future<void> _refreshArchivosLocales() async {
    final now = DateTime.now();
    if (_archivosLocalesCargadosEn != null &&
        now.difference(_archivosLocalesCargadosEn!) < _ttlArchivosLocales) {
      return;
    }
    await _loadLocalFiles();
  }

  /// Recarga el caché de archivos locales de inmediato, ignorando el TTL.
  /// Lo llama DownloadCubit cuando una descarga termina para que el player
  /// encuentre el archivo nuevo ya, sin esperar el TTL.
  Future<void> forzarActualizarArchivosLocales() async {
    _archivosLocalesCargadosEn = null;
    await _loadLocalFiles();
  }

  /// Registra un archivo recién descargado en el mapa local para que la
  /// reproducción lo encuentre sin esperar una recarga de la BD.
  void registrarArchivoLocal({
    required String trackId,
    required String filePath,
    String? providerTrackId,
    String? trackName,
    String? artistName,
    String? isrc,
  }) {
    if (trackId.isNotEmpty) _archivosLocales[trackId] = filePath;
    if (providerTrackId != null && providerTrackId != trackId) {
      _archivosLocales[providerTrackId] = filePath;
    }
    if (trackName != null && trackName.isNotEmpty) {
      _archivosLocales[huellaDesdeNombre(trackName, artistName ?? '')] = filePath;
    }
    if (isrc != null && isrc.isNotEmpty) {
      _archivosLocales[huellaIsrc(isrc)] = filePath;
    }
  }

  /// Resuelve la URI local (file://) de [track] o null si no existe:
  /// 1. historial de descargas por id canónico/normalizado
  /// 2. nombre-fingerprint (misma canción de cualquier proveedor)
  /// 3. ISRC (id de grabación canónico compartido por todos)
  /// 4. adivinanza por id + extensión en el directorio de descargas
  /// 5. escaneo por prefijo del id (último recurso)
  String? _resolveLocalUri(ItemFeed track) {
    final idsAProbar = {track.id, normalizarId(track.id)};

    // 1. Desde el mapa del historial (ruta real de la BD)
    for (final id in idsAProbar) {
      final ruta = _archivosLocales[id];
      if (ruta != null && File(ruta).existsSync()) {
        return 'file://${ruta.replaceAll('\\', '/')}';
      }
    }

    // 2. Match cross-fuente por nombre-fingerprint: un track descargado de
    // deezer/amazon reproduce local aunque se seleccione de un feed de
    // soundcloud/spotify con ids distintos.
    if (track.name.isNotEmpty) {
      final huella = huellaDesdeNombre(track.name, track.artists ?? '');
      final ruta = _archivosLocales[huella];
      if (ruta != null && File(ruta).existsSync()) {
        return 'file://${ruta.replaceAll('\\', '/')}';
      }
    }

    // 3. Match por ISRC — el identificador canónico de grabación compartido
    // por todos los proveedores.
    final isrcTrack = (track.isrc ?? '').trim();
    if (isrcTrack.isNotEmpty) {
      final ruta = _archivosLocales[huellaIsrc(isrcTrack)];
      if (ruta != null && File(ruta).existsSync()) {
        return 'file://${ruta.replaceAll('\\', '/')}';
      }
    }

    // 4. Adivinar por id + extensión
    final sep = Platform.pathSeparator;
    final exts = ['flac', 'mp3', 'm4a', 'ogg', 'wav', 'aac', 'opus'];
    if (_rutaDescargas != null) {
      for (final id in idsAProbar) {
        for (final ext in exts) {
          final porId = '$_rutaDescargas$sep$id.$ext';
          if (File(porId).existsSync()) {
            return 'file://${porId.replaceAll('\\', '/')}';
          }
          final porIdSinExt = '$_rutaDescargas$sep$id';
          if (File(porIdSinExt).existsSync()) {
            return 'file://${porIdSinExt.replaceAll('\\', '/')}';
          }
        }
      }
    }

    // 5. Último recurso: cualquier archivo del directorio que empiece con el
    // id (nombres canónicos y hardlinks).
    if (_rutaDescargas != null) {
      try {
        final dir = Directory(_rutaDescargas!);
        if (dir.existsSync()) {
          final candidatos = dir.listSync().whereType<File>();
          final idsLower = idsAProbar.map((e) => e.toLowerCase()).toSet();
          for (final f in candidatos) {
            final nombre =
                f.path.split(Platform.pathSeparator).last.toLowerCase();
            if (idsLower.any((id) => nombre.startsWith(id))) {
              return 'file://${f.path.replaceAll('\\', '/')}';
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }
}