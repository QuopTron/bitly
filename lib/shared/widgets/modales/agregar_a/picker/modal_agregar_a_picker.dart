// ─────────────────────────────────────────────────────────────
// modal_agregar_a_picker.dart — PART de modal_agregar_a.dart:
// selector de playlists. Lista MIS playlists CREADAS (las `col_*` de
// drift, que son las únicas editables) con su portada y su cantidad de
// canciones, más la opción de crear una nueva. Al elegir una, la
// canción entra por el editor de playlists (queda en la biblioteca
// local, al final y sin duplicarse).
// Las filas viven en modal_agregar_a_picker_filas.dart.
// Se conecta con: modal_agregar_a.dart (misma library) +
// cache_colecciones + editor_playlist + fondo reactivo + l10n.
// Parte del flujo: acciones de ítem (agregar a playlist).
// ─────────────────────────────────────────────────────────────

part of '../base/modal_agregar_a.dart';

/// Selector de playlists creadas: crear nueva o elegir una existente.
class _SelectorPlaylist extends StatefulWidget {
  final Responsive r;
  final ItemFeed item;

  const _SelectorPlaylist({required this.r, required this.item});

  @override
  State<_SelectorPlaylist> createState() => _SelectorPlaylistState();
}

class _SelectorPlaylistState extends State<_SelectorPlaylist> {
  List<PlaylistPropia>? _playlists;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final propias = await sl<CacheColecciones>().getPlaylistsPropias();
    if (!mounted) return;
    setState(() => _playlists = propias);
  }

  /// Suma el ítem a [playlist] y cierra el selector avisando con un snack.
  Future<void> _agregarA(PlaylistPropia playlist) async {
    final loc = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (widget.item.type == 'track') {
      await sl<ServicioEditorPlaylist>().agregarItem(playlist.id, widget.item);
    }
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          loc.setup.agregadoAPlaylist.replaceFirst('{name}', playlist.nombre),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(esOscuro);
    final bg = ColoresApp.superficie(esOscuro);
    final brillo = esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final loc = AppLocalizations.of(context);
    final caratula = sl<CubitCola>().state.actual?.coverUrl;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Mismo fondo reactivo que el resto de los modales.
          Positioned.fill(
            child: FondoReactivoPortada(caratula: caratula, esOscuro: esOscuro),
          ),
          Column(
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
              _filaCrearPlaylist(this, r, onBg, brillo, loc),
              Divider(height: 1, color: onBg.withValues(alpha: 0.06)),
              ..._filasPlaylists(this, r, onBg, loc),
              SizedBox(height: r.bottomPadding + insetInferiorSistema(context)),
            ],
          ),
        ],
      ),
    );
  }
}
