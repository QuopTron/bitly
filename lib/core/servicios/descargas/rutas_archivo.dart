// ─────────────────────────────────────────────────────────────
// rutas_archivo.dart — Helpers de rutas de descargas (sin disco):
// qué extensión es audio, cuál es imagen, nombre/tallo/carpeta de una
// ruta y el índice de la carpeta nueva (por nombre y por tallo) que
// usa la re-vinculación cuando el usuario mueve la carpeta.
// Se conecta con: plan_relink.dart (usa este índice).
// Parte del flujo: descargas (Ajustes → carpeta de descargas).
// ─────────────────────────────────────────────────────────────

/// Extensiones que la app considera audio reproducible. Un archivo con otra
/// extensión puede ser la carátula o un sidecar de letras: nunca reemplaza
/// al audio de una fila del historial.
const Set<String> extensionesAudioDescarga = {
  '.flac', '.mp3', '.m4a', '.aac', '.opus', '.ogg', '.wav', '.mp4',
};

/// Extensiones de imagen que se aceptan como carátula reubicada.
const Set<String> extensionesImagenDescarga = {
  '.jpg', '.jpeg', '.png', '.webp',
};

/// Nombre final de una ruta ("/a/b/c.flac" → "c.flac"). Acepta `/` y `\`.
String nombreDeRuta(String ruta) {
  final i = ruta.lastIndexOf(RegExp(r'[/\\]'));
  return i >= 0 ? ruta.substring(i + 1) : ruta;
}

/// Carpeta de una ruta ("" si no tiene separador).
String carpetaDeRuta(String ruta) {
  final i = ruta.lastIndexOf(RegExp(r'[/\\]'));
  return i > 0 ? ruta.substring(0, i) : '';
}

/// Extensión en minúscula con punto ("" si no tiene).
String extensionDe(String nombre) {
  final i = nombre.lastIndexOf('.');
  return i > 0 ? nombre.substring(i) : '';
}

/// Nombre sin extensión ("c.flac" → "c").
String talloDe(String nombre) {
  final i = nombre.lastIndexOf('.');
  return i > 0 ? nombre.substring(0, i) : nombre;
}

/// Índice de los archivos que HOY viven en la carpeta elegida, armado en una
/// sola pasada: por nombre completo y por "tallo" (nombre sin extensión).
class ArchivosEnCarpeta {
  /// "cancion.flac" (minúscula) → ruta absoluta.
  final Map<String, String> porNombre;

  /// "cancion" (minúscula, solo audio) → ruta absoluta.
  final Map<String, String> porTallo;

  const ArchivosEnCarpeta(this.porNombre, this.porTallo);

  /// Construye el índice desde rutas absolutas. La primera coincidencia gana,
  /// para que el plan sea determinista sin importar el orden del listado.
  factory ArchivosEnCarpeta.desde(List<String> rutas) {
    final porNombre = <String, String>{};
    final porTallo = <String, String>{};
    for (final ruta in rutas) {
      final nombre = nombreDeRuta(ruta).toLowerCase();
      if (nombre.isEmpty) continue;
      porNombre.putIfAbsent(nombre, () => ruta);
      if (!extensionesAudioDescarga.contains(extensionDe(nombre))) continue;
      porTallo.putIfAbsent(talloDe(nombre), () => ruta);
    }
    return ArchivosEnCarpeta(porNombre, porTallo);
  }

  /// Busca el archivo nuevo que corresponde a una ruta vieja. Devuelve '' si
  /// no hay ninguna coincidencia razonable (mejor no tocar la fila que
  /// apuntarla a un archivo que no es).
  String buscar(String rutaVieja, String id) {
    final nombreViejo = nombreDeRuta(rutaVieja).toLowerCase();
    if (nombreViejo.isNotEmpty) {
      // Solo un archivo de AUDIO puede ocupar el lugar del audio: si la ruta
      // vieja era un sidecar (.lrc) o una carátula, su nombre no vale acá.
      if (extensionesAudioDescarga.contains(extensionDe(nombreViejo))) {
        final exacto = porNombre[nombreViejo];
        if (exacto != null) return exacto;
      }
      // porTallo solo indexa audio, así que un acierto acá ya es válido.
      final porTalloViejo = porTallo[talloDe(nombreViejo)];
      if (porTalloViejo != null) return porTalloViejo;
    }
    // El nombre del archivo suele derivar del id del track
    // ("{id}_audio.flac"): es la última coincidencia fiable.
    final idLimpio = id.trim().toLowerCase();
    if (idLimpio.length >= 6) {
      for (final e in porNombre.entries) {
        if (!extensionesAudioDescarga.contains(extensionDe(e.key))) continue;
        if (e.key.contains(idLimpio)) return e.value;
      }
    }
    return '';
  }

  /// Busca la carátula nueva de un track: mismo nombre que la vieja o, si la
  /// carátula vivía junto al audio, el cover típico de la carpeta.
  String buscarCaratula(String rutaCaratulaVieja, String rutaAudioVieja) {
    final nombreViejo = nombreDeRuta(rutaCaratulaVieja).toLowerCase();
    if (nombreViejo.isNotEmpty) {
      final exacto = porNombre[nombreViejo];
      if (exacto != null) return exacto;
      final tallo = talloDe(nombreViejo);
      for (final ext in extensionesImagenDescarga) {
        final hit = porNombre['$tallo$ext'];
        if (hit != null) return hit;
      }
    }
    // Si la carátula estaba DENTRO de la carpeta de descargas (y no en la
    // caché de carátulas de la app), se rescata el cover de la carpeta nueva.
    final carpetaVieja = carpetaDeRuta(rutaAudioVieja);
    if (carpetaVieja.isEmpty || carpetaDeRuta(rutaCaratulaVieja) != carpetaVieja) {
      return '';
    }
    final talloAudio = talloDe(nombreDeRuta(rutaAudioVieja).toLowerCase());
    final candidatos = <String>[
      if (talloAudio.isNotEmpty) talloAudio,
      'cover',
      'folder',
      'caratula',
    ];
    for (final base in candidatos) {
      for (final ext in extensionesImagenDescarga) {
        final hit = porNombre['$base$ext'];
        if (hit != null) return hit;
      }
    }
    return '';
  }
}
