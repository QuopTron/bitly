// ─────────────────────────────────────────────────────────────
// escala_ui.dart — Escala global de LETRAS e ICONOS elegida por el usuario
// (Ajustes → Apariencia → Diseño), en un solo lugar consultable.
//
// Por qué existe: el tamaño de las letras y el de los iconos aparecen en
// decenas de archivos (tarjetas, navbar, miniplayer, cabeceras) y cada uno los
// calcula a partir de un tamaño base. Un notifier global permite que el control
// de Ajustes mueva TODO a la vez y en vivo, sin que cada vista tenga que
// escuchar a las preferencias de apariencia ni recalcular nada.
//
// Cómo se aplica cada uno:
//   · Letras  → [protegerLayout]/[acotarEscalaTexto] lo meten en el
//               `textScaler` del árbol entero, así que vale para TODOS los
//               textos de la app (incluido el sistema de widgets).
//   · Iconos  → lo consultan los widgets COMPARTIDOS que dibujan iconos
//               (tarjetas y barras), que son los que aparecen repetidos.
//
// Se conecta con: preferencias_apariencia (de dónde sale el valor),
// apariencia_helper (lo aplica al cambiar), app_helpers (al arrancar),
// escala_texto (lo usa para el texto) y las tarjetas/barras (iconos).
// Parte del flujo: presentación (accesibilidad elegida por el usuario).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../../../../core/modelos/usuario/preferencias/preferencias_apariencia.dart';

/// Estado global del tamaño de letras e iconos.
class EscalaUi {
  EscalaUi._();

  /// Multiplicador de las LETRAS (1 = tamaño de fábrica).
  static final ValueNotifier<double> texto = ValueNotifier<double>(1);

  /// Multiplicador de los ICONOS (1 = tamaño de fábrica).
  static final ValueNotifier<double> iconos = ValueNotifier<double>(1);

  /// Los dos juntos, para quien tenga que repintar con cualquiera de ellos.
  static final Listenable cambios = Listenable.merge([texto, iconos]);

  /// Afinado por COMPONENTE (bloque "Personalizado" de los tamaños): el general de
  /// arriba mueve todo junto y estos lo separan. Se MULTIPLICAN entre sí, no se
  /// reemplazan, así subir el general sigue agrandando todo lo que el usuario
  /// ya había afinado.
  static final ValueNotifier<double> titulos = ValueNotifier<double>(1);
  static final ValueNotifier<double> textos = ValueNotifier<double>(1);
  static final ValueNotifier<double> iconosCards = ValueNotifier<double>(1);
  static final ValueNotifier<double> iconosBarras = ValueNotifier<double>(1);

  /// Factor final de los TÍTULOS de las tarjetas.
  static double get factorTitulos => texto.value * titulos.value;

  /// Factor final de los TEXTOS secundarios (artista y datos de abajo).
  static double get factorTextos => texto.value * textos.value;

  /// Factor final de los ICONOS de las tarjetas.
  static double get factorIconosCards => iconos.value * iconosCards.value;

  /// Factor final de los ICONOS de las barras (navbar y miniplayer).
  static double get factorIconosBarras => iconos.value * iconosBarras.value;

  /// Aplica la escala guardada en las preferencias de apariencia.
  ///
  /// Se llama al arrancar y cada vez que el usuario mueve un control, así que
  /// el cambio se ve en vivo y sobrevive al reinicio.
  static void aplicarDesde(PreferenciasApariencia prefs) {
    texto.value = prefs.escalaTexto;
    iconos.value = prefs.escalaIconos;
    titulos.value = prefs.escalaTitulos;
    textos.value = prefs.escalaTextos;
    iconosCards.value = prefs.escalaIconosCards;
    iconosBarras.value = prefs.escalaIconosBarras;
  }

  /// Vuelve al tamaño de fábrica (tests y "restablecer diseño").
  @visibleForTesting
  static void reiniciar() {
    texto.value = 1;
    iconos.value = 1;
    titulos.value = 1;
    textos.value = 1;
    iconosCards.value = 1;
    iconosBarras.value = 1;
  }
}
