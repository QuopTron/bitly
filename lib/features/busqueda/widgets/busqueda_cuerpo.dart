// ─────────────────────────────────────────────────────────────
// busqueda_cuerpo.dart — Cuerpo compartido de la búsqueda: monta
// los BlocSelectors de like (huellas amadas) y descargas (estados
// + huellas) y decide entre resultados, recientes o la vista de
// pegar URL. Compartido por las variantes móvil y escritorio para
// no duplicar la lógica de selección.
// Se conecta con: cubit_like + cubit_descargas + resultados_
// busqueda + busqueda_recientes + busqueda_pegar_url.
// Parte del flujo: búsqueda (cuerpo de la vista).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cache/estado_descarga.dart';
import '../../../core/cache/estado_like.dart';
import '../../../core/modelos/item_feed.dart';
import '../../../estado/cubit_descargas.dart';
import '../../../estado/cubit_like.dart';
import 'resultados_busqueda.dart';
import 'busqueda_pegar_url.dart';
import 'busqueda_recientes.dart';

/// Cuerpo de la búsqueda: resultados, recientes o vista inicial.
class CuerpoBusqueda extends StatelessWidget {
  final String? tipoSeleccionado;
  final String fuenteSeleccionada;
  final List<ItemFeed> resultados;
  final bool cargando;
  final bool haBuscado;
  final String? error;
  final bool mostrarResultados;
  final bool mostrarRecientes;
  final List<String> busquedasRecientes;

  final void Function(String id, [ItemFeed? item]) onAlternarLike;
  final void Function(ItemFeed item) onIniciarDescarga;
  final void Function(ItemFeed item)? onBorrarTrack;
  final void Function(ItemFeed item)? onDescargaLote;
  final void Function(ItemFeed item)? onBorradoLote;
  final void Function(ItemFeed item)? onExportarPlaylist;
  final void Function(BuildContext context, ItemFeed item) onMostrarInfo;
  final void Function(BuildContext context, ItemFeed item) onMostrarMas;
  final void Function(ItemFeed item)? onNavegarItem;
  final ValueChanged<String> onBusquedaTocada;
  final VoidCallback onLimpiarRecientes;
  final ValueChanged<String> onQuitarReciente;

  const CuerpoBusqueda({
    super.key,
    required this.tipoSeleccionado,
    required this.fuenteSeleccionada,
    required this.resultados,
    required this.cargando,
    required this.haBuscado,
    this.error,
    required this.mostrarResultados,
    required this.mostrarRecientes,
    required this.busquedasRecientes,
    required this.onAlternarLike,
    required this.onIniciarDescarga,
    this.onBorrarTrack,
    this.onDescargaLote,
    this.onBorradoLote,
    this.onExportarPlaylist,
    required this.onMostrarInfo,
    required this.onMostrarMas,
    this.onNavegarItem,
    required this.onBusquedaTocada,
    required this.onLimpiarRecientes,
    required this.onQuitarReciente,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CubitLikes, EstadoLikes, Set<String>>(
      selector: (estado) => estado.huellasAmadas,
      builder: (context, idsAmados) {
        return BlocSelector<CubitDescargas, EstadoCubitDescargas,
            SnapshotDescargasBusqueda>(
          selector: (dl) => SnapshotDescargasBusqueda(
            dl.descargas.map((k, v) => MapEntry(k, v.estado)),
            dl.huellasDescargadas,
          ),
          builder: (context, snap) {
            if (mostrarResultados) {
              return CuerpoResultadosBusqueda(
                tipoSeleccionado: tipoSeleccionado,
                fuenteSeleccionada: fuenteSeleccionada,
                resultados: resultados,
                cargando: cargando,
                haBuscado: haBuscado,
                error: error,
                idsAmados: idsAmados,
                estadosDescarga: snap.estados,
                huellasDescargadas: snap.huellas,
                onAlternarLike: onAlternarLike,
                onIniciarDescarga: onIniciarDescarga,
                onBorrarTrack: onBorrarTrack,
                onDescargaLote: onDescargaLote,
                onBorradoLote: onBorradoLote,
                onExportarPlaylist: onExportarPlaylist,
                onMostrarInfo: onMostrarInfo,
                onMostrarMas: onMostrarMas,
                onNavegarItem: onNavegarItem ??
                    (_) {},
              );
            }
            if (mostrarRecientes) {
              return ListaBusquedasRecientes(
                busquedas: busquedasRecientes,
                onBusquedaTocada: onBusquedaTocada,
                onLimpiarTodas: onLimpiarRecientes,
                onQuitar: onQuitarReciente,
              );
            }
            return const VistaPegarUrl();
          },
        );
      },
    );
  }
}