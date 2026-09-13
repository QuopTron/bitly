// ─────────────────────────────────────────────────────────────
// modal_agregar_a.dart — Modal inferior "agregar a": agrega el
// ítem a una playlist (con picker o creación), a favoritos, o lo
// pone como siguiente en la cola (solo tracks). El picker y la
// creación viven en modal_agregar_a_picker/crear.dart y las piezas
// visuales en modal_agregar_a_widgets.dart.
// Se conecta con: cubit_playlists + cubit_like + cubit_cola +
// l10n + colores_app + vidrio (fondo desenfocado con track).
// Parte del flujo: acciones de ítem (más) — feed, búsqueda, mi
// espacio.
// ─────────────────────────────────────────────────────────────

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/inyeccion.dart';
import '../../../../core/modelos/usuario/estilo_visual.dart';
import '../../../../core/modelos/feed/item_feed.dart';
import '../../../../core/modelos/usuario/preferencias_estilo.dart';
import '../../../../estado/cola/cubit_cola.dart';
import '../../../../estado/like/cubit_like.dart';
import '../../../../estado/playlists/cubit_playlists.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../tema/colores_app.dart';
import '../../../utilidades/portada/paleta_portada.dart';
import '../../../utilidades/plataforma/responsive.dart';

part 'modal_agregar_a_crear.dart';
part 'modal_agregar_a_inline.dart';
part 'modal_agregar_a_picker.dart';
part 'modal_agregar_a_widgets.dart';

/// Abre el modal "agregar a" para un ítem de la app.
void mostrarAgregarA(BuildContext context, ItemFeed item) {
  final r = Responsive(context);
  final loc = AppLocalizations.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _HojaAgregarA(r: r, loc: loc, item: item),
  );
}

class _HojaAgregarA extends StatelessWidget {
  final Responsive r;
  final AppLocalizations loc;
  final ItemFeed item;

  const _HojaAgregarA({required this.r, required this.loc, required this.item});

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(esOscuro);
    final bg = ColoresApp.superficie(esOscuro);
    final hayTrack = sl<CubitCola>().state.tieneActual;
    final fondoModal = hayTrack ? bg.withValues(alpha: 0.85) : bg;

    return _AgregarAEstilo(
      esOscuro: esOscuro,
      onBg: onBg,
      bg: bg,
      hayTrack: hayTrack,
      fondoModal: fondoModal,
      r: r,
      loc: loc,
      item: item,
    );
  }
}

/// Widget wrapper that reacts to visual style for blur/dominant color.
class _AgregarAEstilo extends StatefulWidget {
  final bool esOscuro;
  final Color onBg;
  final Color bg;
  final bool hayTrack;
  final Color fondoModal;
  final Responsive r;
  final AppLocalizations loc;
  final ItemFeed item;

  const _AgregarAEstilo({
    required this.esOscuro,
    required this.onBg,
    required this.bg,
    required this.hayTrack,
    required this.fondoModal,
    required this.r,
    required this.loc,
    required this.item,
  });

  @override
  State<_AgregarAEstilo> createState() => _AgregarAEstiloState();
}

class _AgregarAEstiloState extends State<_AgregarAEstilo> {
  Color? _acento;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  Future<void> _extraerColor() async {
    final url = widget.item.coverUrl;
    if (url == null || url.isEmpty) return;
    try {
      final paleta = await paletaParaPortada(url);
      if (mounted) setState(() => _acento = paleta?.dominante);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstiloVisual>(
      valueListenable: sl<ValueNotifier<EstiloVisual>>(),
      builder: (context, estilo, _) {
        return ValueListenableBuilder<PreferenciasEstilo>(
          valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
          builder: (context, prefs, _) {
            final spotify =
                estilo == EstiloVisual.spotify && prefs.fondosModals;
            final r = widget.r;
            final onBg = widget.onBg;
            final loc = widget.loc;
            final item = widget.item;

            Widget hoja = Container(
              decoration: BoxDecoration(
                color: widget.fondoModal,
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
                      _agregarAPlaylist(context, item);
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

            if (spotify && widget.hayTrack && _acento != null) {
              final defaultBg = widget.esOscuro
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF5F5F5);
              final colorFinal = Color.lerp(
                defaultBg,
                _acento!,
                widget.esOscuro ? 0.45 : 0.30,
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
            } else if (widget.hayTrack) {
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

  /// Abre el picker de playlists o el diálogo de creación si no hay ninguna.
  void _agregarAPlaylist(BuildContext context, ItemFeed item) {
    final cubit = sl<CubitPlaylists>();
    if (cubit.state.playlists.isEmpty) {
      _mostrarDialogoCrear(context, cubit, item);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _SelectorPlaylist(r: widget.r, cubit: cubit, item: item),
    );
  }
}