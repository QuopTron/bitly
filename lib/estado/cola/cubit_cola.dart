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

import '../../core/cache/estado/estado_cola.dart';
import '../../core/modelos/feed/item_feed.dart';
import '../../core/servicios/utilidades/utilidades_id.dart';

part 'cola_orden_aleatorio.dart';
part 'cola_navegacion.dart';

class CubitCola extends Cubit<EstadoCola> with ColaOrdenAleatorio, ColaNavegacion {
  CubitCola() : super(const EstadoCola());

  void reproducir(ItemFeed item) {
    _historial.clear();
    _invalidarOrdenShuffle();
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
    _invalidarOrdenShuffle();
    var idx = _indiceDe(items, item);
    final tracks = List<ItemFeed>.from(items);
    // El track tocado TIENE que quedar como actual. Si el contexto no lo
    // contiene (grillas con otro id de proveedor, listas recortadas), se pone
    // primero: dejar el índice en 0 haría que sonara OTRA canción y que, al
    // terminar, el avance cayera en un lugar equivocado de la cola.
    if (idx < 0) {
      tracks.insert(0, item);
      idx = 0;
    }
    emit(state.copiarCon(tracks: tracks, indiceActual: idx));
  }

  /// Índice de [item] dentro de [items]: por identidad estable (id+source),
  /// después por id normalizado y por último por nombre+artista (la misma
  /// canción puede llegar con otro id de proveedor). Devuelve -1 si no está.
  int _indiceDe(List<ItemFeed> items, ItemFeed item) {
    final exacto = items.indexWhere(
      (t) => t.id == item.id && t.source == item.source,
    );
    if (exacto >= 0) return exacto;
    final norm = normalizarId(item.id);
    final porId = items.indexWhere((t) => normalizarId(t.id) == norm);
    if (porId >= 0) return porId;
    final nombre = item.name.trim().toLowerCase();
    if (nombre.isEmpty) return -1;
    return items.indexWhere(
      (t) =>
          t.name.trim().toLowerCase() == nombre &&
          (t.artists ?? '').trim().toLowerCase() ==
              (item.artists ?? '').trim().toLowerCase(),
    );
  }

  void reproducirLista(List<ItemFeed> items, {int indiceInicio = 0}) {
    if (items.isEmpty) return;
    _historial.clear();
    _invalidarOrdenShuffle();
    emit(state.copiarCon(
      tracks: items,
      indiceActual: indiceInicio.clamp(0, items.length - 1),
    ));
  }

  void agregarSiguiente(ItemFeed item) {
    _invalidarOrdenShuffle();
    final tracks = List<ItemFeed>.from(state.tracks);
    final insertarEn = state.tieneActual ? state.indiceActual + 1 : tracks.length;
    tracks.insert(insertarEn, item);
    final idx = state.indiceActual >= insertarEn ? state.indiceActual + 1 : state.indiceActual;
    emit(state.copiarCon(tracks: tracks, indiceActual: idx >= 0 ? idx : 0));
  }

  void agregarAlFinal(ItemFeed item) {
    _invalidarOrdenShuffle();
    final tracks = List<ItemFeed>.from(state.tracks)..add(item);
    emit(state.copiarCon(tracks: tracks));
  }

  void eliminar(int index) {
    if (index < 0 || index >= state.tracks.length) return;
    _invalidarOrdenShuffle();
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
    _invalidarOrdenShuffle();
    emit(const EstadoCola());
  }

  void reordenar(int indiceViejo, int indiceNuevo) {
    _invalidarOrdenShuffle();
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
    _invalidarOrdenShuffle();
    final tracks = List<ItemFeed>.from(state.tracks)..addAll(items);
    emit(state.copiarCon(tracks: tracks));
  }

  /// Reemplaza toda la cola con tracks nuevos (autoplay/radio cuando se acaba
  /// la cola anterior). Arranca desde el primer track.
  void reemplazarCola(List<ItemFeed> items) {
    _historial.clear();
    _invalidarOrdenShuffle();
    emit(EstadoCola(
      tracks: items,
      indiceActual: items.isNotEmpty ? 0 : -1,
      modoRepeticion: state.modoRepeticion,
      shuffle: state.shuffle,
    ));
  }
}