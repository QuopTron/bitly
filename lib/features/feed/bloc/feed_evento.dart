// ─────────────────────────────────────────────────────────────
// feed_evento.dart — Eventos del bloc de feed: cargar el feed
// (con cache + refresh del backend), descargar un ítem por id y
// cambiar la fuente activa del home feed.
// Se conecta con: modelos (SeccionFeed) — sin dependencias extra.
// Parte del flujo: feed de inicio (eventos del BlocFeed).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Evento base del bloc de feed.
abstract class EventoFeed extends Equatable {
  const EventoFeed();

  @override
  List<Object?> get props => [];
}

/// Carga el feed: restaura el cache y refresca desde el backend.
class CargarFeed extends EventoFeed {
  const CargarFeed();
}

/// Descarga un ítem por id (lo guarda Go para procesarlo luego).
class DescargarItem extends EventoFeed {
  final String itemId;

  const DescargarItem(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

/// Cambia la fuente activa del home feed.
class FuenteFeedCambiada extends EventoFeed {
  final String fuente;

  const FuenteFeedCambiada(this.fuente);

  @override
  List<Object?> get props => [fuente];
}