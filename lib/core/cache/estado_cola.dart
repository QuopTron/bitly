// ─────────────────────────────────────────────────────────────
// estado_cola.dart — Estado de la cola de reproducción: lista de
// tracks, índice actual, modo de repetición y shuffle.
// Se conecta con: QueueCubit (estado del cubit).
// Parte del flujo: reproducción (cola, miniplayer, player).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import '../modelos/item_feed.dart';

enum ModoRepeticion { ninguno, uno, todos }

class EstadoCola extends Equatable {
  final List<ItemFeed> tracks;
  final int indiceActual;
  final ModoRepeticion modoRepeticion;
  final bool shuffle;

  bool get tieneActual => indiceActual >= 0 && indiceActual < tracks.length;

  ItemFeed? get actual => tieneActual ? tracks[indiceActual] : null;

  const EstadoCola({
    this.tracks = const [],
    this.indiceActual = -1,
    this.modoRepeticion = ModoRepeticion.ninguno,
    this.shuffle = false,
  });

  EstadoCola copiarCon({
    List<ItemFeed>? tracks,
    int? indiceActual,
    ModoRepeticion? modoRepeticion,
    bool? shuffle,
  }) =>
      EstadoCola(
        tracks: tracks ?? this.tracks,
        indiceActual: indiceActual ?? this.indiceActual,
        modoRepeticion: modoRepeticion ?? this.modoRepeticion,
        shuffle: shuffle ?? this.shuffle,
      );

  @override
  List<Object?> get props => [tracks, indiceActual, modoRepeticion, shuffle];
}