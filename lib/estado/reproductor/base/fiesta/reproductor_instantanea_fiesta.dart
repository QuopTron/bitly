// ─────────────────────────────────────────────────────────────
// reproductor_instantanea_fiesta.dart — PART de cubit_reproductor.dart: la
// FOTO del reproductor que necesita el modo fiesta para armar el parlante
// grande en la red local.
//
// Es una sola consulta de lectura: qué canción está puesta, por dónde sale su
// audio, en qué minuto va y si está sonando. El servicio de fiesta la pide en
// cada pregunta de los invitados, así el estado que se publica nunca queda
// viejo.
//
// Se conecta con: servicio_fiesta (la usa como fuente) + cubit_reproductor.
// Parte del flujo: reproductor → modo fiesta.
// ─────────────────────────────────────────────────────────────

part of '../../cubit_reproductor.dart';

/// La foto del reproductor para el modo fiesta.
extension InstantaneaFiestaReproductor on CubitReproductor {
  /// Qué suena, en qué minuto, si está sonando y con qué URL se abrió.
  ///
  /// La URL vacía es un caso normal (nada abierto todavía): el servicio de
  /// fiesta lo trata como "no hay nada que prestar".
  ({ItemFeed? track, String? url, Duration posicion, bool sonando})
  get instantaneaFiesta => (
    track: _queueCubit.state.actual,
    url: _ultimaUriAbierta,
    posicion: state.posicion,
    sonando: state.estaReproduciendo,
  );
}
