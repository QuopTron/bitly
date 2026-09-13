// tutorial_host.dart — Monta la capa del tutorial en el Overlay RAÍZ de la
// app, no dentro de la Home.
//
// Por qué: el tutorial tiene que explicar cosas que están adentro de un modal
// (la hoja de ajustes) y el Spotlight necesita cubrir toda la pantalla. Un
// overlay metido en el árbol de la Home queda DEBAJO de cualquier modal, así
// que la hoja taparía al tutorial. Viviendo en el Overlay raíz queda arriba
// de todo.
//
// El host no dibuja nada: inserta/retira un OverlayEntry y le devuelve al
// controller un callback (`alFrente`) para que quien abra la hoja de ajustes
// pueda reinsertarla encima (la hoja se apila arriba de lo que ya existía).
//
// Además APARTA el foco del contenido de atrás mientras el tutorial está
// abierto: con teclado (PC) o con el control remoto (TV) el usuario no toca
// sin querer un botón que está tapado por la capa oscura.
//
// Se conecta con: tutorial_controller + tutorial_overlay + la hoja de ajustes.
// Parte del flujo: tutorial interactivo (capa global).
import 'package:flutter/material.dart';

import 'tutorial_controller.dart';
import './overlay/tutorial_overlay.dart';

/// Mantiene la capa del tutorial en el Overlay raíz mientras esté visible.
///
/// [child] es el árbol de la app: el host solo lo deja pasar (no dibuja nada
/// propio), así que se puede envolver la Home sin cambiar su layout.
class TutorialHost extends StatefulWidget {
  final TutorialController controller;
  final Widget? child;

  const TutorialHost({super.key, required this.controller, this.child});

  @override
  State<TutorialHost> createState() => _TutorialHostState();
}

class _TutorialHostState extends State<TutorialHost> {
  OverlayEntry? _entrada;

  /// Visibilidad ya aplicada al árbol: gobierna el ExcludeFocus de abajo.
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sincronizar);
    widget.controller.alFrente = _traerAlFrente;
    // Primer frame: recién ahí el Overlay raíz existe.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizar());
  }

  @override
  void didUpdateWidget(covariant TutorialHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sincronizar);
      widget.controller.addListener(_sincronizar);
      widget.controller.alFrente = _traerAlFrente;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sincronizar);
    widget.controller.alFrente = null;
    _quitar();
    super.dispose();
  }

  /// Inserta la capa cuando el tutorial está visible y la retira cuando no.
  void _sincronizar() {
    if (!mounted) return;
    final visible = widget.controller.visible;
    // El ExcludeFocus depende de este booleano: hay que repintar el árbol
    // cuando cambia (el checkbox del foco no se actualiza solo).
    if (visible != _visible) setState(() => _visible = visible);
    if (visible) {
      _insertar();
    } else {
      _quitar();
    }
  }

  void _insertar() {
    if (_entrada != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final entrada = OverlayEntry(
      builder:
          (_) => Positioned.fill(
            child: TutorialOverlay(controller: widget.controller),
          ),
    );
    overlay.insert(entrada);
    _entrada = entrada;
  }

  void _quitar() {
    _entrada?.remove();
    _entrada = null;
  }

  /// Reinserta la capa para que quede por ENCIMA de la hoja de ajustes que
  /// se acaba de abrir (los modales se apilan arriba de lo que ya existía).
  void _traerAlFrente() {
    if (!mounted || _entrada == null) return;
    _quitar();
    _insertar();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child ?? const SizedBox.shrink();
    // Mientras el tutorial está en pantalla, el contenido de atrás no puede
    // recibir foco: en TV el D-pad y en PC el Tab se quedan en la tarjeta.
    return ExcludeFocus(excluding: _visible, child: child);
  }
}
