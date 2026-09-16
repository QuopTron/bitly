// ─────────────────────────────────────────────────────────────
// overlay_compartido_encabezado.dart — PART de
// overlay_compartido_contenido.dart: el encabezado de la carta.
//
// Arriba dice "te compartieron" (traducido) y, si el enlace trae el
// dato, un chip con la inicial de quien lo mandó y su nombre.
//
// Se conecta con: overlay_compartido_contenido.dart (misma library).
// Parte del flujo: enlace compartido → carta → reproducir/encolar.
// ─────────────────────────────────────────────────────────────

part of 'overlay_compartido_contenido.dart';

/// Encabezado: frase de "te compartieron" + quién lo mandó.
Widget _cabeceraOverlay(
  ColorScheme cs,
  OverlayCompartidoContenido w,
  Responsive r,
  StringsSetup l,
) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        l.compartidoTitulo.toUpperCase(),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: r.footerSize,
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.4,
        ),
      ),
      if (w.emisor.isNotEmpty) ...[
        SizedBox(height: r.spacingS),
        _chipEmisor(cs, w.emisor, r, l),
      ],
    ],
  );
}

/// Chip de quien compartió: inicial en círculo + "Compartido por …".
Widget _chipEmisor(
  ColorScheme cs,
  String emisor,
  Responsive r,
  StringsSetup l,
) {
  final lado = r.footerSize + 12;
  return Container(
    padding: EdgeInsets.only(
      left: 3,
      right: r.spacingM,
      top: 3,
      bottom: 3,
    ),
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: lado,
          height: lado,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            emisor.trim().substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontSize: r.footerSize,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ),
        SizedBox(width: r.spacingS),
        Flexible(
          child: Text(
            l.compartidosDe.replaceAll('{user}', emisor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.footerSize + 1,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    ),
  );
}
