// ─────────────────────────────────────────────────────────────
// modal_agregar_a_crear.dart — PART de modal_agregar_a.dart:
// diálogo de creación rápida de playlist (nombre + crear), usado
// cuando no existe ninguna playlist todavía. Al crear agrega el
// ítem si es un track.
// Se conecta con: modal_agregar_a.dart (misma library) +
// cubit_playlists + l10n + colores_app.
// Parte del flujo: acciones de ítem (crear playlist).
// ─────────────────────────────────────────────────────────────

part of 'modal_agregar_a.dart';

/// Abre el diálogo de crear playlist y devuelve el id creado (o null
/// si se cancela). Reutilizado por el modal "agregar a" y Mi Espacio.
Future<String?> mostrarCrearPlaylist(BuildContext context) {
  final cubit = sl<CubitPlaylists>();
  final r = Responsive(context);
  final loc = AppLocalizations.of(context);
  final controlador = TextEditingController();
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final onBg = ColoresApp.enSuperficie(esOscuro);
  final bg = ColoresApp.superficie(esOscuro);
  final brillo = esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.playlist_add_rounded, color: brillo, size: 22),
          SizedBox(width: r.spacingS),
          Text(
            loc.setup.nuevaPlaylist,
            style: TextStyle(
                color: onBg, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: TextField(
        controller: controlador,
        decoration: InputDecoration(
          hintText: loc.setup.playlistNameHint,
          hintStyle: TextStyle(color: onBg.withValues(alpha: 0.4)),
          filled: true,
          fillColor: onBg.withValues(alpha: 0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: onBg.withValues(alpha: 0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: brillo),
          ),
        ),
        style: TextStyle(color: onBg),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(loc.setup.cancel,
              style: TextStyle(color: onBg.withValues(alpha: 0.6))),
        ),
        TextButton(
          onPressed: () async {
            final nombre = controlador.text.trim();
            String? id;
            if (nombre.isNotEmpty) {
              id = await cubit.crearPlaylist(nombre);
            }
            if (ctx.mounted) Navigator.pop(ctx, id);
          },
          child: Text(loc.setup.crear,
              style: TextStyle(color: brillo, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  ).whenComplete(controlador.dispose);
}

/// Diálogo para crear una playlist desde el modal "agregar a" (y agrega
/// el track si es canción).
void _mostrarDialogoCrear(
    BuildContext context, CubitPlaylists cubit, ItemFeed item) async {
  final id = await mostrarCrearPlaylist(context);
  if (id != null && item.type == 'track') {
    cubit.agregarTrack(id, item.id);
  }
}