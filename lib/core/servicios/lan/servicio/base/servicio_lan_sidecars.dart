// ─────────────────────────────────────────────────────────────
// servicio_lan_sidecars.dart — PART de servicio_lan.dart: la carátula y la
// letra que acompañan a una canción en el traspaso.
//
// Una canción sin carátula se ve gris y una sin letra no tiene karaoke, así
// que las dos viajan con el audio. Los nombres son los que la app ya usa, no
// inventamos ninguno:
//   · carátula → el nombre del audio con su extensión de imagen
//     (`<id>.jpg`), que es el primero que busca la app al reubicar archivos;
//   · letra    → `lyrics_<sha1 del id>.lrc`, como la escriben las descargas
//     (por eso el sha1 tiene que ser el mismo: es la identidad del archivo).
//
// Se conecta con: servicio_lan.dart (misma library) + lan_cancion.
// Parte del flujo: Ajustes → Conexión → traspaso de una canción.
// ─────────────────────────────────────────────────────────────

part of 'servicio_lan.dart';

/// Nombres y asentado de los archivos que acompañan al audio.
extension SidecarsLan on ServicioLan {
  /// Cómo se llama la letra de [id] en el disco (igual que las descargas).
  String nombreLetra(String id) =>
      'lyrics_${sha1.convert(utf8.encode(id)).toString()}.lrc';

  /// La extensión de imagen de una ruta ('jpg', 'png'...), o '' si no es una
  /// imagen que valga como carátula.
  String extImagenDe(String ruta) {
    final ext = _extensionDeRuta(ruta).toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ? ext : '';
  }

  /// ¿Esta canción ya tiene su letra descargada al lado del audio?
  Future<bool> hayLetraAlLado(String rutaAudio, String id) async {
    final punto = rutaAudio.lastIndexOf(RegExp(r'[/\\]'));
    if (punto <= 0) return false;
    final letra = io.File(
      '${rutaAudio.substring(0, punto)}${io.Platform.pathSeparator}'
      '${nombreLetra(id)}',
    );
    return letra.exists();
  }

  /// Deja la carátula al lado del audio con el nombre que la app espera, y
  /// devuelve su ruta (null si no vino carátula).
  Future<String?> escribirCover(
    CancionLan cancion,
    String carpeta,
    List<int>? bytes,
  ) async {
    if (bytes == null || cancion.extCover.isEmpty) return null;
    final destino = io.File(
      '$carpeta${io.Platform.pathSeparator}${cancion.id}.${cancion.extCover}',
    );
    await destino.writeAsBytes(bytes, flush: true);
    return destino.path;
  }

  /// Deja la letra al lado del audio, con su `.txt` gemelo como hace la
  /// descarga normal.
  Future<void> escribirLetra(
    String carpeta,
    String id,
    List<int>? bytes,
  ) async {
    if (bytes == null || bytes.isEmpty) return;
    final base = '$carpeta${io.Platform.pathSeparator}${nombreLetra(id)}';
    await io.File(base).writeAsBytes(bytes, flush: true);
    await io.File(
      base.replaceAll('.lrc', '.txt'),
    ).writeAsBytes(bytes, flush: true);
  }

  /// La extensión de una ruta, sin el punto ('' si no tiene o es rarísima).
  String _extensionDeRuta(String ruta) {
    final punto = ruta.lastIndexOf('.');
    if (punto < 0 || punto == ruta.length - 1) return '';
    final ext = ruta.substring(punto + 1);
    return ext.length > 5 ? '' : ext;
  }
}
