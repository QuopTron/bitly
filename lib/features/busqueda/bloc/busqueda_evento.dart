// ─────────────────────────────────────────────────────────────
// busqueda_evento.dart — Eventos del bloc de búsqueda: cambio de
// query/fuente/tipo, ejecución de la búsqueda (con tipo y límite
// por categoría), gestión de búsquedas recientes (agregar, quitar,
// limpiar, cargadas) y carga de la config de búsqueda por fuente.
// Se conecta con: modelos (ItemFeed, ConfigBusquedaFuente).
// Parte del flujo: búsqueda (eventos del BlocBusqueda).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import '../../../core/modelos/config_busqueda_fuente.dart';

/// Evento base del bloc de búsqueda.
abstract class EventoBusqueda extends Equatable {
  const EventoBusqueda();

  @override
  List<Object?> get props => [];
}

/// La query del campo de búsqueda cambió.
class QueryBusquedaCambiada extends EventoBusqueda {
  final String query;

  const QueryBusquedaCambiada(this.query);

  @override
  List<Object?> get props => [query];
}

/// Cambió la fuente (extensión) seleccionada.
class FuenteBusquedaCambiada extends EventoBusqueda {
  final String fuente;

  const FuenteBusquedaCambiada(this.fuente);

  @override
  List<Object?> get props => [fuente];
}

/// Cambió el tipo de filtro (tracks/albums/artists/playlists).
class TipoBusquedaCambiado extends EventoBusqueda {
  final String tipo;

  const TipoBusquedaCambiado(this.tipo);

  @override
  List<Object?> get props => [tipo];
}

/// Ejecuta la búsqueda. [tipo] es "all" para el mix combinado acotado o un id
/// de categoría (p.ej. "tracks", "songs", "albums") para re-consultar esa
/// categoría. [limite] lo ignora el mix "all" (las extensiones acotan sus
/// categorías) y se usa en las re-consultas por categoría (50 tracks / 20
/// álbumes).
class EjecutarBusqueda extends EventoBusqueda {
  final String query;
  final String fuente;
  final String tipo;
  final int limite;

  const EjecutarBusqueda({
    this.query = '',
    this.fuente = '',
    this.tipo = 'all',
    this.limite = 25,
  });

  @override
  List<Object?> get props => [query, fuente, tipo, limite];
}

/// Agrega una búsqueda a las recientes (persistida en CacheBusqueda).
class AgregarBusquedaReciente extends EventoBusqueda {
  final String query;

  const AgregarBusquedaReciente(this.query);

  @override
  List<Object?> get props => [query];
}

/// Limpia todas las búsquedas recientes.
class LimpiarBusquedasRecientes extends EventoBusqueda {
  const LimpiarBusquedasRecientes();
}

/// Quita una búsqueda reciente específica.
class QuitarBusquedaReciente extends EventoBusqueda {
  final String query;

  const QuitarBusquedaReciente(this.query);

  @override
  List<Object?> get props => [query];
}

/// Las búsquedas recientes cargaron desde el cache.
class BusquedasRecientesCargadas extends EventoBusqueda {
  final List<String> busquedas;

  const BusquedasRecientesCargadas(this.busquedas);

  @override
  List<Object?> get props => [busquedas];
}

/// Limpia la búsqueda actual (resultados + query + flags).
class LimpiarBusqueda extends EventoBusqueda {
  const LimpiarBusqueda();
}

/// La config de búsqueda por fuente se cargó desde el backend.
class ConfigBusquedaCargada extends EventoBusqueda {
  final Map<String, ConfigBusquedaFuente> config;

  const ConfigBusquedaCargada(this.config);

  @override
  List<Object?> get props => [config];
}