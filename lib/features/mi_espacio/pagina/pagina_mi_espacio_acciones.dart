// ─────────────────────────────────────────────────────────────
// pagina_mi_espacio_acciones.dart — PART de pagina_mi_espacio
// .dart: acciones de la página — cambio de tema/idioma (persistido
// en CacheAjustes), like, creación de playlists desde canciones
// amadas o desde el historial de descargas, descarga por lote
// (álbum/playlist), borrado de lote, reintento y exportación.
// Reutiliza AccionesItem para la lógica globalizada de ítems.
// Se conecta con: pagina_mi_espacio.dart (misma library) +
// cubits + servicio_dominio_playlist + cache_descargas.
// Parte del flujo: Home → Mi Espacio (acciones del usuario).
// ─────────────────────────────────────────────────────────────

part of 'pagina_mi_espacio.dart';

/// Cambia el tema global y lo persiste.
void _onTemaCambiado(_PaginaMiEspacioState st, bool esOscuro) {
  final modo = esOscuro ? ThemeMode.dark : ThemeMode.light;
  sl<ValueNotifier<ThemeMode>>().value = modo;
  sl<CacheAjustes>().guardarTema(modo == ThemeMode.dark ? 'dark' : 'light');
}

/// Alterna el idioma global (ES/EN) y lo persiste.
void _onIdiomaCambiado(_PaginaMiEspacioState st) {
  final actual = sl<ValueNotifier<Locale>>().value;
  final siguiente =
      actual.languageCode == 'es' ? const Locale('en') : const Locale('es');
  sl<ValueNotifier<Locale>>().value = siguiente;
  sl<CacheAjustes>().guardarIdioma(siguiente.languageCode);
}

/// Da like a un ítem (toggle).
void _onLike(_PaginaMiEspacioState st, Item item) {
  if (item.idReal.isEmpty) return;
  st.context.read<CubitLikes>().alternarLike(_itemFeedPara(st, item));
}

/// Recarga las playlists propias tras crear/borrar una.
Future<void> _onCrearPlaylist(_PaginaMiEspacioState st) async {
  await st._recargarPlaylists();
}

/// Crea una playlist con todas las canciones amadas.
Future<void> _onCrearPlaylistDesdeAmados(_PaginaMiEspacioState st) async {
  final loc = AppLocalizations.of(st.context);
  final servicio = sl<ServicioDominioPlaylist>();
  final likedCubit = st.context.read<CubitLikes>();
  final tracks = likedCubit.tracks;
  if (tracks.isEmpty) return;

  final nombre =
      '${loc.setup.likedSongs} (${DateTime.now().toString().substring(0, 10)})';
  final creada = await servicio.crear(nombre);
  if (creada == null) return;

  for (final t in tracks) {
    await servicio.agregarTrack(creada.id, t.id);
  }
  await servicio.garantizarCaratula(
    creada.id,
    tracks.map((t) => t.coverUrl).toList(),
  );

  await _onCrearPlaylist(st);
  if (st.mounted) {
    _mostrarSnack(
      st,
      '${loc.setup.miSpacePlaylist} "$nombre" ${loc.setup.downloaded}',
    );
  }
}

/// Crea una playlist con todos los tracks del historial de descargas.
Future<void> _onCrearPlaylistDesdeDescargados(_PaginaMiEspacioState st) async {
  final loc = AppLocalizations.of(st.context);
  final servicio = sl<ServicioDominioPlaylist>();
  try {
    final historialJson = await sl<CacheDescargas>().getHistorialDescargas();
    if (historialJson.isEmpty || historialJson == '[]') return;
    final lista = jsonDecode(historialJson) as List;
    if (lista.isEmpty) return;

    final nombre =
        '${loc.setup.downloaded} (${DateTime.now().toString().substring(0, 10)})';
    final creada = await servicio.crear(nombre);
    if (creada == null) return;

    final caratulas = <String?>[];
    for (final e in lista) {
      final m = e as Map<String, dynamic>;
      final trackId = (m['track_id'] ?? m['id'] ?? '').toString();
      if (trackId.isNotEmpty) {
        await servicio.agregarTrack(creada.id, trackId);
      }
      final cover = (m['coverUrl'] ?? m['cover_url'] ?? m['coverPath'] ?? '')
          .toString();
      if (cover.isNotEmpty) caratulas.add(cover);
    }
    await servicio.garantizarCaratula(creada.id, caratulas);

    await _onCrearPlaylist(st);
    if (st.mounted) {
      _mostrarSnack(
        st,
        '${loc.setup.miSpacePlaylist} "$nombre" ${loc.setup.downloaded}',
      );
    }
  } catch (_) {}
}

/// Descarga por lote (álbum/playlist) con la acción globalizada.
Future<void> _onDescargaLote(_PaginaMiEspacioState st, Item item) async {
  final src = _resolverFuente(st, item);
  if (src.isEmpty) return;
  await AccionesItem.iniciarDescargaLote(st.context, _itemFeedPara(st, item));
}

/// Borra la descarga por lote de un álbum/playlist.
void _onBorrarLote(_PaginaMiEspacioState st, Item item) {
  AccionesItem.borrarLote(st.context, _itemFeedPara(st, item));
}

/// Reintenta los tracks fallidos de un lote.
void _onReintentarLote(_PaginaMiEspacioState st, Item item) {
  final tipo = item.tipo == TipoItem.album ? 'album' : 'playlist';
  final batchKey =
      '${tipo}_${normalizarIdTrack(item.idReal)}_${item.fuente}';
  st.context.read<CubitDescargas>().reintentarTracksFallidosLote(batchKey);
}

/// Exporta una playlist/álbum a M3U/CUE/NFO.
Future<void> _onExportarPlaylist(_PaginaMiEspacioState st, Item item) async =>
    AccionesItem.exportarPlaylist(st.context, _itemFeedPara(st, item));

/// Muestra un SnackBar breve.
void _mostrarSnack(_PaginaMiEspacioState st, String msg) {
  ScaffoldMessenger.of(st.context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );
}