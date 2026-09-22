// ─────────────────────────────────────────────────────────────
// resultados_busqueda_stream.dart — Resultado de un poll de
// búsqueda en streaming: ítems acumulados, flag de fin y generación.
// Se conecta con: backend_go (RPC searchStream/getSearchStreamResults).
// Parte del flujo: búsqueda incremental (los proveedores corren en
// paralelo y los resultados llegan de a poco).
// ─────────────────────────────────────────────────────────────

import '../../../modelos/feed/item_feed.dart';

/// Resultado acumulado de una búsqueda en streaming.
class ResultadosBusquedaStream {
  final List<ItemFeed> items;

  /// true cuando la búsqueda terminó (todos los proveedores acabaron
  /// o expiró el tiempo).
  final bool done;

  /// Coincide con la generación devuelta por searchStreaming — si cambia,
  /// los resultados pertenecen a una búsqueda reemplazada y se descartan.
  final int generation;

  /// true cuando ESTE poll no llegó al backend (RPC del puente caído o
  /// respuesta ilegible). No es "sin resultados": la búsqueda sigue viva en
  /// Go, así que el llamador debe tolerarlo y volver a sondear en vez de
  /// abandonar lo que ya llegó.
  final bool fallo;

  /// Fuentes a las que el backend NO pudo preguntar (error de sesión/
  /// transporte, cooldown o techo de tiempo vencido). Son las que permiten no
  /// mentir: con [items] vacío y [fuentesOk] en 0, el vacío NO es "sin
  /// resultados", es que nadie llegó a responder.
  final List<String> fallidas;

  /// Fuentes que sí respondieron — aunque contestaran "no tengo nada".
  final int fuentesOk;

  const ResultadosBusquedaStream({
    required this.items,
    required this.done,
    required this.generation,
    this.fallo = false,
    this.fallidas = const [],
    this.fuentesOk = 0,
  });

  /// ¿La búsqueda terminó sin resultados porque NINGUNA fuente pudo responder?
  /// En ese caso corresponde un error (reintentable), no "sin resultados".
  bool get vacioPorFallo =>
      items.isEmpty && fuentesOk == 0 && fallidas.isNotEmpty;
}
