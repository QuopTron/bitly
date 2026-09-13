// tutorial_overlay.dart — Overlay del tutorial interactivo estilo "primera
// partida" (Clash Royale): oscurece la app, hace un agujero brillante sobre el
// widget que explica y muestra un tooltip con título, descripción, progreso y
// botones.
//
// CLAVE DE DISEÑO: no todos los pasos apuntan a algo que esté montado en la
// pantalla de Inicio (el reproductor completo, el modal de descarga o Premium
// viven en otras vistas). Si el objetivo no está en pantalla, el paso se
// muestra CENTRADO y sin agujero, para explicar la función igual en vez de
// quedarse invisible y trabar el tutorial.
//
// Se conecta con: tutorial_controller (estado + persistencia), tutorial_pasos
// (los objetivos) y l10n (textos ES/EN).
// Parte del flujo: Home, una sola vez después del setup.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../modelo_tutorial.dart';
import '../tutorial_controller.dart';

part 'tutorial_overlay_estado.dart';
part 'tutorial_overlay_capas.dart';
part 'tutorial_overlay_spotlight.dart';
part 'tutorial_overlay_ubicacion.dart';
part 'tutorial_overlay_tooltip.dart';
part 'tutorial_overlay_flecha.dart';
part 'tutorial_overlay_tarjeta.dart';
part 'tutorial_overlay_cabecera.dart';
part 'tutorial_overlay_botones.dart';
part 'tutorial_overlay_saltar.dart';

/// Overlay del tutorial interactivo. Se monta una vez en el shell de la Home
/// (móvil y escritorio); si el tutorial ya se completó, no dibuja nada.
class TutorialOverlay extends StatefulWidget {
  final TutorialController controller;

  const TutorialOverlay({super.key, required this.controller});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

/// Rect global donde está dibujado [key], o null si su widget no está montado
/// (pantalla no abierta, pestaña no construida, lista vacía…) o si el paso no
/// apunta a ningún widget ([key] null: la función vive en otra vista).
Rect? rectDeObjetivo(GlobalKey? key) {
  if (key == null) return null;
  final caja = key.currentContext?.findRenderObject();
  if (caja is! RenderBox || !caja.hasSize) return null;
  final origen = caja.localToGlobal(Offset.zero);
  final rect = origen & caja.size;
  // Un objetivo recortado por el borde o de tamaño cero no sirve para apuntar.
  if (rect.width < 8 || rect.height < 8) return null;
  return rect;
}
