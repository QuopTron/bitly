// ─────────────────────────────────────────────────────────────
// splash_evento.dart — Eventos del bloc de splash: actualmente un
// solo evento (ChequearBackend) que dispara el chequeo de salud
// del backend Go al arrancar y en el botón reintentar.
// Se conecta con: splash_bloc.dart (maneja el evento).
// Parte del flujo: splash (chequeo del backend al arrancar).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Evento base del bloc de splash.
abstract class EventoSplash extends Equatable {
  const EventoSplash();

  @override
  List<Object?> get props => [];
}

/// Dispara el chequeo de salud del backend (con reintento automático).
class ChequearBackend extends EventoSplash {
  const ChequearBackend();
}