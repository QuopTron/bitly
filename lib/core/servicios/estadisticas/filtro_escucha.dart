// ─────────────────────────────────────────────────────────────
// filtro_escucha.dart — Filtros y órdenes de las estadísticas de
// escucha (rango de fechas, tipo de contenido y orden). Lógica PURA:
// recibe filas ya cargadas y devuelve la vista que corresponde.
//
// Por qué aparte de la pantalla: así el filtro se puede probar sin
// base de datos ni UI, y la pantalla solo pinta lo que le devuelven.
//
// Se conecta con: detalle_escucha.dart (arma las filas) y
// settings_estadisticas_detalle*.dart (las pinta y les pone los nombres
// localizados desde AppLocalizations).
// Parte del flujo: Ajustes → Estadísticas → detalle.
// ─────────────────────────────────────────────────────────────

/// Rango temporal del detalle. Los nombres visibles los pone la UI desde
/// AppLocalizations (`estadisticas.rango*`): acá solo vive el cálculo.
enum RangoEscucha {
  hoy,
  sieteDias,
  treintaDias,
  unAnio,
  todo;

  /// Desde cuándo cuenta este rango (null = sin límite).
  DateTime? desde(DateTime ahora) => switch (this) {
        RangoEscucha.hoy => DateTime(ahora.year, ahora.month, ahora.day),
        RangoEscucha.sieteDias => ahora.subtract(const Duration(days: 7)),
        RangoEscucha.treintaDias => ahora.subtract(const Duration(days: 30)),
        RangoEscucha.unAnio => DateTime(ahora.year - 1, ahora.month, ahora.day),
        RangoEscucha.todo => null,
      };
}

/// Cómo se ordena la lista. Las etiquetas las pone la UI
/// (`estadisticas.orden*`).
enum OrdenEscucha {
  masReproducidas,
  menosReproducidas,
  recientes,
  az,
  za,
}

/// Tipo de contenido del detalle (los mismos cubos que guarda la app).
enum TipoEscucha {
  canciones('track'),
  albumes('album'),
  artistas('artist'),
  playlists('playlist');

  /// Tipo tal como lo guarda el historial.
  final String clave;
  const TipoEscucha(this.clave);
}

/// Una fila del detalle: lo mínimo para pintarla y poder ordenarla.
class FilaEscucha {
  final String id;
  final String nombre;
  final String artista;
  final int reproducciones;
  final int minutos;
  final DateTime? ultimaVez;

  const FilaEscucha({
    required this.id,
    required this.nombre,
    this.artista = '',
    this.reproducciones = 0,
    this.minutos = 0,
    this.ultimaVez,
  });
}

/// Aplica rango + orden a [filas]. Devuelve una lista nueva.
///
/// El rango se evalúa contra la última reproducción de cada fila: una fila sin
/// fecha NO se descarta (los contadores viejos del historial no la traen y
/// perderlos sería mentir sobre lo escuchado), solo no entra en los rangos
/// cortos.
List<FilaEscucha> aplicarFiltroEscucha(
  List<FilaEscucha> filas, {
  RangoEscucha rango = RangoEscucha.todo,
  OrdenEscucha orden = OrdenEscucha.masReproducidas,
  DateTime? ahora,
}) {
  final desde = rango.desde(ahora ?? DateTime.now());
  final visibles = desde == null
      ? List<FilaEscucha>.from(filas)
      : filas
          .where((f) => f.ultimaVez == null || !f.ultimaVez!.isBefore(desde))
          .toList();

  int porNombre(FilaEscucha a, FilaEscucha b) => a.nombre
      .toLowerCase()
      .compareTo(b.nombre.toLowerCase());

  switch (orden) {
    case OrdenEscucha.masReproducidas:
      visibles.sort((a, b) => b.reproducciones.compareTo(a.reproducciones));
    case OrdenEscucha.menosReproducidas:
      visibles.sort((a, b) => a.reproducciones.compareTo(b.reproducciones));
    case OrdenEscucha.recientes:
      visibles.sort((a, b) => (b.ultimaVez ?? DateTime(0))
          .compareTo(a.ultimaVez ?? DateTime(0)));
    case OrdenEscucha.az:
      visibles.sort(porNombre);
    case OrdenEscucha.za:
      visibles.sort((a, b) => porNombre(b, a));
  }
  return visibles;
}

/// Tiempo total (en minutos) de las filas visibles.
int minutosDeFilas(List<FilaEscucha> filas) =>
    filas.fold(0, (total, f) => total + f.minutos);
