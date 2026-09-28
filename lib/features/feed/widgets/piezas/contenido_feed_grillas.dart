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

part of '../base/contenido_feed.dart';

/// Grillas por sección (álbumes/playlists/artistas) con cabecera, como
/// SLIVERS: cada celda se construye cuando entra en pantalla.
List<Widget> _sliversGrillas(
  ContenidoFeed c,
  BuildContext context,
  Responsive r,
) {
  final slivers = <Widget>[];
  for (final s in c.secciones) {
    final items = s.items.where((i) => i.type != 'track').toList();
    if (items.isEmpty) continue;
    slivers.add(
      SliverToBoxAdapter(
        child: _cabeceraSeccion(
          context,
          titulo: localizeFeedTitle(AppLocalizations.of(context), s.title),
          colorBrillo: c.colorBrillo,
          icono:
              s.items.firstOrNull?.type == 'album'
                  ? Icons.album
                  : Icons.queue_music,
        ),
      ),
    );
    slivers.add(_grillaSliver(c, context, r, items));
    // El hueco ENTRE grids también sigue el eje Y de Ajustes → Diseño.
    slivers.add(
      SliverToBoxAdapter(
        child: SizedBox(
          height: r.spacingM * AparienciaEspacios.espacioY(context),
        ),
      ),
    );
  }
  return slivers;
}

/// Grilla responsiva de ítems no-track (2/3/4/6 columnas según ancho),
/// como SLIVER: `SliverGrid` no necesita `shrinkWrap` (que era justamente lo
/// que obligaba a medir todos sus hijos de una) ni un scroll propio apagado.
///
/// El ancho disponible se lee de `SliverLayoutBuilder` (`crossAxisExtent`), que
/// es el ancho REAL del hueco de la grilla — así en PC la cuenta de columnas
/// sigue al ancho del box y no al de la pantalla.
Widget _grillaSliver(
  ContenidoFeed c,
  BuildContext context,
  Responsive r,
  List<ItemFeed> items,
) {
  // Con la grilla cargada de color, las cards se separan menos: el espacio se
  // cierra de a poco mientras crece la intensidad. Se mide con `TinteVista`
  // para que la grilla y sus cards usen la MISMA (una paleta de esta vista
  // tiene piso: sin esto la grilla quedaría con el aire de "sin color").
  final nivelGrilla = TinteVista.nivelDeGrilla(context);
  final gap = r.spacingXS * (1 - 0.5 * nivelGrilla);
  // El margen lateral también se cierra con la intensidad: la grilla con
  // color del cover aprovecha casi todo el ancho.
  final padH = r.spacingS * 0.5 * (1 - nivelGrilla) + 2 * nivelGrilla;
  // Separación personalizable por el usuario (Ajustes → Apariencia → Diseño).
  final factorX = AparienciaEspacios.espacioXGrilla(context);
  final sepX = gap * factorX;
  final sepY = gap * AparienciaEspacios.espacioYGrilla(context);

  return SliverPadding(
    padding: EdgeInsets.symmetric(horizontal: padH * factorX),
    sliver: SliverLayoutBuilder(
      builder: (context, restricciones) {
        // La cuenta vive en `columnasDeGrilla` (una sola vez para las tres
        // grillas) y respeta el tope de columnas de ESTA vista.
        final columnas = columnasDeGrilla(
          context,
          restricciones.crossAxisExtent,
        );
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnas,
            mainAxisSpacing: sepY,
            crossAxisSpacing: sepX,
            childAspectRatio: 0.72,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final huella = huellaItem(item);
            final id =
                '${item.type}_${normalizarIdTrack(item.id)}_${item.source}';
            final caratulaResuelta = context
                .read<CubitLikes>()
                .caratulaLocalPara(item);
            return TarjetaGrilla(
              // Línea divisoria del modo "unido": en todas las columnas
              // menos la última (así no marca el borde externo).
              lineaDerecha: i % columnas != columnas - 1,
              tipo: item.type,
              titulo: item.name,
              subtitulo: item.artists ?? '',
              coverUrl: caratulaResuelta,
              escalaTexto: 1.2,
              esAmado: c.idsAmados.contains(huella),
              onLike: () => c.onAlternarLike(id, item),
              estadoDescarga: c.estadosDescarga[id] ?? EstadoDescarga.ninguno,
              onDescargar:
                  (item.type == 'album' || item.type == 'playlist')
                      ? (c.onDescargaLote != null
                          ? () => c.onDescargaLote!(item)
                          : () => c.onIniciarDescarga(item))
                      : () => c.onIniciarDescarga(item),
              onBorrar:
                  (item.type == 'album' || item.type == 'playlist')
                      ? (c.onBorradoLote != null
                          ? () => c.onBorradoLote!(item)
                          : null)
                      : null,
              mostrarTerceraAccion: item.type == 'track',
              onTap:
                  item.type != 'track' ? () => c.onNavegarItem(item) : null,
            );
          },
        );
      },
    ),
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
        // Flexible + recorte: el título de sección lo pone el proveedor
        // ("Spotify — Novedades para vos", etc.), así que puede ser largo. Sin
        // esto el Text se lleva todo el ancho que quiera y la fila se desborda
        // (los "píxeles amarillos") al chocar con el divisor Expanded.
        Flexible(
          child: Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.subtitleSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: onBg,
            ),
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
