// ─────────────────────────────────────────────────────────────
// descargas_reparar.dart — PART de cubit_descargas.dart: busca
// archivos alternativos reproducibles en disco (carreras de
// proveedores) y valida por magic bytes que un archivo sea audio
// reproducible (los streams amazon encriptados con .flac NO lo
// son). El decrypt DRM vive en descargas_reparar_decrypt.dart y el
// escaneo de arranque en descargas_reparar_escaneo.dart.
// Parte del flujo: descargas (reparación y post-descarga).
// ─────────────────────────────────────────────────────────────

part of '../cubit_descargas.dart';

/// Reparación y validación de archivos. Mixin aplicado en CubitDescargas.
mixin DescargasReparar on DescargasBase {
  /// Despacho de un track individual — impl. concreta en DescargasDespacho
  /// (arriba en la cadena); declaración para re-descargar tracks rotos.
  Future<void> despacharTrackIndividual({
    required Map<String, dynamic> metaComun,
    required AjustesDescarga ajustes,
    required String baseId,
    String? calidadForzada,
  });

  /// Busca un archivo reproducible (m4a, mp3...) en disco para el mismo track
  /// cuando el decrypt del FLAC encriptado falló. Escanea el directorio padre.
  Future<String?> _buscarArchivoAlternativo(
    String stateKey, [
    String rutaEncriptada = '',
  ]) async {
    final parts = stateKey.split('_');
    if (parts.length < 3) return null;
    final normId = parts.sublist(1, parts.length - 1).join('_');
    String dirPath;
    if (rutaEncriptada.isNotEmpty) {
      dirPath = rutaEncriptada.substring(
        0,
        rutaEncriptada.lastIndexOf(Platform.pathSeparator),
      );
    } else {
      try {
        final dirDescargas = await di.sl<CacheAjustes>().getRutaDescargas();
        if (dirDescargas == null || dirDescargas.isEmpty) return null;
        dirPath = dirDescargas;
      } catch (e) {
        debugPrint('[DescargasReparar] $e');
        return null;
      }
    }
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        _log.w('[buscarAlt] el directorio no existe: $dirPath para $stateKey');
        return null;
      }
      for (final f in dir.listSync(followLinks: false)) {
        if (f is! File) continue;
        final nombre = f.path.split(Platform.pathSeparator).last;
        if (!nombre.toLowerCase().startsWith(
          '${normId.toLowerCase()}_audio.',
        )) {
          continue;
        }
        if (nombre.contains('.tmp.') || nombre.contains('.enc.')) continue;
        final ext = nombre.substring(nombre.lastIndexOf('.'));
        if ({'.m4a', '.mp3', '.mp4', '.ogg', '.wav', '.opus'}.contains(ext)) {
          if (f.existsSync() && f.lengthSync() > 1024) {
            if (ext == '.mp3') {
              try {
                final raf = f.openSync(mode: FileMode.read);
                try {
                  final head = raf.readSync(4);
                  if (head.length < 4) continue;
                  final esID3 =
                      head[0] == 0x49 && head[1] == 0x44 && head[2] == 0x33;
                  final esMPEG = head[0] == 0xFF && (head[1] & 0xE0) == 0xE0;
                  final esTS = head[0] == 0x47;
                  if (!esID3 && !esMPEG && !esTS) continue;
                } finally {
                  raf.closeSync();
                }
              } catch (e) {
                debugPrint('[DescargasReparar] $e');
                continue;
              }
            }
            return f.path;
          }
        }
        if ((ext == '.flac' || ext == '.dec.flac') &&
            f.existsSync() &&
            f.lengthSync() > 1024) {
          try {
            final raf = f.openSync(mode: FileMode.read);
            try {
              final head = raf.readSync(4);
              if (head.length >= 4 &&
                  head[0] == 0x66 &&
                  head[1] == 0x4C &&
                  head[2] == 0x61 &&
                  head[3] == 0x43) {
                return f.path;
              }
            } finally {
              raf.closeSync();
            }
          } catch (e) {
            debugPrint("[Descargas] $e");
          }
        }
      }
    } catch (e) {
      _log.w('[buscarAlt] error escaneando $dirPath para $stateKey: $e');
    }
    _log.w(
      '[buscarAlt] sin archivo reproducible para $stateKey en $dirPath (normId=$normId)',
    );
    return null;
  }

  /// Chequeo rápido de magic bytes: ¿es audio reproducible?
  ///
  /// Delega en [esAudioUsableEnDisco], que NUNCA dice "no" por no poder leer
  /// el archivo. El bug que esto arregla: antes una excepción de E/S (permiso
  /// sin conceder, carpeta externa no montada) devolvía `false`, eso se leía
  /// como "corrupto" y terminaba borrando descargas buenas del usuario. Los
  /// archivos realmente rotos son streams encriptados guardados como `.flac`
  /// (son contenedores MP4, no FLAC) — eso SÍ se detecta, con evidencia.
  Future<bool> _esAudioDecodificable(File file) =>
      esAudioUsableEnDisco(file.path);
}
