// ─────────────────────────────────────────────────────────────
// modal_info_cancion.dart — Modal inferior con la info de un ítem:
// carátula, nombre, artista, filas de detalle y compartir. Con un
// track reproduciéndose el fondo usa vidrio desenfocado. Las
// piezas visuales viven en modal_info_cancion_widgets.dart.
// Se conecta con: imagen_portada + cubit_cola + l10n + share_plus.
// Parte del flujo: acciones de ítem (info) — todas las vistas.
// ─────────────────────────────────────────────────────────────

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/inyeccion.dart';
import '../../core/modelos/item_feed.dart';
import '../../estado/cubit_cola.dart';
import '../../l10n/app_localizations.dart';
import '../utilidades/responsive.dart';
import 'imagen_portada.dart';

part 'modal_info_cancion_widgets.dart';

/// Abre el modal de información de un ítem de la app.
void mostrarInfoCancion(BuildContext context, ItemFeed item) {
  final r = Responsive(context);
  final loc = AppLocalizations.of(context);

  final duracion = item.durationMs != null
      ? _formatearDuracion(item.durationMs!)
      : '--:--';

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _HojaInfoCancion(
      r: r,
      loc: loc,
      item: item,
      duracion: duracion,
    ),
  );
}

class _HojaInfoCancion extends StatelessWidget {
  final Responsive r;
  final AppLocalizations loc;
  final ItemFeed item;
  final String duracion;

  const _HojaInfoCancion({
    required this.r,
    required this.loc,
    required this.item,
    required this.duracion,
  });

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final bg = esOscuro ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final onBg = esOscuro ? Colors.white : Colors.black;
    final hayTrack = sl<CubitCola>().state.tieneActual;
    final fondoModal = hayTrack ? bg.withValues(alpha: 0.70) : bg;

    Widget hoja = Container(
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: fondoModal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: r.spacingM),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: r.spacingXL),
              if (item.coverUrl != null && item.coverUrl!.isNotEmpty)
                ImagenPortada(
                  coverUrl: item.coverUrl,
                  ancho: r.width * 0.5,
                  alto: r.width * 0.5,
                  radioBorde: 16,
                  fallback: Container(
                    width: r.width * 0.5,
                    height: r.width * 0.5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.music_note,
                        size: 48, color: Colors.white.withValues(alpha: 0.3)),
                  ),
                ),
              SizedBox(height: r.spacingL),
              Text(item.name,
                  style: TextStyle(
                      fontSize: r.subtitleSize + 2,
                      fontWeight: FontWeight.bold,
                      color: onBg),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              SizedBox(height: r.spacingXS),
              Text(item.artists ?? '',
                  style: TextStyle(
                      fontSize: r.subtitleSize,
                      color: onBg.withValues(alpha: 0.6)),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              SizedBox(height: r.spacingL),
              _filaInfo(r, onBg, Icons.music_note, loc.setup.feedSubtitleTrack, item.name),
              if (item.albumName != null)
                _filaInfo(r, onBg, Icons.album, loc.setup.feedSubtitleAlbum, item.albumName!),
              _filaInfo(r, onBg, Icons.timer_outlined, loc.setup.trackDuration, duracion),
              if (item.type != 'track')
                _filaInfo(r, onBg, Icons.category_outlined, loc.setup.trackType, item.type),
              SizedBox(height: r.spacingL),
              _botonCompartir(context, r, onBg, item),
              SizedBox(height: r.spacingXL),
            ],
          ),
        ),
      ),
    );
    if (hayTrack) {
      hoja = ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: hoja,
        ),
      );
    }
    return hoja;
  }

}