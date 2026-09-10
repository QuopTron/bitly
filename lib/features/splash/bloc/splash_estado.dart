// ─────────────────────────────────────────────────────────────
// splash_estado.dart — Estado del bloc de splash: estatus de
// conexión con el backend (cargando/conectado/error) y mensaje de
// error opcional. El splash navega a /home o /setup según este
// estado.
// Se conecta con: splash_bloc.dart (estado del bloc) + página.
// Parte del flujo: splash (chequeo del backend al arrancar).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Estatus de conexión del splash con el backend Go.
enum EstatusSplash { cargando, conectado, error }

/// Estado del bloc de splash.
class EstadoSplash extends Equatable {
  final EstatusSplash status;
  final String? error;

  const EstadoSplash({this.status = EstatusSplash.cargando, this.error});

  EstadoSplash copiarCon({EstatusSplash? status, String? error}) =>
      EstadoSplash(status: status ?? this.status, error: error);

  @override
  List<Object?> get props => [status, error];
}