// ─────────────────────────────────────────────────────────────
// resultados_busqueda_grilla.dart — PART de
// resultados_busqueda.dart: sección de grilla de los resultados —
// álbumes/playlists/artistas en TarjetaGrilla con columnas
// responsivas, descarga por lote (album/playlist) y navegación al
// detalle. La lista de tracks vive en resultados_busqueda_tarjetas.
// Se conecta con: resultados_busqueda.dart (misma library) +
// tarjeta_grilla + huella_item + cubits (vía callbacks del padre).
// Parte del flujo: búsqueda (resultados → grilla).
// ─────────────────────────────────────────────────────────────

part of '../base/resultados_busqueda.dart';

/// Sección de grilla (álbumes/playlists/artistas) con título opcional, como
/// SLIVERS: `SliverGrid` no necesita `shrinkWrap` (que era justo lo que
/// obligaba a medir todos sus hijos de una) ni apagar su propio scroll.
List<Widget> _seccionGrilla(
  CuerpoResultadosBusqueda cuerpo,
  BuildContext context,
  Responsive r,
  List<ItemFeed> items, {
  Color? colorBrillo,
  Color? onBg,
  String? titulo,
}) {
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  // Con la grilla cargada de color del cover, las cards se separan menos:
  // el espacio se cierra de a poco mientras crece la intensidad.
  final nivelGrilla = EstiloHelper.cardsGrilla(context);
  final gap = r.spacingXS * (1 - 0.5 * nivelGrilla);
  // El margen lateral también se cierra con la intensidad: la grilla con
  // color del cover aprovecha casi todo el ancho.
  final padH = r.spacingS * 0.5 * (1 - nivelGrilla) + 2 * nivelGrilla;
  // Separación personalizable (Ajustes → Apariencia → Diseño). El eje X
  // mueve el hueco entre columnas Y el margen contra los bordes izq/der;
  // el eje Y, el hueco entre filas.
  final factorX = AparienciaEspacios.espacioXGrilla(context);
  final sepX = gap * factorX;
  final sepY = gap * AparienciaEspacios.espacioYGrilla(context);

  return [
    if (titulo != null)
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            r.spacingS + 4,
            r.spacingM,
            r.spacingS,
            r.spacingS,
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_open,
                size: 18,
                color: (onBg ?? ColoresApp.enSuperficie(esOscuro)).withValues(
                  alpha: 0.6,
                ),
              ),
              SizedBox(width: r.spacingS),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: r.subtitleSize + 4,
                  fontWeight: FontWeight.bold,
                  color: onBg,
                ),
              ),
            ],
          ),
        ),
      ),
    SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: padH * factorX),
      sliver: SliverLayoutBuilder(
        builder: (context, restricciones) {
          // `crossAxisExtent` es el ancho REAL del hueco de la grilla, así la
          // cuenta de columnas sigue al ancho del box y no al de la pantalla.
          final disponible = restricciones.crossAxisExtent;
          var columnas = 2;
          if (disponible > 1000) {
            columnas = 6;
          } else if (disponible > 700) {
            columnas = 4;
          } else if (disponible > 340) {
            columnas = 3;
          }
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnas,
              mainAxisSpacing: sepY,
              crossAxisSpacing: sepX,
              // Misma proporción que el grid del feed.
              childAspectRatio: 0.72,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final huella = huellaItem(item);
              final id =
                  '${item.type}_${normalizarIdTrack(item.id)}_${item.source}';
              final caratulaResuelta = context
                  .read<CubitLikes>()
                  .caratulaLocalPara(item);
              return TarjetaGrilla(
                // Línea divisoria del modo "unido" (todas menos la última).
                lineaDerecha: index % columnas != columnas - 1,
                tipo: item.type,
                titulo: item.name,
                subtitulo: item.artists ?? '',
                coverUrl: caratulaResuelta,
                escalaTexto: 1.2,
                esAmado: cuerpo.idsAmados.contains(huella),
                onLike: () => cuerpo.onAlternarLike(id, item),
                estadoDescarga:
                    cuerpo.estadosDescarga[id] ?? EstadoDescarga.ninguno,
                onDescargar:
                    (item.type == 'album' || item.type == 'playlist')
                        ? (cuerpo.onDescargaLote != null
                            ? () => cuerpo.onDescargaLote!(item)
                            : () => cuerpo.onIniciarDescarga(item))
                        : () => cuerpo.onIniciarDescarga(item),
                onBorrar:
                    (item.type == 'album' || item.type == 'playlist')
                        ? (cuerpo.onBorradoLote != null
                            ? () => cuerpo.onBorradoLote!(item)
                            : null)
                        : null,
                mostrarTerceraAccion: item.type == 'track',
                onTap:
                    item.type != 'track'
                        ? () => cuerpo.onNavegarItem(item)
                        : null,
              );
            },
          );
        },
      ),
    ),
  ];
}
