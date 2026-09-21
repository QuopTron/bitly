// ─────────────────────────────────────────────────────────────
// portada_playlist.dart — Elige la foto de portada de una playlist
// desde el dispositivo y la COPIA a una carpeta estable de la app.
//
// Por qué copiarla: la ruta que devuelve el selector en Android es una
// copia en la CACHÉ del plugin (se puede borrar) y, con el modo SAF de
// `file_picker`, hasta puede venir SIN ruta (solo el identificador del
// documento). Antes eso terminaba en `null` y la foto se perdía en
// silencio; ahora, si no hay ruta, se guardan los BYTES.
//
// En web no hay archivos locales: devuelve null y la playlist usa la
// carátula de su primera canción.
// Se conecta con: file_picker + path_provider + dart:io.
// Parte del flujo: Mi Espacio → playlists (portada).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Carpeta donde viven las portadas elegidas por el usuario.
const String carpetaPortadas = 'portadas_playlist';

/// Abre el explorador de imágenes y devuelve la ruta local de la foto copiada
/// a la app, o null si el usuario canceló (o si estamos en web).
Future<String?> elegirPortadaPlaylist({String? titulo}) async {
  if (kIsWeb) return null;
  try {
    final elegido = await FilePicker.pickFile(
      type: FileType.image,
      dialogTitle: titulo,
    );
    final ruta = elegido?.path;
    if (ruta == null || ruta.isEmpty) {
      debugPrint('[Playlist] la foto elegida no trajo una ruta usable');
      return null;
    }
    final copiada = await copiarPortadaDeArchivo(ruta, nombre: elegido?.name);
    if (copiada == null) {
      debugPrint('[Playlist] no se pudo copiar la foto elegida: $ruta');
    }
    return copiada;
  } catch (e) {
    debugPrint('[Playlist] no se pudo elegir la portada: $e');
    return null;
  }
}

/// Copia [origen] a la carpeta de portadas y devuelve la ruta nueva.
///
/// Se copia porque la ruta del selector en Android vive en la CACHÉ del
/// plugin: si se guardara tal cual, la portada se quedaría muerta al
/// limpiarse esa carpeta.
Future<String?> copiarPortadaDeArchivo(String origen, {String? nombre}) async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final destino = await rutaNuevaPortada(docs.path, nombre ?? origen);
    return (await File(origen).copy(destino)).path;
  } catch (e) {
    debugPrint('[Playlist] no se pudo copiar la portada: $e');
    return null;
  }
}

/// Ruta nueva y única dentro de la carpeta de portadas de [base], conservando
/// la extensión de [referencia] (el nombre original o la ruta de origen).
/// Separado para poder probar la regla de nombres y extensiones sin disco.
Future<String> rutaNuevaPortada(String base, String referencia) async {
  final dir = Directory(p.join(base, carpetaPortadas));
  if (!await dir.exists()) await dir.create(recursive: true);
  final ext =
      p.extension(referencia).isEmpty
          ? '.jpg'
          : p.extension(referencia).toLowerCase();
  return p.join(
    dir.path,
    'playlist_${DateTime.now().millisecondsSinceEpoch}$ext',
  );
}
