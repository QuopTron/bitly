// ─────────────────────────────────────────────────────────────
// reproductor_limpieza.dart — PART de cubit_reproductor.dart:
// limpieza y mantenimiento: borrado de archivos de descargas (con
// sidecars .lrc/.jpg/.png y match por stems), limpieza del caché de
// stream del backend (DELETE a Go) e ID normalizado del track
// actual. El autoplay (modo radio) vive en reproductor_autoplay.dart.
// Se conecta con: reproductor_autoplay.dart (misma library).
// Parte del flujo: reproducción (mantenimiento post-playback).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Limpieza y mantenimiento. Mixin aplicado en CubitReproductor.
mixin ReproductorLimpieza on ReproductorAutoplay {
  /// Elimina entradas de [_archivosLocales] indexadas por los IDs de
  /// proveedor dados, y cualquier otra key que apunte al mismo archivo
  /// (p.ej. hash canónico que comparte path con un providerTrackId).
  /// Lo llama DownloadCubit tras borrar descargas. [borrarArchivos] true
  /// también borra los archivos físicos del disco.
  void eliminarArchivosLocalesPorProveedores(
    List<String> idsProveedor, {
    bool borrarArchivos = false,
  }) {
    final buscados = idsProveedor.toSet();
    if (buscados.isEmpty) return;

    final rutasARemover = <String>{};
    for (final id in idsProveedor) {
      final ruta = _archivosLocales.remove(id);
      if (ruta != null) rutasARemover.add(ruta);
    }
    if (rutasARemover.isNotEmpty) {
      _archivosLocales.removeWhere((_, v) => rutasARemover.contains(v));
    }

    if (borrarArchivos) {
      // Respaldo a disco: si el mapa en memoria aún no indexó un archivo
      // (app recién abierta / TTL sin refrescar), resolver los stems
      // escaneando el directorio de descargas para que ningún audio quede
      // huérfano en disco aunque la caché esté vacía.
      for (final ruta in _archivosDescargasCoincidentes(buscados)) {
        if (rutasARemover.add(ruta)) {
          _archivosLocales.removeWhere((_, v) => v == ruta);
        }
      }
      for (final ruta in rutasARemover) {
        _borrarArchivoLocal(ruta);
      }
    }
  }

  /// Escanea el directorio de descargas y devuelve las rutas cuyo nombre
  /// (sin extensión) coincide con alguno de [stems].
  Set<String> _archivosDescargasCoincidentes(Set<String> stems) {
    final out = <String>{};
    final dirPath = _rutaDescargas;
    if (dirPath == null) return out;
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return out;
      for (final f in dir.listSync(followLinks: false)) {
        if (f is! File) continue;
        final stem = _raizArchivo(f.path);
        if (stems.contains(stem)) {
          out.add(f.path);
          continue;
        }
        // Las descargas se guardan como "{id}_audio" y tras el decrypt pueden
        // quedar "{id}_audio.dec". El borrado solo recibe el id base, así que
        // también matchean prefix con frontera "_" o "." (evita {id}Otro).
        for (final w in stems) {
          if (stem.startsWith('${w}_') || stem.startsWith('$w.')) {
            out.add(f.path);
            break;
          }
        }
      }
    } catch (_) {}
    return out;
  }

  /// Nombre de archivo sin extensión (stem).
  String _raizArchivo(String path) => path
      .split(Platform.pathSeparator)
      .last
      .replaceAll(RegExp(r'\.[^.]+$'), '');

  /// Borra un archivo local del disco y sus sidecars (.lrc, .jpg, .png).
  void _borrarArchivoLocal(String ruta) {
    try {
      final file = File(ruta);
      if (file.existsSync()) {
        file.deleteSync();
        final base = ruta.substring(0, ruta.lastIndexOf('.'));
        for (final ext in ['.lrc', '.jpg', '.png', '.jpeg']) {
          final sidecar = File('$base$ext');
          if (sidecar.existsSync()) sidecar.deleteSync();
        }
        final padre = file.parent;
        if (padre.existsSync() && padre.listSync().isEmpty) {
          padre.deleteSync();
        }
      }
    } catch (_) {}
  }

  /// ID normalizado del track actual, o null si no hay.
  String? _idActualNormalizado() {
    final actual = _queueCubit.state.actual;
    if (actual == null) return null;
    return normalizarId(actual.id);
  }

  /// Envía un DELETE al backend para eliminar el archivo cacheado del track
  /// streameado en .stream_cache. No bloquea la reproducción (unawaited).
  Future<void> _limpiarCacheStream(String idNormalizado) async {
    try {
      final client = HttpClient();
      try {
        final url = 'http://127.0.0.1:55009/cache/delete/$idNormalizado.flac';
        final request = await client.deleteUrl(Uri.parse(url));
        final response = await request.close();
        await response.drain();
      } finally {
        client.close();
      }
    } catch (_) {
      // Fallo silencioso — la limpieza no debe interrumpir nada.
    }
  }
}