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
// DETALLE IMPORTANTE: la carta se monta en el `builder` de MaterialApp
// (encima del Navigator), así que sus textos NO tienen un `Material`
// ancestro. Sin él, MaterialApp aplica su DefaultTextStyle de aviso, que
// lleva un subrayado DOBLE amarillo (0xFFFFFF00): eso era el par de
// líneas amarillas debajo de cada texto de la carta. Por eso el overlay
// va dentro de un `Material` transparente: le da el mismo estilo de texto
// que el resto de la app, sin pintar fondo ni sombra.
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
    // Material transparente: sin fondo, sin sombra, pero con el
    // DefaultTextStyle del tema (si no, los textos salen con el
    // subrayado doble amarillo del estilo de aviso de MaterialApp).
    return Material(
      type: MaterialType.transparency,
      child: _carta(context),
    );
  }

  /// El overlay en sí: fondo velado + carta animada.
  Widget _carta(BuildContext context) {
    final compartido = widget.link.compartido;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        // El fondo va FUERA de la animación: se construye una sola vez y el
        // desenfoque no se rearma en cada frame mientras la carta cae.
        Positioned.fill(child: FondoCompartido(onDismiss: widget.onDismiss)),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _entrada,
            builder:
                (context, _) => OverlayCompartidoContenido(
                  item:
                      compartido?.comoItem ??
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
                  mostrarFondo: false,
                ),
          ),
        ),
      ],
    );
  }
}
