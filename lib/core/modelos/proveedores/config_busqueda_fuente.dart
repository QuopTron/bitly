// ─────────────────────────────────────────────────────────────
// config_busqueda_fuente.dart — Configuración de búsqueda por
// fuente: burbujas de filtro y ratio de miniatura que declara cada
// extensión en su manifest (searchBehavior).
// Se conecta con: backend_go (RPC getSearchConfig).
// Parte del flujo: búsqueda — renderiza las burbujas de categoría.
// ─────────────────────────────────────────────────────────────

/// Burbuja de categoría de búsqueda declarada por una fuente (searchBehavior).
class ConfigFiltroBusqueda {
  final String id;
  final String label;
  final String icon;

  const ConfigFiltroBusqueda({
    required this.id,
    required this.label,
    this.icon = '',
  });

  factory ConfigFiltroBusqueda.desdeJson(Map<String, dynamic> json) {
    return ConfigFiltroBusqueda(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
    );
  }
}

/// Configuración de búsqueda por fuente: burbujas de categoría + ratio de
/// miniatura leídos del manifest de la extensión, para que la UI de búsqueda
/// renderice cada fuente como la extensión pretende.
class ConfigBusquedaFuente {
  final String source;

  /// Refleja el searchBehavior.primary del manifest — la fuente de búsqueda
  /// por defecto. Se usa para ordenar las burbujas y saber qué fuente prueba
  /// primero el backend en una búsqueda "Todas".
  final bool primary;

  final String thumbnailRatio;
  final String placeholder;
  final List<ConfigFiltroBusqueda> filters;

  const ConfigBusquedaFuente({
    required this.source,
    this.primary = false,
    this.thumbnailRatio = '',
    this.placeholder = '',
    this.filters = const [],
  });

  factory ConfigBusquedaFuente.desdeJson(Map<String, dynamic> json) {
    return ConfigBusquedaFuente(
      source: json['source'] as String? ?? '',
      primary: json['primary'] as bool? ?? false,
      thumbnailRatio: json['thumbnailRatio'] as String? ?? '',
      placeholder: json['placeholder'] as String? ?? '',
      filters: (json['filters'] as List?)
              ?.map((e) => ConfigFiltroBusqueda.desdeJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}