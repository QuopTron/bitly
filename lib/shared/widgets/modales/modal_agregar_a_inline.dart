// ─────────────────────────────────────────────────────────────
// modal_agregar_a_inline.dart — PART de modal_agregar_a.dart:
// hoja inline de creación rápida de playlist desde el selector
// (página fullscreen con campo de nombre y botón crear+agregar).
// Se conecta con: modal_agregar_a.dart (misma library) +
// cubit_playlists + l10n + colores_app.
// Parte del flujo: acciones de ítem (crear playlist).
// ─────────────────────────────────────────────────────────────

part of 'modal_agregar_a.dart';

/// Hoja inline de creación usada desde el selector de playlists.
class _CrearPlaylistInline extends StatefulWidget {
  final ItemFeed item;
  const _CrearPlaylistInline({required this.item});

  @override
  State<_CrearPlaylistInline> createState() => _CrearPlaylistInlineState();
}

class _CrearPlaylistInlineState extends State<_CrearPlaylistInline> {
  final _ctrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final brillo = esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: loc.setup.playlistNameHint),
          ),
          SizedBox(height: r.spacingM),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _guardando
                  ? null
                  : () async {
                      setState(() => _guardando = true);
                      final id = await sl<CubitPlaylists>()
                          .crearPlaylist(_ctrl.text.trim());
                      if (id != null && widget.item.type == 'track') {
                        await sl<CubitPlaylists>()
                            .agregarTrack(id, widget.item.id);
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: brillo,
                foregroundColor: Colors.white,
              ),
              child: _guardando
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(loc.setup.crearYAgregar),
            ),
          ),
        ],
      ),
    );
  }
}