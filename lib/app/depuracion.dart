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
// Se conecta con: main.dart (lo llama una vez, antes de arrancar la app).
// Parte del flujo: arranque (silencio de logs).
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
