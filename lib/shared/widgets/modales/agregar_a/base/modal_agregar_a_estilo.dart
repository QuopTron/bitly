// ─────────────────────────────────────────────────────────────
// modal_agregar_a_estilo.dart — PART de modal_agregar_a.dart:
// el estado del modal "agregar a" (su acción de abrir el selector) y
// el armado de la hoja con el fondo reactivo a la carátula.
//
// Antes este archivo extraía su propio color dominante y aplicaba su
// propio tinte/desenfoque: el modal se veía distinto del karaoke, la
// cola o la playlist. Ahora el fondo es el MISMO widget compartido
// (FondoReactivoPortada), así todos los modales se ven igual.
// Se conecta con: modal_agregar_a.dart (misma library) + l10n.
// Parte del flujo: Reproductor → agregar a (estilo visual).
// ─────────────────────────────────────────────────────────────

part of 'modal_agregar_a.dart';

/// Estado del modal "agregar a" (la hoja en sí se arma acá abajo).
class _AgregarAEstilo extends StatefulWidget {
  final bool esOscuro;
  final Color onBg;
  final Color bg;
  final Responsive r;
  final AppLocalizations loc;
  final ItemFeed item;

  const _AgregarAEstilo({
    required this.esOscuro,
    required this.onBg,
    required this.bg,
    required this.r,
    required this.loc,
    required this.item,
  });

  @override
  State<_AgregarAEstilo> createState() => _AgregarAEstiloState();
}

class _AgregarAEstiloState extends State<_AgregarAEstilo> {
  @override
  Widget build(BuildContext context) => _construirHojaAgregarA(this, context);

  /// Abre SIEMPRE el selector de playlists creadas.
  ///
  /// Antes se saltaba el selector cuando el cubit decía "no hay playlists",
  /// pero ese estado viene de otra fuente (ServicioDominioPlaylist) y podía
  /// estar vacío aunque sí hubiera creadas: ahí el botón no dejaba elegir
  /// ninguna. El selector lista `getPlaylistsPropias()` y trae la fila "crear
  /// nueva", así que sirve igual con cero playlists. Todo va con `sobreHoja`:
  /// tapa esta hoja por completo, así que nunca se ven dos modales a la vez.
  void _agregarAPlaylist(BuildContext context, ItemFeed item) {
    mostrarHoja<void>(
      context: context,
      sobreHoja: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SelectorPlaylist(r: widget.r, item: item),
    );
  }
}

/// Hoja del modal: mismo fondo reactivo que el resto de los modales.
Widget _construirHojaAgregarA(_AgregarAEstiloState st, BuildContext context) {
  final r = st.widget.r;
  final onBg = st.widget.onBg;
  final loc = st.widget.loc;
  final item = st.widget.item;

  return Container(
    decoration: BoxDecoration(
      color: st.widget.bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned.fill(
          child: FondoReactivoPortada(
            caratula: item.coverUrl,
            esOscuro: st.widget.esOscuro,
          ),
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
            _vistaPrevia(r, onBg, item),
            SizedBox(height: r.spacingM),
            Divider(height: 1, color: onBg.withValues(alpha: 0.06)),
            _opcion(
              r,
              onBg,
              Icons.playlist_add_rounded,
              loc.setup.addToPlaylist,
              () {
                Navigator.pop(context);
                st._agregarAPlaylist(context, item);
              },
            ),
            Divider(height: 1, indent: 52, color: onBg.withValues(alpha: 0.06)),
            _opcion(
              r,
              onBg,
              Icons.favorite_border_rounded,
              loc.setup.addToWishlist,
              () {
                Navigator.pop(context);
                // Singleton de DI: la hoja vive por encima de los providers
                // de la Home, así que `context.read` no los alcanzaba.
                sl<CubitLikes>().alternarLike(item);
              },
            ),
            if (item.type == 'track') ...[
              Divider(
                height: 1,
                indent: 52,
                color: onBg.withValues(alpha: 0.06),
              ),
              _opcion(
                r,
                onBg,
                Icons.queue_music_rounded,
                loc.setup.playNext,
                () {
                  Navigator.pop(context);
                  sl<CubitCola>().agregarSiguiente(item);
                },
              ),
            ],
            // + menú de navegación del sistema: la hoja se ancla al
            // borde físico, sin esto el último botón queda debajo.
            SizedBox(height: r.bottomPadding + insetInferiorSistema(context)),
          ],
        ),
      ],
    ),
  );
}
