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

import '../../../../../app/inyeccion/inyeccion.dart';
import '../../../../../core/cache/almacenes/biblioteca/base/cache_colecciones.dart';
import '../../../../../core/modelos/playlist/playlist_propia.dart';
import '../../../../../core/modelos/feed/item_feed.dart';
import '../../../../../estado/cola/cubit_cola.dart';
import '../../../../../estado/like/base/cubit_like.dart';
import '../../../../../core/servicios/playlist/editor/editor_playlist.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../tema/colores_app.dart';
import '../../../../utilidades/modales/mostrar_modal.dart';
import '../../../../utilidades/plataforma/pantalla/insets_sistema.dart';
import '../../../../utilidades/plataforma/responsive.dart';
import '../../../esqueletos/esqueleto_carga.dart';
import '../../../tarjetas/portada/imagen_portada.dart';
import '../../../vidrio/base/fondo_reactivo_portada.dart';
import '../../playlist/base/hoja_playlist.dart';

part '../picker/modal_agregar_a_crear.dart';
part 'modal_agregar_a_estilo.dart';
part '../picker/modal_agregar_a_picker.dart';
part '../picker/modal_agregar_a_picker_filas.dart';
part 'modal_agregar_a_widgets.dart';

/// Abre el modal "agregar a" para un ítem de la app.
void mostrarAgregarA(BuildContext context, ItemFeed item) {
  final r = Responsive(context);
  final loc = AppLocalizations.of(context);

  mostrarHoja<void>(
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
    return _AgregarAEstilo(
      esOscuro: esOscuro,
      onBg: onBg,
      bg: bg,
      r: r,
      loc: loc,
      item: item,
    );
  }
}
