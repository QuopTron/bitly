// ─────────────────────────────────────────────────────────────
// contenido_feed.dart — Contenido del feed de inicio: maneja el
// loading (esqueleto), el estado vacío y el listado con las
// tarjetas de tracks + grillas por sección, con pull-to-refresh.
// Las tarjetas viven en contenido_feed_tarjetas.dart y los estados
// vacíos en contenido_feed_estado.dart.
// Se conecta con: tarjeta_track + tarjeta_grilla + esqueleto_carga
// + huella_item + cubits (vía callbacks del padre) + l10n.
// Parte del flujo: feed de inicio (cuerpo).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/inyeccion.dart';
import '../../../core/cache/estado_descarga.dart';
import '../../../core/modelos/item_feed.dart';
import '../../../core/modelos/seccion_feed.dart';
import '../../../core/servicios/huella_item.dart';
import '../../../estado/cubit_cola.dart';
import '../../../estado/cubit_like.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/feed_titles.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/estrategia_descarga.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/esqueleto_carga.dart';
import '../../../shared/widgets/tarjeta_grilla.dart';
import '../../../shared/widgets/tarjeta_track.dart';

part 'contenido_feed_estado.dart';
part 'contenido_feed_grillas.dart';
part 'contenido_feed_tarjetas.dart';

/// Cuerpo del feed: tarjetas de tracks y grillas por sección.
class ContenidoFeed extends StatelessWidget {
  final Color onBg;
  final Color colorBrillo;
  final List<SeccionFeed> secciones;
  final bool tieneContenido;
  final bool cargando;
  final String nombreFuenteActual;
  final Set<String> idsAmados;
  final Map<String, EstadoDescarga> estadosDescarga;

  /// Huellas descargadas sin importar la fuente (source-agnostic).
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
  final VoidCallback? onRefrescar;

  const ContenidoFeed({
    super.key,
    required this.onBg,
    required this.colorBrillo,
    required this.secciones,
    required this.tieneContenido,
    required this.cargando,
    required this.nombreFuenteActual,
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
    this.onRefrescar,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    if (cargando) return const EsqueletoFeed();
    if (!tieneContenido) return _estadoVacio(context, r, onBg);

    final hijos = <Widget>[
      ..._construirTracks(this, context, r),
      ..._construirGrillas(this, context, r),
    ];

    final lista = ListView.builder(
      padding: EdgeInsets.only(
        top: r.spacingXS,
        bottom: r.spacingXS + r.val(120, 100, 150),
      ),
      itemCount: hijos.length,
      itemBuilder: (context, index) => hijos[index],
    );

    if (onRefrescar == null) return lista;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: () async {
        onRefrescar!();
        // Dar un momento al bloc para que empiece a cargar.
        await Future.delayed(const Duration(milliseconds: 300));
      },
      color: onBg.withValues(alpha: 0.7),
      backgroundColor:
          esOscuro ? ColoresApp.superficieOscura : ColoresApp.superficieClara,
      child: lista,
    );
  }
}

/// Snapshot ligero de estados de descarga para BlocSelector (con igualdad
/// de valor para no rebuildear en cada tick de progreso del poller).
class SnapshotDescargasFeed {
  final Map<String, EstadoDescarga> estados;
  final Set<String> huellas;

  const SnapshotDescargasFeed(this.estados, this.huellas);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SnapshotDescargasFeed) return false;
    if (estados.length != other.estados.length) return false;
    for (final e in estados.entries) {
      if (other.estados[e.key] != e.value) return false;
    }
    return huellas.length == other.huellas.length &&
        huellas.containsAll(other.huellas);
  }

  @override
  int get hashCode => Object.hash(estados.length, huellas.length);
}