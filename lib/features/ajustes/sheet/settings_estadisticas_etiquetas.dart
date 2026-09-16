// ─────────────────────────────────────────────────────────────
// settings_estadisticas_etiquetas.dart — PART de settings_sheet_new
// .dart: nombres LOCALIZADOS de los filtros de estadísticas y el
// encabezado del sub-modal de detalle.
//
// Los enums de filtro_escucha.dart solo llevan la lógica; el idioma sale
// de AppLocalizations (`estadisticas.*`), así el detalle se lee en el
// idioma de la app y no en español fijo.
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_estadisticas_detalle_filtros.dart (usa las etiquetas).
// Parte del flujo: Ajustes → Estadísticas → detalle.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Nombre localizado de un tipo de contenido.
String _etiquetaTipo(AppLocalizations loc, TipoEscucha t) => switch (t) {
      TipoEscucha.canciones => loc.estadisticas.tipoCanciones,
      TipoEscucha.albumes => loc.estadisticas.tipoAlbumes,
      TipoEscucha.artistas => loc.estadisticas.tipoArtistas,
      TipoEscucha.playlists => loc.estadisticas.tipoPlaylists,
    };

/// Nombre localizado de un rango temporal.
String _etiquetaRango(AppLocalizations loc, RangoEscucha rg) => switch (rg) {
      RangoEscucha.hoy => loc.estadisticas.rangoHoy,
      RangoEscucha.sieteDias => loc.estadisticas.rango7Dias,
      RangoEscucha.treintaDias => loc.estadisticas.rango30Dias,
      RangoEscucha.unAnio => loc.estadisticas.rango1Anio,
      RangoEscucha.todo => loc.estadisticas.rangoTodo,
    };

/// Nombre localizado de un orden.
String _etiquetaOrden(AppLocalizations loc, OrdenEscucha o) => switch (o) {
      OrdenEscucha.masReproducidas => loc.estadisticas.ordenMasReproducidas,
      OrdenEscucha.menosReproducidas =>
        loc.estadisticas.ordenMenosReproducidas,
      OrdenEscucha.recientes => loc.estadisticas.ordenRecientes,
      OrdenEscucha.az => loc.estadisticas.ordenAz,
      OrdenEscucha.za => loc.estadisticas.ordenZa,
    };

/// Encabezado compacto: título, cuántos ítems entran y el tiempo total.
class _EncabezadoDetalle extends StatelessWidget {
  final int minutos;
  final int items;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _EncabezadoDetalle({
    required this.minutos,
    required this.items,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context).estadisticas;
    final tiempo = textoMinutos(minutos, unidadMin: s.minutos);
    final cuantos = items == 1 ? s.detalleItemsSingular : s.detalleItemsPlural;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingM),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(r.spacingXS),
            decoration: BoxDecoration(
              color: glowColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.insights_rounded,
              color: glowColor,
              size: r.footerSize + 2,
            ),
          ),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.detalleTitulo,
                  style: TextStyle(
                    fontSize: r.footerSize + 2,
                    fontWeight: FontWeight.w700,
                    color: onBg,
                  ),
                ),
                Text(
                  // Cuenta lo que se está viendo, no un total abstracto.
                  [
                    '$items $cuantos',
                    if (tiempo.isNotEmpty) tiempo,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.footerSize - 1,
                    color: onBg.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
