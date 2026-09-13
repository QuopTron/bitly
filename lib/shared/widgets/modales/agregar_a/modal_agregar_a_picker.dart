// ─────────────────────────────────────────────────────────────
// modal_agregar_a_picker.dart — PART de modal_agregar_a.dart:
// selector de playlist (lista de playlists con opción de crear
// nueva) y la hoja inline de creación rápida. Cada playlist se
// agrega el ítem y confirma con SnackBar flotante.
// Se conecta con: modal_agregar_a.dart (misma library) +
// cubit_playlists + l10n + colores_app.
// Parte del flujo: acciones de ítem (agregar a playlist).
// ─────────────────────────────────────────────────────────────

part of 'modal_agregar_a.dart';

/// Selector de playlists: crear nueva o elegir una existente.
class _SelectorPlaylist extends StatelessWidget {
  final Responsive r;
  final CubitPlaylists cubit;
  final ItemFeed item;

  const _SelectorPlaylist({required this.r, required this.cubit, required this.item});

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(esOscuro);
    final bg = ColoresApp.superficie(esOscuro);
    final brillo = esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final loc = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: r.spacingM),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: onBg.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.spacingM),
            Text(
              loc.setup.seleccionarPlaylist,
              style: TextStyle(
                fontSize: r.subtitleSize + 1,
                fontWeight: FontWeight.bold,
                color: onBg,
              ),
            ),
            SizedBox(height: r.spacingS),
            ListTile(
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
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => Scaffold(
                      body: _CrearPlaylistInline(item: item),
                    ),
                  ),
                );
              },
            ),
            Divider(height: 1, color: onBg.withValues(alpha: 0.06)),
            ...cubit.state.playlists.map((p) => ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: onBg.withValues(alpha: 0.06),
                    ),
                    child: p.coverPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              p.coverPath!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, e, s) => Icon(
                                Icons.playlist_play_rounded,
                                color: onBg.withValues(alpha: 0.4),
                                size: 20,
                              ),
                            ),
                          )
                        : Icon(Icons.playlist_play_rounded,
                            color: onBg.withValues(alpha: 0.4), size: 20),
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(color: onBg, fontSize: r.subtitleSize - 1),
                  ),
                  subtitle: Text(
                    '${p.itemCount} ${loc.setup.miSpaceSongCount}',
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color: onBg.withValues(alpha: 0.4),
                    ),
                  ),
                  onTap: () {
                    if (item.type == 'track') {
                      cubit.agregarTrack(p.id, item.id);
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(loc.setup.agregadoAPlaylist
                          .replaceFirst('{name}', p.name)),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                )),
            SizedBox(height: r.bottomPadding),
          ],
        ),
      ),
    );
  }
}

