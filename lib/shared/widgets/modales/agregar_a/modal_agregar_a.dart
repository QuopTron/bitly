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
import '../../../utilidades/plataforma/insets_sistema.dart';
import '../../../utilidades/plataforma/responsive.dart';
import '../../vidrio/desenfoque_adaptativo.dart';

part 'modal_agregar_a_crear.dart';
part 'modal_agregar_a_estilo.dart';
part 'modal_agregar_a_inline.dart';
part 'modal_agregar_a_picker.dart';
part 'modal_agregar_a_widgets.dart';
part 'modal_agregar_a_hoja.dart';

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
