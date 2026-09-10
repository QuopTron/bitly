// ─────────────────────────────────────────────────────────────
// descargas_reparar.dart — PART de cubit_descargas.dart: busca
// archivos alternativos reproducibles en disco (carreras de
// proveedores) y valida por magic bytes que un archivo sea audio
// reproducible (los streams amazon encriptados con .flac NO lo
// son). El decrypt DRM vive en descargas_reparar_decrypt.dart y el
// escaneo de arranque en descargas_reparar_escaneo.dart.
// Parte del flujo: descargas (reparación y post-descarga).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

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
  Future<String?> _buscarArchivoAlternativo(String stateKey,
      [String rutaEncriptada = '']) async {
    final parts = stateKey.split('_');
    if (parts.length < 3) return null;
    final normId = parts.sublist(1, parts.length - 1).join('_');
    String dirPath;
    if (rutaEncriptada.isNotEmpty) {
      dirPath = rutaEncriptada
          .substring(0, rutaEncriptada.lastIndexOf(Platform.pathSeparator));
    } else {
      try {
        final dirDescargas = await di.sl<CacheAjustes>().getRutaDescargas();
        if (dirDescargas == null || dirDescargas.isEmpty) return null;
        dirPath = dirDescargas;
      } catch (_) {
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
        if (!nombre.toLowerCase().startsWith('${normId.toLowerCase()}_audio.')) {
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
                  final esID3 = head[0] == 0x49 && head[1] == 0x44 && head[2] == 0x33;
                  final esMPEG = head[0] == 0xFF && (head[1] & 0xE0) == 0xE0;
                  final esTS = head[0] == 0x47;
                  if (!esID3 && !esMPEG && !esTS) continue;
                } finally {
                  raf.closeSync();
                }
              } catch (_) {
                continue;
              }
            }
            return f.path;
          }
        }
        if ((ext == '.flac' || ext == '.dec.flac') &&
            f.existsSync() && f.lengthSync() > 1024) {
          try {
            final raf = f.openSync(mode: FileMode.read);
            try {
              final head = raf.readSync(4);
              if (head.length >= 4 &&
                  head[0] == 0x66 && head[1] == 0x4C &&
                  head[2] == 0x61 && head[3] == 0x43) {
                return f.path;
              }
            } finally {
              raf.closeSync();
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      _log.w('[buscarAlt] error escaneando $dirPath para $stateKey: $e');
    }
    _log.w('[buscarAlt] sin archivo reproducible para $stateKey en $dirPath (normId=$normId)');
    return null;
  }

  /// Chequeo rápido de magic bytes: ¿es audio reproducible? Los archivos rotos
  /// conocidos son streams amazon DRM encriptados guardados como `.flac` (son
  /// contenedores MP4, no FLAC — un FLAC real siempre empieza con `fLaC`).
  Future<bool> _esAudioDecodificable(File file) async {
    try {
      final nombre = file.path.split(RegExp(r'[/\\\\]')).last.toLowerCase();
      final punto = nombre.lastIndexOf('.');
      final ext = punto >= 0 ? nombre.substring(punto + 1) : '';
      final raf = await file.open(mode: FileMode.read);
      final magic = await raf.read(8);
      await raf.close();
      if (magic.length < 4) return false;
      switch (ext) {
        case 'flac':
          return magic[0] == 0x66 && magic[1] == 0x4C &&
              magic[2] == 0x61 && magic[3] == 0x43; // "fLaC"
        case 'mp3':
          if (magic[0] == 0x49 && magic[1] == 0x44 && magic[2] == 0x33) return true; // ID3
          if (magic[0] == 0xFF && (magic[1] & 0xE0) == 0xE0) return true; // frame MPEG
          if (magic[0] == 0x47) return true; // MPEG-TS (HLS de SoundCloud)
          return false;
        case 'wav':
          return magic[0] == 0x52 && magic[1] == 0x49 &&
              magic[2] == 0x46 && magic[3] == 0x46; // "RIFF"
        case 'ogg':
          return magic[0] == 0x4F && magic[1] == 0x67 &&
              magic[2] == 0x67 && magic[3] == 0x53; // "OggS"
        case 'opus':
          if (magic[0] == 0x4F && magic[1] == 0x67 &&
              magic[2] == 0x67 && magic[3] == 0x53) {
            return true; // OggS
          }
          if (magic[0] == 0x1A && magic[1] == 0x45 &&
              magic[2] == 0xDF && magic[3] == 0xA3) {
            return true; // WebM
          }
          return true; // Opus crudo: aceptar si el archivo existe
        default:
          // mp4/m4a/aac y extensiones desconocidas son contenedores MP4
          // estructuralmente válidos incluso encriptados — no se sniffean.
          return true;
      }
    } catch (_) {
      return false;
    }
  }
}