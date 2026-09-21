// ─────────────────────────────────────────────────────────────
// modal_agregar_a_picker_filas.dart — PART de modal_agregar_a.dart:
// las filas del selector de playlists — la opción de crear una nueva
// (que abre la hoja de playlist con la canción ya cargada) y las
// playlists creadas existentes, con portada y conteo.
// Se conecta con: modal_agregar_a.dart (misma library) + ImagenPortada.
// Parte del flujo: acciones de ítem (agregar a playlist).
// ─────────────────────────────────────────────────────────────

part of '../base/modal_agregar_a.dart';

/// Opción "crear nueva": abre la hoja de playlist con la canción cargada.
///
/// Va sobre el selector (`sobreHoja`) y recién lo cierra al guardar: si no,
/// quedaría mostrando la lista vieja, sin la playlist recién creada.
Widget _filaCrearPlaylist(
  _SelectorPlaylistState st,
  Responsive r,
  Color onBg,
  Color brillo,
  AppLocalizations loc,
) {
  return ListTile(
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: brillo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.add_rounded, color: brillo, size: r.subtitleSize),
    ),
    title: Text(
      loc.setup.crearNuevaPlaylist,
      style: TextStyle(
        color: brillo,
        fontWeight: FontWeight.w600,
        fontSize: r.subtitleSize - 1,
      ),
    ),
    onTap: () async {
      final navigator = Navigator.of(st.context);
      final messenger = ScaffoldMessenger.of(st.context);
      final id = await _mostrarCrearPlaylistDesdeItem(
        st.context,
        st.widget.item,
      );
      if (id == null || !st.mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(loc.setup.playlistSaved),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    },
  );
}

/// Las playlists creadas: portada, nombre y cuántas canciones tienen.
List<Widget> _filasPlaylists(
  _SelectorPlaylistState st,
  Responsive r,
  Color onBg,
  AppLocalizations loc,
) {
  final playlists = st._playlists;
  if (playlists == null) return [_cargandoPlaylists(r, onBg)];
  if (playlists.isEmpty) return [_sinPlaylists(r, onBg, loc)];
  return playlists.map((p) => _filaPlaylist(st, r, onBg, loc, p)).toList();
}

/// Fila de una playlist creada.
Widget _filaPlaylist(
  _SelectorPlaylistState st,
  Responsive r,
  Color onBg,
  AppLocalizations loc,
  PlaylistPropia p,
) {
  return ListTile(
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: onBg.withValues(alpha: 0.06),
      ),
      // La portada puede ser URL O archivo local: ImagenPortada resuelve las
      // dos, Image.network solo la primera.
      child:
          (p.portada ?? '').isEmpty
              ? Icon(
                Icons.playlist_play_rounded,
                color: onBg.withValues(alpha: 0.4),
                size: 20,
              )
              : ImagenPortada(
                coverUrl: p.portada,
                rutaLocal: p.portada,
                radioBorde: 8,
              ),
    ),
    title: Text(
      p.nombre,
      style: TextStyle(color: onBg, fontSize: r.subtitleSize - 1),
    ),
    subtitle: Text(
      '${p.canciones} ${loc.setup.miSpaceSongCount}',
      style: TextStyle(
        fontSize: r.footerSize - 2,
        color: onBg.withValues(alpha: 0.4),
      ),
    ),
    onTap: () => st._agregarA(p),
  );
}

/// Mientras se leen las playlists creadas de la base.
Widget _cargandoPlaylists(Responsive r, Color onBg) {
  return Padding(
    padding: EdgeInsets.all(r.spacingL),
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: onBg.withValues(alpha: 0.4),
        ),
      ),
    ),
  );
}

/// Todavía no hay ninguna playlist creada.
Widget _sinPlaylists(Responsive r, Color onBg, AppLocalizations loc) {
  return Padding(
    padding: EdgeInsets.all(r.spacingL),
    child: Text(
      loc.setup.playlistEmptyHint,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: r.footerSize,
        color: onBg.withValues(alpha: 0.5),
      ),
    ),
  );
}
