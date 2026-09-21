// ─────────────────────────────────────────────────────────────
// splash_estado.dart — Estado del bloc de splash: estatus de
// conexión con el backend (cargando/conectado/error). El splash
// navega a /home o /setup según este estado.
//
// No guarda texto: el aviso de error lo pone la vista con l10n
// (splash.backendNotResponding), así sigue el idioma activo.
// Se conecta con: splash_bloc.dart (estado del bloc) + página.
// Parte del flujo: splash (chequeo del backend al arrancar).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Estatus de conexión del splash con el backend Go.
enum EstatusSplash { cargando, conectado, error }

/// Estado del bloc de splash.
class EstadoSplash extends Equatable {
  final EstatusSplash status;

  const EstadoSplash({this.status = EstatusSplash.cargando});

  @override
  List<Object?> get props => [status];
}
