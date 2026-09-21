// ─────────────────────────────────────────────────────────────
// hoja_playlist_cabecera.dart — PART de hoja_playlist.dart: el
// tirador, el título de la hoja con el botón de guardar y la fila de
// portada + nombre de la playlist.
// Se conecta con: hoja_playlist.dart (misma library) + l10n.
// Parte del flujo: Mi Espacio / detalle → playlists (crear y editar).
// ─────────────────────────────────────────────────────────────

part of 'hoja_playlist.dart';

/// Tirador de la hoja.
Widget _tiradorHoja(Responsive r, Color onBg) => Container(
  margin: EdgeInsets.only(top: r.spacingM),
  width: 40,
  height: 4,
  decoration: BoxDecoration(
    color: onBg.withValues(alpha: 0.2),
    borderRadius: BorderRadius.circular(2),
  ),
);

/// Título de la hoja + botón de guardar.
Widget _cabeceraHoja(
  _HojaPlaylistState st,
  Responsive r,
  AppLocalizations loc,
  Color onBg,
  bool esOscuro,
) {
  final brillo = esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
  return Padding(
    padding: EdgeInsets.fromLTRB(r.spacingM + 6, r.spacingM, r.spacingM, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(
            st.esEdicion ? loc.setup.playlistEdit : loc.setup.nuevaPlaylist,
            style: TextStyle(
              fontSize: r.subtitleSize + 2,
              fontWeight: FontWeight.bold,
              color: onBg,
            ),
          ),
        ),
        if (st._guardando)
          Padding(
            padding: EdgeInsets.all(r.spacingS),
            child: SizedBox(
              width: r.subtitleSize + 4,
              height: r.subtitleSize + 4,
              child: CircularProgressIndicator(strokeWidth: 2, color: brillo),
            ),
          )
        else
          IconButton(
            tooltip: st.esEdicion ? loc.setup.save : loc.setup.crear,
            onPressed: () => _guardarPlaylist(st),
            icon: Icon(Icons.check_rounded, color: brillo),
          ),
      ],
    ),
  );
}

/// Portada elegible + nombre de la playlist + conteo de canciones.
Widget _portadaYNombre(
  _HojaPlaylistState st,
  Responsive r,
  AppLocalizations loc,
  Color onBg,
  bool esOscuro,
) {
  final brillo = esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
  return Padding(
    padding: EdgeInsets.symmetric(
      horizontal: r.spacingM + 6,
      vertical: r.spacingM,
    ),
    child: Row(
      children: [
        // La foto es OPCIONAL (se dice en el caption): sin ella la playlist
        // usa la carátula de su primera canción.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _selectorPortada(st, r, onBg, esOscuro),
            SizedBox(height: r.spacingXS),
            Text(
              loc.setup.optionalField,
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: onBg.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
        SizedBox(width: r.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: st._nombre,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: onBg, fontSize: r.subtitleSize),
                decoration: InputDecoration(
                  hintText: loc.setup.playlistNameHint,
                  hintStyle: TextStyle(color: onBg.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: onBg.withValues(alpha: 0.04),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: r.spacingM,
                    vertical: r.spacingS + 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: onBg.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: brillo),
                  ),
                ),
              ),
              SizedBox(height: r.spacingS),
              Text(
                '${st._canciones.length} ${loc.setup.miSpaceSongCount}',
                style: TextStyle(
                  fontSize: r.footerSize,
                  color: onBg.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
