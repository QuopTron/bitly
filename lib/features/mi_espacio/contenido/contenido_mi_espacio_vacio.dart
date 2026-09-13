// ─────────────────────────────────────────────────────────────
// contenido_mi_espacio_vacio.dart — PART de contenido_mi_espacio
// .dart: estados vacíos de Mi Espacio — vista genérica (icono +
// mensaje localizado) y la vista especial de Playlists vacías con
// botón de crear la primera playlist.
// Se conecta con: contenido_mi_espacio.dart (misma library) +
// l10n + responsive.
// Parte del flujo: Home → Mi Espacio (estados vacíos).
// ─────────────────────────────────────────────────────────────

part of 'contenido_mi_espacio.dart';

/// Estado vacío genérico (icono + mensaje).
Widget _vistaVacia(
    ContenidoMiEspacio c, BuildContext context, Responsive r, Color onBg) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.favorite_border,
          size: r.titleSize * 1.5,
          color: onBg.withValues(alpha: 0.12),
        ),
        SizedBox(height: r.spacingM),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
          child: Text(
            c.mensajeVacio,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.footerSize,
              color: onBg.withValues(alpha: 0.3),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Estado vacío de la pestaña Playlists (con botón de crear).
Widget _vistaVaciaPlaylists(
    ContenidoMiEspacio c, BuildContext context, Responsive r, Color onBg) {
  final loc = AppLocalizations.of(context);
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.queue_music,
          size: r.titleSize * 1.5,
          color: onBg.withValues(alpha: 0.12),
        ),
        SizedBox(height: r.spacingM),
        Text(
          loc.setup.miSpaceEmptyPlaylists,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.footerSize,
            color: onBg.withValues(alpha: 0.3),
          ),
        ),
        SizedBox(height: r.spacingM),
        _botonCrear(c, context, r, onBg),
      ],
    ),
  );
}