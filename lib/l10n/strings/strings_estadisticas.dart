// ─────────────────────────────────────────────────────────────
// strings_estadisticas.dart — Textos del bloque de estadísticas de
// escucha: resumen, sub-modal de detalle, filtros de STATS (qué /
// cuándo / orden), etiquetas de tipos y rangos, y los textos de cada
// fila (veces, minutos, última reproducción). Español primario,
// inglés secundario (se elige por el locale de la app).
// Se conecta con: app_localizations.dart (lo expone como
// `estadisticas`) + settings_estadisticas_*.
// Parte del flujo: Ajustes → Estadísticas (resumen y detalle).
// ─────────────────────────────────────────────────────────────

class StringsEstadisticas {
  final String resumenHoras;
  final String resumenTemas;
  final String resumenArtistas;
  final String resumenDescargas;

  final String detalleTitulo;
  final String detalleVacio;
  final String detalleItemsSingular;
  final String detalleItemsPlural;

  final String filtroQue;
  final String filtroCuando;
  final String filtroOrden;

  final String tipoCanciones;
  final String tipoAlbumes;
  final String tipoArtistas;
  final String tipoPlaylists;

  final String rangoHoy;
  final String rango7Dias;
  final String rango30Dias;
  final String rango1Anio;
  final String rangoTodo;

  final String ordenMasReproducidas;
  final String ordenMenosReproducidas;
  final String ordenRecientes;
  final String ordenAz;
  final String ordenZa;

  final String vecesSingular;
  final String vecesPlural;
  final String minutos;
  final String sinFecha;
  final String ultimaVez;

  const StringsEstadisticas({
    required this.resumenHoras,
    required this.resumenTemas,
    required this.resumenArtistas,
    required this.resumenDescargas,
    required this.detalleTitulo,
    required this.detalleVacio,
    required this.detalleItemsSingular,
    required this.detalleItemsPlural,
    required this.filtroQue,
    required this.filtroCuando,
    required this.filtroOrden,
    required this.tipoCanciones,
    required this.tipoAlbumes,
    required this.tipoArtistas,
    required this.tipoPlaylists,
    required this.rangoHoy,
    required this.rango7Dias,
    required this.rango30Dias,
    required this.rango1Anio,
    required this.rangoTodo,
    required this.ordenMasReproducidas,
    required this.ordenMenosReproducidas,
    required this.ordenRecientes,
    required this.ordenAz,
    required this.ordenZa,
    required this.vecesSingular,
    required this.vecesPlural,
    required this.minutos,
    required this.sinFecha,
    required this.ultimaVez,
  });

  static const es = StringsEstadisticas(
    resumenHoras: 'Horas',
    resumenTemas: 'Temas',
    resumenArtistas: 'Artistas',
    resumenDescargas: 'Descargas',
    detalleTitulo: 'Tu escucha',
    detalleVacio: 'Todavía no hay datos en este filtro.',
    detalleItemsSingular: 'ítem',
    detalleItemsPlural: 'ítems',
    filtroQue: 'Qué',
    filtroCuando: 'Cuándo',
    filtroOrden: 'Orden',
    tipoCanciones: 'Canciones',
    tipoAlbumes: 'Álbumes',
    tipoArtistas: 'Artistas',
    tipoPlaylists: 'Playlists',
    rangoHoy: 'Hoy',
    rango7Dias: '7 días',
    rango30Dias: '30 días',
    rango1Anio: '1 año',
    rangoTodo: 'Todo',
    ordenMasReproducidas: 'Más reproducidas',
    ordenMenosReproducidas: 'Menos reproducidas',
    ordenRecientes: 'Más recientes',
    ordenAz: 'A → Z',
    ordenZa: 'Z → A',
    vecesSingular: 'vez',
    vecesPlural: 'veces',
    minutos: 'min',
    sinFecha: 'sin fecha',
    ultimaVez: 'Última',
  );

  static const en = StringsEstadisticas(
    resumenHoras: 'Hours',
    resumenTemas: 'Tracks',
    resumenArtistas: 'Artists',
    resumenDescargas: 'Downloads',
    detalleTitulo: 'Your listening',
    detalleVacio: 'No data in this filter yet.',
    detalleItemsSingular: 'item',
    detalleItemsPlural: 'items',
    filtroQue: 'What',
    filtroCuando: 'When',
    filtroOrden: 'Order',
    tipoCanciones: 'Songs',
    tipoAlbumes: 'Albums',
    tipoArtistas: 'Artists',
    tipoPlaylists: 'Playlists',
    rangoHoy: 'Today',
    rango7Dias: '7 days',
    rango30Dias: '30 days',
    rango1Anio: '1 year',
    rangoTodo: 'All',
    ordenMasReproducidas: 'Most played',
    ordenMenosReproducidas: 'Least played',
    ordenRecientes: 'Most recent',
    ordenAz: 'A → Z',
    ordenZa: 'Z → A',
    vecesSingular: 'play',
    vecesPlural: 'plays',
    minutos: 'min',
    sinFecha: 'no date',
    ultimaVez: 'Last',
  );
}
