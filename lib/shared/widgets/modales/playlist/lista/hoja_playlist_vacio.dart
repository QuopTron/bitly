// ─────────────────────────────────────────────────────────────
// hoja_playlist_vacio.dart — PART de hoja_playlist.dart: el estado
// vacío de la playlist (todavía no hay ninguna canción).
//
// Va dentro de un scroll con alto mínimo: en una ventana baja (o el
// celular en apaisado) el bloque no entra y sin esto el `Column`
// desbordaba con la franja amarilla de overflow.
// Se conecta con: hoja_playlist.dart (misma library) + l10n.
// Parte del flujo: Mi Espacio / detalle → playlists (crear y editar).
// ─────────────────────────────────────────────────────────────

part of '../base/hoja_playlist.dart';

/// Estado vacío: todavía no hay ninguna canción en la playlist.
Widget _cancionesVacias(Responsive r, AppLocalizations loc, Color onBg) {
  return LayoutBuilder(
    builder:
        (context, limites) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: limites.maxHeight),
            child: Center(child: _mensajeVacio(r, loc, onBg)),
          ),
        ),
  );
}

/// Icono + textos del estado vacío.
Widget _mensajeVacio(Responsive r, AppLocalizations loc, Color onBg) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingL),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.queue_music_rounded,
          size: r.spacingXL * 2,
          color: onBg.withValues(alpha: 0.25),
        ),
        SizedBox(height: r.spacingS),
        Text(
          loc.setup.playlistEmpty,
          style: TextStyle(
            fontSize: r.subtitleSize - 1,
            fontWeight: FontWeight.w600,
            color: onBg.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          loc.setup.playlistEmptyHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.footerSize,
            color: onBg.withValues(alpha: 0.4),
          ),
        ),
      ],
    ),
  );
}
