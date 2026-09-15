// ─────────────────────────────────────────────────────────────
// modal_agregar_a_hoja.dart — PART de modal_agregar_a.dart: arma la
// hoja del modal "agregar a" — tirador, vista previa del ítem y las
// opciones (playlist, lista de deseos, reproducir a continuación) — y
// le aplica el fondo según el estilo visual: color dominante del cover
// en modo Spotify o blur detrás en modo Clásico.
// Se conecta con: modal_agregar_a.dart (misma library).
// Parte del flujo: Reproductor → agregar a (hoja del modal).
// ─────────────────────────────────────────────────────────────

part of 'modal_agregar_a.dart';

Widget _construirHojaAgregarA(_AgregarAEstiloState st, BuildContext context) {
    return ValueListenableBuilder<EstiloVisual>(
      valueListenable: sl<ValueNotifier<EstiloVisual>>(),
      builder: (context, estilo, _) {
        return ValueListenableBuilder<PreferenciasEstilo>(
          valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
          builder: (context, prefs, _) {
            final spotify =
                estilo == EstiloVisual.spotify && prefs.fondosModals;
            final r = st.widget.r;
            final onBg = st.widget.onBg;
            final loc = st.widget.loc;
            final item = st.widget.item;

            Widget hoja = Container(
              decoration: BoxDecoration(
                color: st.widget.fondoModal,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
                    _vistaPrevia(r, onBg, item),
                    SizedBox(height: r.spacingM),
                    Divider(height: 1, color: onBg.withValues(alpha: 0.06)),
                    _opcion(r, onBg, Icons.playlist_add_rounded,
                        loc.setup.addToPlaylist, () {
                      Navigator.pop(context);
                      st._agregarAPlaylist(context, item);
                    }),
                    Divider(
                        height: 1, indent: 52, color: onBg.withValues(alpha: 0.06)),
                    _opcion(r, onBg, Icons.favorite_border_rounded,
                        loc.setup.addToWishlist, () {
                      Navigator.pop(context);
                      context.read<CubitLikes>().alternarLike(item);
                    }),
                    if (item.type == 'track') ...[
                      Divider(
                          height: 1,
                          indent: 52,
                          color: onBg.withValues(alpha: 0.06)),
                      _opcion(r, onBg, Icons.queue_music_rounded,
                          loc.setup.playNext, () {
                        Navigator.pop(context);
                        sl<CubitCola>().agregarSiguiente(item);
                      }),
                    ],
                    SizedBox(height: r.bottomPadding),
                  ],
                ),
              ),
            );

            if (spotify && st.widget.hayTrack && st._acento != null) {
              final defaultBg = st.widget.esOscuro
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF5F5F5);
              final colorFinal = Color.lerp(
                defaultBg,
                st._acento!,
                st.widget.esOscuro ? 0.45 : 0.30,
              )!;
              hoja = ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  color: colorFinal,
                  child: hoja,
                ),
              );
            } else if (st.widget.hayTrack) {
              hoja = ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: hoja,
                ),
              );
            }
            return hoja;
          },
        );
      },
    );
  
}
