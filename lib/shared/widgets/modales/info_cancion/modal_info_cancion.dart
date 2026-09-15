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

import '../../../../app/inyeccion.dart';
import '../../../../core/modelos/usuario/estilo_visual.dart';
import '../../../../core/modelos/feed/item_feed.dart';
import '../../../../core/modelos/usuario/preferencias_estilo.dart';
import '../../../../estado/cola/cubit_cola.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../utilidades/portada/paleta_portada.dart';
import '../../../utilidades/plataforma/responsive.dart';
import '../../tarjetas/portada/imagen_portada.dart';

part 'modal_info_cancion_widgets.dart';
part 'modal_info_cancion_estilo.dart';
part 'info_cancion_hoja.dart';

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

    return _InfoCancionEstilo(
      esOscuro: esOscuro,
      bg: bg,
      onBg: onBg,
      hayTrack: hayTrack,
      fondoModal: fondoModal,
      r: r,
      loc: loc,
      item: item,
      duracion: duracion,
    );
  }
}
