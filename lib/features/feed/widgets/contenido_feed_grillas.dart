// ─────────────────────────────────────────────────────────────
// contenido_feed_grillas.dart — PART de contenido_feed.dart:
// grillas del feed — por sección (álbumes/playlists/artistas en
// TarjetaGrilla con columnas responsivas y descarga por lote) y la
// cabecera de sección con icono, título localizado y línea
// degradada. La lista de tracks vive en contenido_feed_tarjetas.
// Se conecta con: contenido_feed.dart (misma library) +
// tarjeta_grilla + huella_item + cubits (vía callbacks del padre)
// + feed_titles.
// Parte del flujo: feed de inicio (grillas del cuerpo).
// ─────────────────────────────────────────────────────────────

part of 'contenido_feed.dart';

/// Grillas por sección (álbumes/playlists/artistas) con cabecera.
List<Widget> _construirGrillas(
    ContenidoFeed c, BuildContext context, Responsive r) {
  return c.secciones
      .where((s) => s.items.any((i) => i.type != 'track'))
      .map((s) {
        final items = s.items.where((i) => i.type != 'track').toList();
        return Padding(
          padding: EdgeInsets.only(bottom: r.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _cabeceraSeccion(
                context,
                titulo: localizeFeedTitle(
                    AppLocalizations.of(context), s.title),
                colorBrillo: c.colorBrillo,
                icono: s.items.firstOrNull?.type == 'album'
                    ? Icons.album
                    : Icons.queue_music,
              ),
              _grillaDe(c, context, r, items),
            ],
          ),
        );
      })
      .toList();
}

/// Grilla responsiva de ítems no-track (2/3/4 columnas según ancho).
Widget _grillaDe(ContenidoFeed c, BuildContext context, Responsive r,
    List<ItemFeed> items) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final disponible = constraints.maxWidth - 2 * r.spacingS;
      // En pantallas anchas (escritorio) 6 columnas, en tablet 4 y en
      // móvil 3/2 — el box de PC se estira más que antes (1120px).
      final columnas =
          disponible > 1000 ? 6 : disponible > 700 ? 4 : disponible > 340 ? 3 : 2;
      final gap = r.spacingXS;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spacingS * 0.5),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnas,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: 0.72,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
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
              esAmado: c.idsAmados.contains(huella),
              onLike: () => c.onAlternarLike(id, item),
              estadoDescarga: c.estadosDescarga[id] ?? EstadoDescarga.ninguno,
              onDescargar: (item.type == 'album' || item.type == 'playlist')
                  ? (c.onDescargaLote != null
                      ? () => c.onDescargaLote!(item)
                      : () => c.onIniciarDescarga(item))
                  : () => c.onIniciarDescarga(item),
              onBorrar: (item.type == 'album' || item.type == 'playlist')
                  ? (c.onBorradoLote != null ? () => c.onBorradoLote!(item) : null)
                  : null,
              mostrarTerceraAccion: item.type == 'track',
              onTap: item.type != 'track'
                  ? () => c.onNavegarItem(item)
                  : null,
            );
          },
        ),
      );
    },
  );
}

/// Cabecera de sección: icono + título localizado + línea degradada.
Widget _cabeceraSeccion(
  BuildContext context, {
  required String titulo,
  required Color colorBrillo,
  required IconData icono,
}) {
  final r = Responsive(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final onBg = ColoresApp.enSuperficie(esOscuro);

  return Padding(
    padding: EdgeInsets.only(
      left: r.spacingXS,
      right: r.spacingXS,
      top: r.spacingM,
      bottom: r.spacingS,
    ),
    child: Row(
      children: [
        Icon(icono, size: r.footerSize, color: onBg.withValues(alpha: 0.6)),
        SizedBox(width: r.spacingS),
        Text(
          titulo,
          style: TextStyle(
            fontSize: r.subtitleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: onBg,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [onBg.withValues(alpha: 0.15), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}