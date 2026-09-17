// ─────────────────────────────────────────────────────────────
// carpeta_descargas.dart — Elegir y aplicar la carpeta de descargas.
//
// Por qué existe: el mismo trabajo (pedir permiso de almacenamiento,
// abrir el explorador, guardar la ruta, sincronizarla con Go y
// re-vincular los archivos que ya estaban en la carpeta nueva) estaba
// solo dentro de Ajustes. Cuando la carpeta se pierde en medio de una
// descarga hay que resolverlo desde el aviso de descarga, sin pasar por
// Ajustes, y duplicar esa lógica garantizaba que una de las dos se
// quedara vieja.
//
// Se conecta con: cache_ajustes, cache_descargas, cache_biblioteca,
// backend_go (syncDownloadDir) y file_picker.
// Parte del flujo: descargas (destino en disco).
// ─────────────────────────────────────────────────────────────

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/inyeccion.dart';
import '../../../shared/utilidades/plataforma/deteccion_plataforma.dart';
import '../../backend_go/nucleo/contrato_backend.dart';
import '../../cache/almacenes/cache_ajustes.dart';
import '../../cache/almacenes/cache_biblioteca.dart';
import '../../cache/almacenes/cache_descargas.dart';

/// Pide permiso de almacenamiento/leer-audio en Android. No bloquea: si se
/// niega, la carpeta propia de la app sigue siendo escribible.
Future<void> solicitarPermisoAlmacenamiento() async {
  if (esEscritorio()) return;
  try {
    final storage = await Permission.storage.status;
    if (!storage.isGranted && !storage.isLimited) {
      await Permission.storage.request();
    }
    final audio = await Permission.audio.status;
    if (!audio.isGranted && !audio.isLimited) {
      await Permission.audio.request();
    }
  } catch (e) {
    debugPrint('[CarpetaDescargas] permiso: $e');
  }
}

/// Re-vincula el historial con los archivos de [carpeta]: si el usuario movió
/// sus descargas de sitio, las filas de la BD apuntan al archivo nuevo y la
/// biblioteca invalida sus cachés para releer las rutas.
Future<void> reubicarDescargasEnCarpeta(String carpeta) async {
  try {
    final movidos = await sl<CacheDescargas>().reubicarArchivosEnCarpeta(
      carpeta,
    );
    if (movidos > 0) await sl<CacheBiblioteca>().invalidarTodo();
  } catch (e) {
    debugPrint('[CarpetaDescargas] relink: $e');
  }
}

/// Abre el explorador, deja la carpeta elegida configurada (caché + Go) y
/// devuelve la ruta, o null si el usuario canceló. [tituloDialogo] es el texto
/// del explorador (l10n del llamador).
Future<String?> elegirCarpetaDescargas({required String tituloDialogo}) async {
  await solicitarPermisoAlmacenamiento();
  final result = await FilePicker.getDirectoryPath(dialogTitle: tituloDialogo);
  if (result == null || result.isEmpty) return null;

  await sl<CacheAjustes>().guardarRutaDescargas(result);
  try {
    await sl<BackendService>().syncDownloadDir(result);
  } catch (e) {
    debugPrint('[CarpetaDescargas] syncDownloadDir: $e');
  }
  await reubicarDescargasEnCarpeta(result);
  return result;
}
