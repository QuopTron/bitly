// ─────────────────────────────────────────────────────────────
// resultados_busqueda.dart — Cuerpo de los resultados de búsqueda:
// maneja loading (esqueleto), error, "sin resultados" y el listado
// agrupado (por categoría, por fuente o categoría única). Los
// states vacíos viven en resultados_busqueda_estados.dart, las
// vistas agrupadas en resultados_busqueda_vistas.dart, las
// cabeceras en resultados_busqueda_secciones.dart y las tarjetas
// en resultados_busqueda_tarjetas.dart.
// Se conecta con: tarjeta_track + tarjeta_grilla + esqueleto +
// cubits (vía callbacks del padre) + share_plus.
// Parte del flujo: búsqueda (resultados).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/inyeccion.dart';
import '../../../core/cache/estado_descarga.dart';
import '../../../core/modelos/item_feed.dart';
import '../../../core/servicios/huella_item.dart';
import '../../../estado/cubit_cola.dart';
import '../../../estado/cubit_like.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/constantes/constantes_fuente.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/estrategia_descarga.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/esqueleto_busqueda.dart';
import '../../../shared/widgets/tarjeta_grilla.dart';
import '../../../shared/widgets/tarjeta_track.dart';

part 'resultados_busqueda_estados.dart';
part 'resultados_busqueda_grilla.dart';
part 'resultados_busqueda_secciones.dart';
part 'resultados_busqueda_tarjetas.dart';
part 'resultados_busqueda_vistas.dart';

/// Cuerpo de resultados de la búsqueda.
class CuerpoResultadosBusqueda extends StatelessWidget {
  final String? tipoSeleccionado;

  /// Fuente activa; vacía = "Todas" (agrupa por extensión).
  final String fuenteSeleccionada;
  final List<ItemFeed> resultados;
  final bool cargando;
  final bool haBuscado;
  final String? error;
  final Set<String> idsAmados;
  final Map<String, EstadoDescarga> estadosDescarga;
  final Set<String> huellasDescargadas;

  final void Function(String id, [ItemFeed? item]) onAlternarLike;
  final void Function(ItemFeed item) onIniciarDescarga;
  final void Function(ItemFeed item)? onBorrarTrack;
  final void Function(ItemFeed item)? onDescargaLote;
  final void Function(ItemFeed item)? onBorradoLote;
  final void Function(ItemFeed item)? onExportarPlaylist;
  final void Function(BuildContext context, ItemFeed item) onMostrarInfo;
  final void Function(BuildContext context, ItemFeed item) onMostrarMas;
  final void Function(ItemFeed item) onNavegarItem;

  const CuerpoResultadosBusqueda({
    super.key,
    required this.tipoSeleccionado,
    required this.fuenteSeleccionada,
    required this.resultados,
    required this.cargando,
    required this.haBuscado,
    this.error,
    required this.idsAmados,
    required this.estadosDescarga,
    this.huellasDescargadas = const {},
    required this.onAlternarLike,
    required this.onIniciarDescarga,
    this.onBorrarTrack,
    this.onDescargaLote,
    this.onBorradoLote,
    this.onExportarPlaylist,
    required this.onMostrarInfo,
    required this.onMostrarMas,
    required this.onNavegarItem,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(esOscuro);
    final colorBrillo =
        esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

    if (cargando) {
      return EsqueletoBusqueda(tipoSeleccionado: tipoSeleccionado);
    }
    if (error != null) {
      return _estadoError(r, error!);
    }
    if (resultados.isEmpty && haBuscado) {
      return _estadoSinResultados(loc, r, onBg);
    }

    // Sin chip activo: agrupa por categoría, cada una con su cabecera.
    if (tipoSeleccionado == null) {
      return _vistaAgrupadaPorCategoria(
        this,
        context,
        r,
        colorBrillo,
        onBg,
        loc,
      );
    }

    // Fuente "Todas": agrupa por extensión, cada una con su cabecera.
    if (fuenteSeleccionada.isEmpty) {
      return _vistaAgrupadaPorFuente(
        this,
        context,
        r,
        colorBrillo,
        onBg,
        loc,
      );
    }

    // Categoría única activa: solo esa.
    final items = resultados
        .where((it) => _categoriaDe(it.type) == tipoSeleccionado)
        .toList();
    if (items.isEmpty && haBuscado) {
      return _centroSinResultados(loc, r, onBg);
    }
    if (tipoSeleccionado == 'tracks') {
      return ListView(
        padding: EdgeInsets.only(
          top: r.spacingS,
          bottom: r.spacingS + r.val(120, 100, 150),
        ),
        children: _listaTracks(this, context, r, items),
      );
    }
    return _grillaUnica(this, context, r, colorBrillo, onBg, loc, items);
  }
}