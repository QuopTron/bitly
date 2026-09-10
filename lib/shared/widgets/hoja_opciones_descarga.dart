// ─────────────────────────────────────────────────────────────
// hoja_opciones_descarga.dart — Hoja de opciones de descarga:
// elige calidad (lossless/lossy), muestra tamaños estimados vía
// RPC a Go y descarga el track o delega el batch. Incluye la
// descarga rápida (salta la hoja) cuando el ajuste está activo.
// El State, las opciones y las piezas visuales viven en parts.
// Se conecta con: cubit_descargas + cache_ajustes + backend Go
// (estimateTrackFileSize) + estrategia_descarga + l10n.
// Parte del flujo: acciones de ítem (descargar) — feed, búsqueda,
// mi espacio, detalle.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/inyeccion.dart';
import '../../core/backend_go/contrato_backend.dart';
import '../../core/cache/cache_ajustes.dart';
import '../../core/modelos/ajustes_descarga.dart';
import '../../core/modelos/item_feed.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_descargas.dart';
import '../../l10n/app_localizations.dart';
import '../tema/colores_app.dart';
import '../utilidades/estrategia_descarga.dart';
import '../utilidades/formato_tamano.dart';
import '../utilidades/responsive.dart';
import 'contenedor_vidrio.dart';

part 'hoja_opciones_descarga_cuerpo.dart';
part 'hoja_opciones_descarga_estado.dart';
part 'hoja_opciones_descarga_extra.dart';
part 'hoja_opciones_descarga_opcion.dart';
part 'hoja_opciones_descarga_widgets.dart';

/// Abre la hoja de opciones de descarga; si la descarga rápida está
/// activada (y no se fuerza la hoja) descarga directo con los ajustes.
Future<void> mostrarOpcionesDescarga(
  BuildContext context,
  ItemFeed item,
  bool esOscuro, {
  AjustesDescarga? ajustesDescarga,
  bool ignorarDescargaRapida = false,
}) async {
  final ajustes = ajustesDescarga ??
      await sl<CacheAjustes>().getAjustesDescarga();
  if (!context.mounted) return;

  if (ajustes.descargaRapida && !ignorarDescargaRapida) {
    descargaRapidaTrack(item, ajustes);
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => HojaOpcionesDescarga(
      item: item,
      esOscuro: esOscuro,
      ajustes: ajustes,
    ),
  );
}

/// Descarga directa con los ajustes guardados (sin mostrar la hoja).
void descargaRapidaTrack(ItemFeed item, AjustesDescarga ajustes) {
  final cubit = sl<CubitDescargas>();
  final baseId = '${item.type}_${normalizarIdTrack(item.id)}_${item.source}';
  final metaComun = construirMetaTrack(
    trackId: item.id,
    trackTitle: item.name,
    artistName: item.artists ?? '',
    albumName: item.albumName ?? '',
    source: item.source ?? '',
    isrc: item.isrc ?? '',
    durationMs: item.durationMs ?? 0,
    coverUrl: item.coverUrl,
  );
  despacharDescargas(
    cubit: cubit,
    metaComun: metaComun,
    ajustes: ajustes,
    baseId: baseId,
  );
}

/// Hoja de selección de calidad de descarga.
class HojaOpcionesDescarga extends StatefulWidget {
  final ItemFeed item;
  final bool esOscuro;
  final AjustesDescarga ajustes;

  /// Cuando se define, el botón "Descargar" delega con la calidad elegida
  /// (modo batch) en vez de despachar la descarga individual.
  final ValueChanged<String>? onCalidadSeleccionada;

  const HojaOpcionesDescarga({
    super.key,
    required this.item,
    required this.esOscuro,
    required this.ajustes,
    this.onCalidadSeleccionada,
  });

  @override
  State<HojaOpcionesDescarga> createState() => _HojaOpcionesDescargaState();
}