// ─────────────────────────────────────────────────────────────
// resultados_busqueda_stream.dart — Resultado de un poll de
// búsqueda en streaming: ítems acumulados, flag de fin y generación.
// Se conecta con: backend_go (RPC searchStream/getSearchStreamResults).
// Parte del flujo: búsqueda incremental (los proveedores corren en
// paralelo y los resultados llegan de a poco).
// ─────────────────────────────────────────────────────────────

import '../modelos/item_feed.dart';

/// Resultado acumulado de una búsqueda en streaming.
class ResultadosBusquedaStream {
  final List<ItemFeed> items;

  /// true cuando la búsqueda terminó (todos los proveedores acabaron
  /// o expiró el tiempo).
  final bool done;

  /// Coincide con la generación devuelta por searchStreaming — si cambia,
  /// los resultados pertenecen a una búsqueda reemplazada y se descartan.
  final int generation;

  const ResultadosBusquedaStream({
    required this.items,
    required this.done,
    required this.generation,
  });
}