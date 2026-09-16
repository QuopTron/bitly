// ─────────────────────────────────────────────────────────────
// overlay_compartido_arte.dart — PART de
// overlay_compartido_contenido.dart: piezas chicas de la carta — la
// placa que la sostiene, la portada cuadrada, el chip del ISRC y el
// badge del tipo compartido.
//
// Todo se pinta con los colores del TEMA (blanco y negro): así la
// carta se ve bien tanto en tema claro como oscuro sin colores de
// marca. Las etiquetas del tipo salen del l10n.
//
// La portada usa ImagenPortada, el mismo widget de toda la
// biblioteca, con decode acotado al tamaño real (menos RAM).
//
// Se conecta con: overlay_compartido_contenido.dart (misma library).
// Parte del flujo: enlace compartido → carta → reproducir/encolar.
// ─────────────────────────────────────────────────────────────

part of 'overlay_compartido_contenido.dart';

/// Placa translúcida que sostiene la carta.
Widget _placa(
  ColorScheme cs,
  Responsive r, {
  required double width,
  required Widget child,
}) {
  return Container(
    width: width,
    padding: EdgeInsets.all(r.spacingM),
    decoration: BoxDecoration(
      color: cs.surface.withValues(alpha: 0.90),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.26),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

/// Portada cuadrada del tamaño pedido, con reserva si no hay imagen.
Widget _portadaCuadrada(
  ColorScheme cs,
  OverlayCompartidoContenido w,
  double lado, {
  double radio = 12,
}) {
  final cover = w.item.coverUrl;
  // Reserva: si no hay carátula —o si la URL falla— queda el icono del
  // tipo sobre el color de superficie. Antes el error dejaba la caja
  // vacía y la carta parecía no cargar nada.
  final reserva = ColoredBox(
    color: cs.surfaceContainerHighest,
    child: Center(
      child: Icon(
        _iconoTipo(w),
        size: lado * 0.4,
        color: cs.onSurfaceVariant,
      ),
    ),
  );
  return ClipRRect(
    borderRadius: BorderRadius.circular(radio),
    child: SizedBox(
      width: lado,
      height: lado,
      child: (cover != null && cover.isNotEmpty)
          // Ancho/alto acotan el decode al tamaño real de la carta (menos
          // RAM) y ante un error se cae a la reserva, no a una caja vacía.
          ? ImagenPortada(
              coverUrl: cover,
              ancho: lado,
              alto: lado,
              radioBorde: radio,
              fondoFallback: cs.surfaceContainerHighest,
              fallback: reserva,
            )
          : reserva,
    ),
  );
}

/// Chip con el ISRC: la identidad exacta de la canción.
Widget _chipIsrc(ColorScheme cs, String isrc, Responsive r) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 2),
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
    ),
    child: Text(
      isrc,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: r.footerSize - 1,
        letterSpacing: 0.4,
        color: cs.onSurfaceVariant,
      ),
    ),
  );
}

/// Badge del tipo compartido (canción / álbum / artista / playlist).
Widget _badgeTipo(
  ColorScheme cs,
  OverlayCompartidoContenido w,
  Responsive r,
  StringsSetup l,
) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 2),
    decoration: BoxDecoration(
      color: cs.surface.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_iconoTipo(w), size: r.footerSize, color: cs.onSurfaceVariant),
        SizedBox(width: r.spacingXS),
        Text(
          _etiquetaTipo(w, l),
          style: TextStyle(
            fontSize: r.footerSize - 1,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
