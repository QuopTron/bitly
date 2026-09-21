// ─────────────────────────────────────────────────────────────
// modal_agregar_a_crear.dart — PART de modal_agregar_a.dart: abre la
// HOJA de playlist (la misma que crea y edita desde Mi Espacio) con
// la canción ya cargada, en vez del viejo diálogo flotante.
// Se conecta con: modal_agregar_a.dart (misma library) +
// hoja_playlist + l10n.
// Parte del flujo: acciones de ítem (crear playlist y agregar).
// ─────────────────────────────────────────────────────────────

part of 'modal_agregar_a.dart';

/// Crea una playlist nueva desde el modal "agregar a", dejando [item] ya
/// dentro. Devuelve el id creado (o null si se canceló).
/// Va con `sobreHoja` porque sale desde dentro de esa hoja (el velo de la hoja
/// de playlist tapa la de abajo, así nunca se ven dos modales).
Future<String?> _mostrarCrearPlaylistDesdeItem(
  BuildContext context,
  ItemFeed item,
) => mostrarHojaPlaylist(context, semilla: item, sobreHoja: true);
