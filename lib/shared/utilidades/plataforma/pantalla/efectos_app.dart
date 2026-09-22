// ─────────────────────────────────────────────────────────────
// efectos_app.dart — Interruptores GLOBALES de efectos visuales costosos
// (desenfoques de GPU, sombras con blur, pulsos, partículas y las fotos a
// pantalla completa), alimentados por el perfil de rendimiento detectado, por
// el monitor de frames y por la elección del usuario ("modo fluido").
//
// Por qué existe: el `BackdropFilter`/`ImageFiltered` de las superficies de
// vidrio y del fondo ambiente se compone en la GPU en CADA frame. En un
// celular de gama baja (Helio G / PowerVR GE8320, Mali-G52) eso es lo que
// congela la app: no el código Dart, sino el trabajo de GPU por frame.
//
// Vive fuera de GetIt a propósito: lo consultan widgets de `shared/` y así no
// hay riesgo de romper tests ni de dependencia circular con la inyección.
// El valor por defecto es PERMISIVO (todo habilitado), así que nada cambia
// hasta que el perfil de rendimiento lo limite al arrancar.
//
// Se conecta con: contenedor_vidrio, desenfoque_adaptativo, fondo_ambiente,
// fondo_reactivo_portada, tarjetas, esqueletos, miniplayer y cargarPerfilRendimiento
// (inyeccion.dart) — que lo alimenta.
// Parte del flujo: presentación (coste visual adaptado al equipo).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// Estado global del coste visual permitido en este equipo.
class EfectosApp {
  EfectosApp._();

  /// Si false, ningún widget pinta desenfoques (se usa el color de fondo).
  static final ValueNotifier<bool> permitirDesenfoque = ValueNotifier<bool>(
    true,
  );

  /// Sigma máximo tolerado. 0 = sin desenfoque.
  static final ValueNotifier<double> sigmaMaximo = ValueNotifier<double>(26);

  /// Segundo escalón de degradación: cuando el equipo no llega al ritmo ni
  /// siquiera sin desenfoques, se apaga además el trabajo de color POR
  /// TARJETA (extraer la paleta dominante de cada cover). Es lo único que
  /// escala con la cantidad de items en pantalla, así que es lo siguiente que
  /// hay que soltar para que una lista larga siga yendo fluida.
  /// Lo enciende [MonitorFrames] midiendo frames reales.
  static final ValueNotifier<bool> efectosMinimos = ValueNotifier<bool>(false);

  /// Modo fluido: elección EXPLÍCITA del usuario (Ajustes → Rendimiento) para
  /// los equipos donde la app se siente pesada.
  ///
  /// Qué apaga, sin tocar el diseño de la app:
  ///   · desenfoques, sombras con blur, pulsos de glow, partículas y shimmer;
  ///   · las FOTOS a pantalla completa de los fondos (fondo ambiente de la
  ///     Home, fondo del reproductor, cabecera de detalle y fondos de modales).
  ///     En su lugar se pinta el COLOR DOMINANTE del cover, que es el mismo
  ///     estado al que llega el control de intensidad de estilo al 100%: el
  ///     diseño se mantiene, el color sigue siendo el de la canción.
  ///
  /// A diferencia de [efectosMinimos] (que lo decide el monitor midiendo), este
  /// lo elige la persona y por eso nunca se revierte solo.
  static final ValueNotifier<bool> modoFluido = ValueNotifier<bool>(false);

  /// Cambios combinados de TODOS los interruptores de efectos.
  ///
  /// Los widgets que encienden y apagan animaciones necesitan reaccionar a
  /// cualquiera de ellos (el perfil, el monitor o el modo fluido), no solo a
  /// uno: sin esto, activar el modo fluido dejaba animaciones corriendo porque
  /// el widget solo escuchaba `permitirDesenfoque`.
  static final Listenable cambiosEfectos = Listenable.merge([
    permitirDesenfoque,
    sigmaMaximo,
    efectosMinimos,
    modoFluido,
  ]);

  /// ¿Se puede desenfocar/pintar sombras y pulsos en este equipo?
  static bool get desenfoqueActivo =>
      !modoFluido.value && permitirDesenfoque.value && sigmaMaximo.value > 0;

  /// ¿Se puede hacer trabajo de color por tarjeta?
  ///
  /// El modo fluido NO entra acá a propósito: el tinte por tarjeta es parte del
  /// diseño que la persona eligió y su coste está amortizado (se extrae una vez
  /// por cover, no en cada frame). Lo que apaga el modo fluido es el trabajo de
  /// GPU por frame, no el color.
  static bool get colorPorTarjetaActivo => !efectosMinimos.value;

  /// ¿Se pintan las FOTOS a pantalla completa (fondos ambiente, cabeceras y
  /// modales)? Es la capa más cara que queda en una GPU de gama baja: una
  /// textura escalada del tamaño de la pantalla, en cada frame.
  static bool get fotoPantallaCompletaActiva => !modoFluido.value;

  /// Aplica el coste visual del perfil activo (lo llama el arranque).
  static void aplicar({
    required bool efectosPesados,
    required double sigmaMax,
  }) {
    permitirDesenfoque.value = efectosPesados;
    sigmaMaximo.value = sigmaMax;
  }

  /// Activa/desactiva el modo fluido elegido por el usuario.
  static void aplicarModoFluido(bool activo) {
    if (modoFluido.value == activo) return;
    modoFluido.value = activo;
  }

  /// Vuelve al estado permisivo (usado por tests).
  @visibleForTesting
  static void reiniciar() {
    permitirDesenfoque.value = true;
    sigmaMaximo.value = 26;
    efectosMinimos.value = false;
    modoFluido.value = false;
  }
}
