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

part of 'resultados_busqueda.dart';

/// Sección de grilla (álbumes/playlists/artistas) con título opcional.
Widget _seccionGrilla(
  CuerpoResultadosBusqueda cuerpo,
  BuildContext context,
  Responsive r,
  List<ItemFeed> items, {
  Color? colorBrillo,
  Color? onBg,
  String? titulo,
}) {
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  return LayoutBuilder(
    builder: (_, constraints) {
      final disponible = constraints.maxWidth - 2 * r.spacingS;
      // En pantallas anchas (escritorio) 6 columnas, en tablet 4 y en
      // móvil 3/2 — el box de PC se estira más que antes (1120px).
      final columnas =
          disponible > 1000 ? 6 : disponible > 700 ? 4 : disponible > 340 ? 3 : 2;
      final gap = r.spacingXS;
      return Column(
        children: [
          if (titulo != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  r.spacingS + 4, r.spacingM, r.spacingS, r.spacingS),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 18,
                    color: (onBg ?? ColoresApp.enSuperficie(esOscuro))
                        .withValues(alpha: 0.6),
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: r.spacingS * 0.5),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnas,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              // Misma proporción que el grid del feed.
              childAspectRatio: 0.72,
            ),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              final huella = huellaItem(item);
              final id = '${item.type}_${normalizarIdTrack(item.id)}_${item.source}';
              final caratulaResuelta =
                  context.read<CubitLikes>().caratulaLocalPara(item);
              return TarjetaGrilla(
                tipo: item.type,
                titulo: item.name,
                subtitulo: item.artists ?? '',
                coverUrl: caratulaResuelta,
                escalaTexto: 1.2,
                esAmado: cuerpo.idsAmados.contains(huella),
                onLike: () => cuerpo.onAlternarLike(id, item),
                estadoDescarga: cuerpo.estadosDescarga[id] ??
                    EstadoDescarga.ninguno,
                onDescargar: (item.type == 'album' || item.type == 'playlist')
                    ? (cuerpo.onDescargaLote != null
                        ? () => cuerpo.onDescargaLote!(item)
                        : () => cuerpo.onIniciarDescarga(item))
                    : () => cuerpo.onIniciarDescarga(item),
                onBorrar: (item.type == 'album' || item.type == 'playlist')
                    ? (cuerpo.onBorradoLote != null
                        ? () => cuerpo.onBorradoLote!(item)
                        : null)
                    : null,
                mostrarTerceraAccion: item.type == 'track',
                onTap: item.type != 'track'
                    ? () => cuerpo.onNavegarItem(item)
                    : null,
              );
            },
          ),
        ],
      );
    },
  );
}