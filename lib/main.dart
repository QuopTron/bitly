// ─────────────────────────────────────────────────────────────
// main.dart — Punto de entrada de la app: limpia archivos stale de
// media_kit, inicializa media_kit, configura la inyección de
// dependencias (GetIt + drift + backend Go), carga el perfil de
// rendimiento, configura el caché de imágenes según el perfil de
// runtime y arranca los servicios de plataforma (share intent, deep
// link, notificación multimedia, foco de audio).
// Se conecta con: app.dart (raíz) + inyeccion (sl) + servicios de
// plataforma + perfil_runtime.
// Parte del flujo: arranque (primer código que corre la app).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app/inyeccion.dart';
import 'core/plataforma/perfil_runtime.dart';
import 'core/plataforma/puente_notificacion_media.dart';
import 'core/plataforma/servicio_deep_link.dart';
import 'core/plataforma/servicio_foco_audio.dart';
import 'core/plataforma/servicio_share_intent.dart';
import 'estado/cubit_reproductor.dart';

/// Punto de entrada de la app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Limpia archivos temporales stale de media_kit (NativeReferenceHolder)
  // de sesiones previas. Estos archivos guardan una dirección de memoria
  // nativa para el cleanup del hot-restart; si la app se mató, el archivo
  // persiste con una dirección obsoleta y causa FormatException al iniciar.
  // En Android, NativeReferenceHolder usa Context.getFilesDir() =
  // <pkg>/files; getApplicationSupportDirectory() devuelve <pkg>/app_flutter,
  // así que derivamos el dir nativo del padre.
  try {
    final soporte = await getApplicationSupportDirectory();
    const prefijo = 'com.alexmercerind.media_kit.NativeReferenceHolder.';
    final dirsALimpiar = <Directory>[soporte];
    if (Platform.isAndroid) {
      final padre = soporte.parent;
      final dirNativo = Directory('${padre.path}/files');
      if (dirNativo.existsSync()) dirsALimpiar.add(dirNativo);
    }
    for (final dir in dirsALimpiar) {
      final stale = dir.listSync().whereType<File>().where((f) {
        final nombre = f.uri.pathSegments.last;
        return nombre.startsWith(prefijo);
      });
      for (final f in stale) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  } catch (_) {}

  // media_kit DEBE inicializarse antes de crear cualquier Player.
  MediaKit.ensureInitialized();
  await configurarDependencias();

  // Carga el perfil de rendimiento guardado al notificador global. El push
  // al backend Go ocurre dentro del healthCheck del splash (después del
  // init nativo) para no colgar el arranque.
  await cargarPerfilRendimiento();

  // Perfil de runtime: configura el caché de imágenes según el nivel.
  final prefs = await SharedPreferences.getInstance();
  final perfil = await cargarPerfilRuntime(prefs);
  configurarCacheImagenes(perfil);

  // Listener de share intents (Android/iOS).
  await ServicioShareIntent.instance.initialize();

  // Deep links (abrir la app desde un link externo).
  await ServicioDeepLink.instance.initialize();

  // Conecta el foco de audio al cubit del reproductor antes de iniciar.
  ServicioFocoAudio.instance.controlador = sl<CubitReproductor>();

  // Notificación multimedia + controles de lock screen + servicio en
  // primer plano (Android). Va después de GetIt para enlazar los cubits.
  await PuenteNotificacionMedia.instancia.init();

  // Pausa automática cuando otra app toma el audio. Después de GetIt.
  await ServicioFocoAudio.instance.init();

  runApp(const BitlyApp());
}