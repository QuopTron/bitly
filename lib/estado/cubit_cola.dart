// ─────────────────────────────────────────────────────────────
// cubit_cola.dart — Cubit de la cola de reproducción: lista de
// tracks, índice actual, shuffle, repetición y reordenamiento.
// La navegación siguiente/anterior con historial vive en el part
// cola_navegacion.dart.
// Se conecta con: modelos (ItemFeed) + CubitReproductor (player).
// Parte del flujo: reproducción (cola, miniplayer, player).
// ─────────────────────────────────────────────────────────────

import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/cache/estado_cola.dart';
import '../core/modelos/item_feed.dart';

part 'cola_navegacion.dart';

class CubitCola extends Cubit<EstadoCola> with ColaNavegacion {
  CubitCola() : super(const EstadoCola());

  void reproducir(ItemFeed item) {
    _historial.clear();
    emit(state.copiarCon(tracks: [item], indiceActual: 0));
  }

  /// Siembra la cola con una lista de contexto visible empezando en [item],
  /// para que el player pueda precachear vecinos y navegar la lista.
  /// Cae a cola de un solo item cuando [item] no está en [items].
  ///
  /// El [item] tocado puede ser un objeto DIFERENTE a las entradas de [items]
  /// (las grillas reconstruyen FeedItems nuevos), así que el índice actual se
  /// busca por identidad estable (id+source), NO por igualdad de referencia.
  void reproducirConContexto(List<ItemFeed> items, ItemFeed item) {
    if (items.isEmpty) {
      reproducir(item);
      return;
    }
    _historial.clear();
    final idx = items.indexWhere(
      (t) => t.id == item.id && t.source == item.source,
    );
    emit(state.copiarCon(
      tracks: List<ItemFeed>.from(items),
      indiceActual: idx >= 0 ? idx : 0,
    ));
  }

  void reproducirLista(List<ItemFeed> items, {int indiceInicio = 0}) {
    if (items.isEmpty) return;
    _historial.clear();
    emit(state.copiarCon(
      tracks: items,
      indiceActual: indiceInicio.clamp(0, items.length - 1),
    ));
  }

  void agregarSiguiente(ItemFeed item) {
    final tracks = List<ItemFeed>.from(state.tracks);
    final insertarEn = state.tieneActual ? state.indiceActual + 1 : tracks.length;
    tracks.insert(insertarEn, item);
    final idx = state.indiceActual >= insertarEn ? state.indiceActual + 1 : state.indiceActual;
    emit(state.copiarCon(tracks: tracks, indiceActual: idx >= 0 ? idx : 0));
  }

  void agregarAlFinal(ItemFeed item) {
    final tracks = List<ItemFeed>.from(state.tracks)..add(item);
    emit(state.copiarCon(tracks: tracks));
  }

  void eliminar(int index) {
    if (index < 0 || index >= state.tracks.length) return;
    final tracks = List<ItemFeed>.from(state.tracks)..removeAt(index);
    int nuevoIndice = state.indiceActual;
    if (index < state.indiceActual) {
      nuevoIndice--;
    } else if (index == state.indiceActual) {
      nuevoIndice = tracks.isEmpty ? -1 : nuevoIndice.clamp(0, tracks.length - 1);
    }
    emit(state.copiarCon(tracks: tracks, indiceActual: nuevoIndice));
  }

  void limpiar() {
    _historial.clear();
    emit(const EstadoCola());
  }

  void reordenar(int indiceViejo, int indiceNuevo) {
    final tracks = List<ItemFeed>.from(state.tracks);
    final item = tracks.removeAt(indiceViejo);
    tracks.insert(indiceNuevo, item);
    int indiceActual = state.indiceActual;
    if (indiceViejo == indiceActual) {
      indiceActual = indiceNuevo;
    } else if (indiceViejo < indiceActual && indiceNuevo >= indiceActual) {
      indiceActual--;
    } else if (indiceViejo > indiceActual && indiceNuevo <= indiceActual) {
      indiceActual++;
    }
    emit(state.copiarCon(tracks: tracks, indiceActual: indiceActual));
  }

  /// Añade una lista de tracks al final de la cola (para autoplay/radio).
  void agregarTracks(List<ItemFeed> items) {
    if (items.isEmpty) return;
    final tracks = List<ItemFeed>.from(state.tracks)..addAll(items);
    emit(state.copiarCon(tracks: tracks));
  }

  /// Reemplaza toda la cola con tracks nuevos (autoplay/radio cuando se acaba
  /// la cola anterior). Arranca desde el primer track.
  void reemplazarCola(List<ItemFeed> items) {
    _historial.clear();
    emit(EstadoCola(
      tracks: items,
      indiceActual: items.isNotEmpty ? 0 : -1,
      modoRepeticion: state.modoRepeticion,
      shuffle: state.shuffle,
    ));
  }
}