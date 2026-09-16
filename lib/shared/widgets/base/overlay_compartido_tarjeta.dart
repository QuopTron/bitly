// ─────────────────────────────────────────────────────────────
// overlay_compartido_tarjeta.dart — PART de
// overlay_compartido_contenido.dart: las cartas CHICAS del ítem.
//
// Dos formas, según lo que te compartieron:
// · canción → una fila compacta: carátula cuadrada + nombre/artista
//   + el ISRC (es lo que identifica el track exacto).
// · álbum/artista/playlist → una mini tarjeta de grilla, con su
//   carátula cuadrada y el badge del tipo encima.
//
// Las dos son chicas a propósito: anchos de celular (con tope) y
// colores del tema, así van bien en cualquier DPI y en cualquier tema.
//
// Se conecta con: overlay_compartido_contenido.dart (misma library).
// Parte del flujo: enlace compartido → carta → reproducir/encolar.
// ─────────────────────────────────────────────────────────────

part of 'overlay_compartido_contenido.dart';

/// Carta de una canción: fila compacta.
Widget _tarjetaTrackMini(
  ColorScheme cs,
  OverlayCompartidoContenido w,
  Responsive r,
  StringsSetup l,
) {
  final lado = (r.width * 0.12).clamp(42.0, 54.0);
  final ancho = (r.width * 0.72).clamp(200.0, 320.0);
  final titulo = w.item.name.isEmpty ? l.compartidoCancion : w.item.name;
  final artista = w.item.artists ?? '';

  return _placa(
    cs,
    r,
    width: ancho,
    child: Row(
      children: [
        _portadaCuadrada(cs, w, lado, radio: 10),
        SizedBox(width: r.spacingM),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.subtitleSize + 1,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              if (artista.isNotEmpty) ...[
                SizedBox(height: 2),
                Text(
                  artista,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.footerSize,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              if (w.isrc.isNotEmpty) ...[
                SizedBox(height: r.spacingS),
                _chipIsrc(cs, w.isrc, r),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Carta de álbum/artista/playlist: mini tarjeta de grilla.
Widget _tarjetaGridMini(
  ColorScheme cs,
  OverlayCompartidoContenido w,
  Responsive r,
  StringsSetup l,
) {
  final lado = (r.width * 0.42).clamp(112.0, 168.0);
  final titulo = w.item.name.isEmpty ? l.compartidoCancion : w.item.name;
  final subtitulo = (w.item.artists ?? '').isNotEmpty
      ? w.item.artists!
      : (w.item.albumName ?? '');

  return _placa(
    cs,
    r,
    width: lado + r.spacingM * 2,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            _portadaCuadrada(cs, w, lado, radio: 14),
            Positioned(
              top: r.spacingXS,
              left: r.spacingXS,
              child: _badgeTipo(cs, w, r, l),
            ),
          ],
        ),
        SizedBox(height: r.spacingS + 2),
        Text(
          titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.subtitleSize + 1,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        if (subtitulo.isNotEmpty) ...[
          SizedBox(height: 2),
          Text(
            subtitulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.footerSize,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}
