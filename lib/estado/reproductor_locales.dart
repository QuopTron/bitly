// ─────────────────────────────────────────────────────────────
// reproductor_locales.dart — PART de cubit_reproductor.dart:
// carga del historial de descargas para saber qué archivos existen
// localmente: indexa por ID canónico, providerTrackId, nombre-
// fingerprint e ISRC (matching cross-extensión) y escanea el
// directorio de descargas en la carga completa. Implementa el
// abstract _loadLocalFiles declarado en ReproductorVideoLocal.
// Se conecta con: reproductor_completado.dart (misma library).
// Parte del flujo: reproducción (local-first).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Carga de archivos locales. Mixin aplicado en CubitReproductor.
mixin ReproductorLocales on ReproductorCompletado {
  /// Carga el historial de descargas para saber qué archivos existen
  /// localmente. [delta]=true solo trae entradas nuevas desde
  /// [_ultimoTimestampCarga] y hace merge; [delta]=false carga completa.
  @override
  Future<void> _loadLocalFiles({bool delta = false}) async {
    try {
      final json = await di.sl<CacheDescargas>().getHistorialDescargas(
        desde: delta ? _ultimoTimestampCarga : null,
      );
      if (json.isNotEmpty && json != '[]') {
        final list = jsonDecode(json) as List;

        if (!delta) {
          _archivosLocales.clear();
        }

        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final tid = (m['id'] ?? m['trackId'] ?? m['track_id'] ?? '').toString();
          final fp = (m['filePath'] ?? m['file_path'] ?? '') as String;
          if (tid.isNotEmpty && fp.isNotEmpty && await File(fp).exists()) {
            _archivosLocales[tid] = fp;
            // Indexar también por id normalizado: los FeedItems de la UI
            // (p.ej. lista de descargas en Mi Espacio) llevan
            // `normalizarId(rawId)` como id, así el lookup local siempre gana.
            final normTid = normalizarId(tid);
            if (normTid != tid) _archivosLocales[normTid] = fp;
          }

          final providerTrackId = (m['providerTrackId'] ?? '').toString();
          if (providerTrackId.isNotEmpty &&
              providerTrackId != tid &&
              await File(fp).exists()) {
            _archivosLocales[providerTrackId] = fp;
            final normPid = normalizarId(providerTrackId);
            if (normPid != providerTrackId) _archivosLocales[normPid] = fp;
          }

          // Indexar por nombre-fingerprint: un track descargado se encuentra
          // aunque se reproduzca desde el feed de OTRA extensión (misma
          // canción, id de otro proveedor).
          final name = (m['trackName'] ?? m['track_name'] ?? '').toString();
          final artist = (m['artistName'] ?? m['artist_name'] ?? '') as String;
          if (name.isNotEmpty && fp.isNotEmpty && await File(fp).exists()) {
            _archivosLocales[huellaDesdeNombre(name, artist)] = fp;
          }

          // Indexar por ISRC — el id de grabación canónico compartido por
          // TODOS los proveedores: un track descargado de apple-music
          // reproduce local aunque nombre/artista difieran levemente.
          final isrc = (m['isrc'] ?? '').toString();
          if (isrc.isNotEmpty && fp.isNotEmpty && await File(fp).exists()) {
            _archivosLocales[huellaIsrc(isrc)] = fp;
          }
        }
      }

      // Escanear el directorio de descargas solo en full load (no repetir la
      // operación de filesystem en cada refresh).
      if (!delta && _rutaDescargas != null) {
        final dir = Directory(_rutaDescargas!);
        if (await dir.exists()) {
          final entries = await dir.list().toList();
          for (final entry in entries) {
            if (entry is File) {
              final fname = entry.path.split(Platform.pathSeparator).last;
              final stem = fname.replaceAll(RegExp(r'\.[^.]+$'), '');
              if (!_archivosLocales.containsKey(stem)) {
                _archivosLocales[stem] = entry.path;
              }
            }
          }
        }
      }

      _archivosLocalesCargadosEn = DateTime.now();
      _ultimoTimestampCarga = DateTime.now().toUtc().toIso8601String();
    } catch (_) {}
  }
}