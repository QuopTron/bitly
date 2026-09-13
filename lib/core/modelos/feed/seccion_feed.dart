// ─────────────────────────────────────────────────────────────
// seccion_feed.dart — Modelo de una sección del feed de inicio
// (título + lista de ítems de una fuente), tal como la arma Go.
// Se conecta con: backend_go (RPC getHomeFeed).
// Parte del flujo: inicio (feed del home).
// ─────────────────────────────────────────────────────────────

import 'item_feed.dart';

/// Sección del feed: un bloque con título (ej. "Canciones de moda") y
/// su lista de ítems, agrupado por fuente.
class SeccionFeed {
  final String source;
  final String displayName;
  final String title;
  final List<ItemFeed> items;

  const SeccionFeed({
    required this.source,
    this.displayName = '',
    required this.title,
    required this.items,
  });

  factory SeccionFeed.desdeJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return SeccionFeed(
      source: json['source'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      items: rawItems.map((e) => ItemFeed.desdeJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> aJson() => {
        'source': source,
        'display_name': displayName,
        'title': title,
        'items': items.map((e) => e.aJson()).toList(),
      };
}