// ─────────────────────────────────────────────────────────────
// depuracion.dart — Apaga los logs de depuración en las versiones de
// release.
//
// Por qué existe: `debugPrint` NO desaparece al compilar en release (sigue
// escribiendo en la consola del sistema / logcat), así que las líneas de
// diagnóstico del proyecto se veían también en la app publicada. Con esto, en
// release no se imprime NADA y durante el desarrollo (flutter run) se siguen
// viendo todos los mensajes igual que siempre.
//
// Se conecta con: main.dart (lo llama una vez, antes de arrancar la app) y
// monitor_frames (que usa [avisoRendimiento], la excepción que sí sale en
// release).
// Parte del flujo: arranque (silencio de logs) + diagnóstico de rendimiento.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// En release, `debugPrint` pasa a no hacer nada.
///
/// Es global a propósito: el proyecto usa `debugPrint` como log en toda la app,
/// así que apagarlo acá cubre todos los archivos sin tocarlos uno por uno.
void silenciarDepuracion() {
  if (kDebugMode) return;
  debugPrint = (String? message, {int? wrapWidth}) {};
}

/// Avisos de RENDIMIENTO: la única línea que sí sale en release.
///
/// Por qué existe: cuando el equipo no llega al ritmo, la app apaga efectos y
/// cambia lo que se ve (sombras, color por tarjeta, foto de fondo). Si eso
/// pasara en silencio, un reporte de "va lento" o de "¿por qué se ve
/// distinto?" sería imposible de diagnosticar en el aparato: el silencio de
/// [silenciarDepuracion] también tapa los avisos del monitor de frames.
///
/// No es un log de depuración: lo emite [MonitorFrames] con límite de
/// frecuencia, así que un equipo que va bien no imprime NADA, y uno que va mal
/// deja como mucho una línea cada diez segundos con los números medidos.
void avisoRendimiento(String mensaje) {
  // `print` y no `debugPrint`: `debugPrint` está anulado en release.
  // ignore: avoid_print
  print('[rendimiento] $mensaje');
}
