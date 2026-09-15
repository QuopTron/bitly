// ─────────────────────────────────────────────────────────────
// overlay_compartido_contenido.dart — Contenido visual del overlay
// "te compartieron": portada con glow, nombre, artista, etiqueta
// de tipo y botones de reproducir / omitir. El arte (portada, badge
// y etiquetas de tipo) vive en overlay_compartido_tarjeta.dart y los
// botones en overlay_compartido_acciones.dart.
//
// Se conecta con: overlay_compartido.dart (lo monta dentro del
// AnimatedBuilder).
// Parte del flujo: arranque / llegada de deep links.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/modelos/feed/item_feed.dart';
import '../../tema/colores_app.dart';
import '../../utilidades/plataforma/responsive.dart';
import '../tarjetas/portada/imagen_portada.dart';

part 'overlay_compartido_tarjeta.dart';
part 'overlay_compartido_acciones.dart';

/// Contenido del overlay: portada + info + botones.
class OverlayCompartidoContenido extends StatelessWidget {
  final ItemFeed? item;
  final bool cargando;
  final VoidCallback onPlay;
  final VoidCallback onDismiss;
  final String type;

  const OverlayCompartidoContenido({
    super.key,
    required this.item,
    required this.cargando,
    required this.onPlay,
    required this.onDismiss,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final brillo = ColoresApp.primario;

    return Column(
      children: [
        const Spacer(flex: 2),
        Text(
          'Te compartieron',
          style: TextStyle(
            fontSize: r.subtitleSize - 2,
            color: Colors.white.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: r.spacingL),
        _cubiertaOverlay(this, r, brillo),
        SizedBox(height: r.spacingL),
        Text(
          item?.name ?? 'Buscando...',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.titleSize + 2,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        if (item?.artists != null && item!.artists!.isNotEmpty) ...[
          SizedBox(height: r.spacingXS),
          Text(
            item!.artists!,
            style: TextStyle(
              fontSize: r.subtitleSize,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
        SizedBox(height: r.spacingS),
        _badgeTipoOverlay(this, r, brillo),
        const Spacer(flex: 2),
        _botonPlayOverlay(this, brillo),
        SizedBox(height: r.spacingL),
        _botonOmitirOverlay(this, r),
        SizedBox(height: r.spacingXL),
      ],
    );
  }
}
