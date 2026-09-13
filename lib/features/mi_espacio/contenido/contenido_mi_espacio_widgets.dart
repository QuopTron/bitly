// ─────────────────────────────────────────────────────────────
// contenido_mi_espacio_widgets.dart — PART de contenido_mi_espacio
// .dart: widgets auxiliares del contenido — botón compacto
// (icono + etiqueta), botón de crear playlist (con el diálogo
// compartido) e insignia de origen (amado/descargado/propio) para
// la esquina de las tarjetas de grilla.
// Se conecta con: contenido_mi_espacio.dart (misma library) +
// l10n + responsive.
// Parte del flujo: Home → Mi Espacio (widgets del contenido).
// ─────────────────────────────────────────────────────────────

part of 'contenido_mi_espacio.dart';

/// Botón compacto (icono + etiqueta) para acciones secundarias.
Widget _botonMini(
  ContenidoMiEspacio c,
  BuildContext context,
  Responsive r,
  IconData icono,
  String etiqueta,
  VoidCallback onTap,
  Color onBg,
  Color colorIcono,
) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacingS,
        vertical: r.spacingXS,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorIcono.withValues(alpha: 0.2)),
        color: colorIcono.withValues(alpha: 0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: r.footerSize - 2, color: colorIcono),
          SizedBox(width: 3),
          Text(
            etiqueta,
            style: TextStyle(fontSize: r.footerSize - 2, color: colorIcono),
          ),
        ],
      ),
    ),
  );
}

/// Botón de crear playlist (con el diálogo compartido).
Widget _botonCrear(
  ContenidoMiEspacio c,
  BuildContext context,
  Responsive r,
  Color onBg,
) {
  final loc = AppLocalizations.of(context);
  return GestureDetector(
    onTap: () async {
      await mostrarCrearPlaylist(context);
      c.onCreatePlaylist?.call();
    },
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacingL,
        vertical: r.spacingS,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onBg.withValues(alpha: 0.15)),
        color: onBg.withValues(alpha: 0.05),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add,
            size: r.footerSize,
            color: onBg.withValues(alpha: 0.5),
          ),
          SizedBox(width: r.spacingXS),
          Text(
            loc.setup.addToPlaylist,
            style: TextStyle(
              fontSize: r.footerSize,
              color: onBg.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Insignia compacta de origen (amado/descargado/propio).
Widget? _insigniaOrigen(BuildContext context, Item item) {
  if (item.origen == OrigenItem.ninguno) return null;
  final r = Responsive(context);
  final tamano = r.footerSize - 4;
  final (icono, color, etiqueta) = switch (item.origen) {
    OrigenItem.amado => (Icons.favorite, Colors.redAccent, null),
    OrigenItem.descargado => (Icons.download, const Color(0xFF4CAF50), null),
    OrigenItem.propio => (
        Icons.person_pin,
        const Color(0xFF4CAF50),
        AppLocalizations.of(context).setup.miSpaceOwned,
      ),
    OrigenItem.ninguno => (Icons.music_note, Colors.white70, null),
  };
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: Colors.black.withValues(alpha: 0.55),
      border: Border.all(color: color.withValues(alpha: 0.5), width: 0.7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: tamano, color: color),
        if (etiqueta != null) ...[
          SizedBox(width: 3),
          Text(
            etiqueta,
            style: TextStyle(
              fontSize: tamano - 2,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    ),
  );
}