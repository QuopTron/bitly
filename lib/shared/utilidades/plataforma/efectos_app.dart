// ─────────────────────────────────────────────────────────────
// efectos_app.dart — Interruptor GLOBAL de efectos visuales costosos
// (desenfoques de GPU), alimentado por el perfil de rendimiento detectado.
//
// Por qué existe: el `BackdropFilter`/`ImageFiltered` de las superficies de
// vidrio y del fondo ambiente se compone en la GPU en CADA frame. En un
// celular de gama baja (Helio G / PowerVR GE8320, Mali-G52) eso es lo que
// congela la app: no el código Dart, sino el blur a pantalla completa.
//
// Vive fuera de GetIt a propósito: lo consultan widgets de `shared/` y así no
// hay riesgo de romper tests ni de dependencia circular con la inyección.
// El valor por defecto es PERMISIVO (todo habilitado), así que nada cambia
// hasta que el perfil de rendimiento lo limite al arrancar.
//
// Se conecta con: contenedor_vidrio, desenfoque_adaptativo, fondo_ambiente y
// cargarPerfilRendimiento (inyeccion.dart) — que lo alimenta.
// Parte del flujo: presentación (coste visual adaptado al equipo).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// Estado global del coste visual permitido en este equipo.
class EfectosApp {
  EfectosApp._();

  /// Si false, ningún widget pinta desenfoques (se usa el color de fondo).
  static final ValueNotifier<bool> permitirDesenfoque =
      ValueNotifier<bool>(true);

  /// Sigma máximo tolerado. 0 = sin desenfoque.
  static final ValueNotifier<double> sigmaMaximo = ValueNotifier<double>(26);

  /// ¿Se puede desenfocar en este equipo?
  static bool get desenfoqueActivo =>
      permitirDesenfoque.value && sigmaMaximo.value > 0;

  /// Aplica el coste visual del perfil activo (lo llama el arranque).
  static void aplicar({required bool efectosPesados, required double sigmaMax}) {
    permitirDesenfoque.value = efectosPesados;
    sigmaMaximo.value = sigmaMax;
  }

  /// Vuelve al estado permisivo (usado por tests).
  @visibleForTesting
  static void reiniciar() {
    permitirDesenfoque.value = true;
    sigmaMaximo.value = 26;
  }
}
