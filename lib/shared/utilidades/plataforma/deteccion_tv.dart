// deteccion_tv.dart — ¿esta sesión corre en un televisor (Android TV, Google
// TV, Fire TV)? Lo responde el SISTEMA, no el ancho en píxeles.
//
// Por qué no alcanza el ancho: una TV de 720p reporta pocos dp de ancho, así
// que un proxy por tamaño la confundiría con un celular y mostraría el layout
// móvil. Acá se pregunta UNA sola vez al arrancar (antes de runApp) y se
// cachea, para que la decisión de layout sea estable desde el primer frame y
// no provoque un salto de diseño.
//
// Se conecta con: nativo (MethodChannel com.bitly/plataforma, ver
// MainActivity.kt) + deteccion_plataforma (usarLayoutEscritorio) + main.dart
// (la dispara).
// Parte del flujo: arranque → elección de layout global.
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel;

/// Canal con el lado nativo (MainActivity.kt).
const MethodChannel _canalPlataforma = MethodChannel('com.bitly/plataforma');

/// Respuesta cacheada del sistema: true si corremos en un televisor.
bool _esTv = false;

/// True si el sistema ya reportó que estamos en TV. Antes de [detectarTelevisor]
/// es false (y el respaldo por ancho decide).
bool get esTelevisor => _esTv;

/// Pregunta al nativo una sola vez si corremos en TV.
///
/// Se llama ANTES de `runApp`: así el primer frame ya usa el layout correcto
/// (el de escritorio, que es el que queremos en TV) sin un salto visible.
Future<void> detectarTelevisor() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final respuesta = await _canalPlataforma.invokeMethod<bool>('esTv');
    _esTv = respuesta ?? false;
  } catch (_) {
    // Canal sin respuesta (nativo viejo, test, otra plataforma): se queda en
    // false y el respaldo por ancho sigue decidiendo.
  }
}
