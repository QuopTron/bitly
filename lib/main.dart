import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'backend/services/media_notification.dart';
import 'backend/services/share_intent_service.dart';
import 'backend/services/runtime_profile.dart';
import 'injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean stale media_kit NativeReferenceHolder temp files from previous
  // debug sessions. These files store a native memory address for hot-restart
  // cleanup; if the app was killed the file persists with a stale address,
  // causing FormatException("Invalid number") on the next launch.
  //
  // On Android, NativeReferenceHolder uses AndroidHelper.filesDir which maps
  // to Context.getFilesDir() = <pkg>/files. getApplicationSupportDirectory()
  // returns <pkg>/app_flutter, so we derive the native files dir from it.
  try {
    final supportDir = await getApplicationSupportDirectory();
    final prefix = 'com.alexmercerind.media_kit.NativeReferenceHolder.';
    // On Android, try both the Flutter support dir and the native files dir.
    final dirsToClean = <Directory>[supportDir];
    if (Platform.isAndroid) {
      // <pkg>/app_flutter → <pkg>/files
      final parent = supportDir.parent;
      final nativeFilesDir = Directory('${parent.path}/files');
      if (nativeFilesDir.existsSync()) dirsToClean.add(nativeFilesDir);
    }
    for (final dir in dirsToClean) {
      final stale = dir.listSync().whereType<File>().where((f) {
        final name = f.uri.pathSegments.last;
        return name.startsWith(prefix);
      });
      for (final f in stale) {
        try { await f.delete(); } catch (_) {}
      }
    }
  } catch (_) {}

  // Inicializar media_kit ANTES de crear cualquier Player (PlayerCubit).
  MediaKit.ensureInitialized();
  await configureDependencies();
  await loadPerformanceProfile();

  // Load and configure device performance profile (image cache, etc.).
  final prefs = await SharedPreferences.getInstance();
  final profile = await loadRuntimeProfile(prefs);
  configureImageCache(profile);

  // Initialize share intent listener (Android/iOS).
  ShareIntentService.instance.initialize();

  // Registrar el manejador de audio del sistema (notificación multimedia,
  // controles de lock screen y servicio en primer plano en Android). Se hace
  // DESPUÉS de GetIt para poder enlazar los cubits de reproducción.
  await MediaNotificationBridge.instance.init();
  runApp(const BitlyApp());
}
