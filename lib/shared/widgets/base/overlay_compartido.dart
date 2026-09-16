// ─────────────────────────────────────────────────────────────
// overlay_compartido.dart — Overlay "te compartieron" que aparece al
// abrir Bitly desde un enlace compartido.
//
// Qué hace: monta la carta CHICA del ítem compartido sobre la app (que
// queda desenfocada detrás) y le da una entrada corta: cae un poco,
// se asienta y aparece el resto. Una sola animación de 460 ms y ningún
// bucle infinito, así no cuesta GPU.
//
// Quién decide "reproducir" o "agregar a la cola" es el estado raíz
// (app_compartido.dart); acá solo se pinta y se avisa qué se tocó.
//
// Se conecta con: servicio_deep_link (DatosDeepLink) +
// overlay_compartido_contenido + ItemFeed.
// Parte del flujo: enlace compartido → carta → reproducir/encolar.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/modelos/feed/item_feed.dart';
import '../../../core/plataforma/sistema/servicio_deep_link.dart';
import 'overlay_compartido_contenido.dart';

/// Overlay "compartido contigo" para aperturas por deep link.
class OverlayCompartido extends StatefulWidget {
  final DatosDeepLink link;
  final VoidCallback onDismiss;

  /// Reproduce la canción (reemplaza la cola).
  final VoidCallback onPlay;

  /// La encola al final sin cortar lo que ya suena.
  final VoidCallback onAgregar;

  /// ¿Ya hay algo reproduciéndose? Cambia el botón por "agregar a la cola".
  final bool enCola;

  const OverlayCompartido({
    super.key,
    required this.link,
    required this.onDismiss,
    required this.onPlay,
    required this.onAgregar,
    this.enCola = false,
  });

  @override
  State<OverlayCompartido> createState() => _OverlayCompartidoState();
}

class _OverlayCompartidoState extends State<OverlayCompartido>
    with SingleTickerProviderStateMixin {
  /// Entrada de la carta: caída + asentado + aparición de las opciones.
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  )..forward();

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compartido = widget.link.compartido;
    return AnimatedBuilder(
      animation: _entrada,
      builder: (context, _) => OverlayCompartidoContenido(
        item: compartido?.comoItem ??
            ItemFeed(
              id: widget.link.id,
              type: widget.link.type,
              name: widget.link.query,
              source: '',
            ),
        emisor: compartido?.emisor ?? '',
        isrc: compartido?.isrc ?? widget.link.id,
        type: widget.link.type,
        progreso: _entrada.value,
        enCola: widget.enCola,
        onAccion: widget.enCola ? widget.onAgregar : widget.onPlay,
        onDismiss: widget.onDismiss,
      ),
    );
  }
}
