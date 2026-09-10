// ─────────────────────────────────────────────────────────────
// contenido_mi_espacio_grilla.dart — PART de contenido_mi_espacio
// .dart: grilla de playlists/álbumes/artistas de Mi Espacio con
// TarjetaGrilla (columnas responsivas 2/3/4), botones de crear y
// mini-acciones en la pestaña Playlists, e insignia de origen en
// la esquina. Resuelve el estado de descarga del lote por clave
// exacta o escaneo source-agnostic con validación de proveedor.
// Se conecta con: contenido_mi_espacio.dart (misma library) +
// tarjeta_grilla + estrategia_descarga + cubits (vía callbacks).
// Parte del flujo: Home → Mi Espacio → grilla por pestaña.
// ─────────────────────────────────────────────────────────────

part of 'contenido_mi_espacio.dart';

/// Grilla de ítems (playlist/álbum/artista) con acciones de lote.
Widget _vistaGrilla(
  ContenidoMiEspacio c,
  BuildContext parentCtx,
  Responsive r,
  String tipo,
  Color onBg,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final disponible = constraints.maxWidth - 2 * r.spacingS * 0.5;
      // En pantallas anchas (escritorio) 6 columnas, en tablet 4 y en
      // móvil 3/2 — el box de PC se estira más que antes (1120px).
      final columnas =
          disponible > 1000 ? 6 : disponible > 700 ? 4 : disponible > 340 ? 3 : 2;
      final gap = r.spacingXS;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          r.spacingS * 0.5,
          r.spacingS,
          r.spacingS * 0.5,
          r.spacingS + r.val(120, 100, 150),
        ),
        child: Column(
          children: [
            if (tipo == 'playlist')
              Padding(
                padding: EdgeInsets.only(bottom: r.spacingS),
                child: Row(
                  children: [
                    _botonCrear(c, context, r, onBg),
                    if (c.onCreateDesdeAmados != null) ...[
                      SizedBox(width: r.spacingXS),
                      _botonMini(
                        c,
                        context,
                        r,
                        Icons.favorite,
                        AppLocalizations.of(context).setup.likedSongs,
                        c.onCreateDesdeAmados!,
                        onBg,
                        Colors.redAccent,
                      ),
                    ],
                    if (c.onCreateDesdeDescargados != null) ...[
                      SizedBox(width: r.spacingXS),
                      _botonMini(
                        c,
                        context,
                        r,
                        Icons.download_done,
                        AppLocalizations.of(context).setup.downloaded,
                        c.onCreateDesdeDescargados!,
                        onBg,
                        const Color(0xFF4CAF50),
                      ),
                    ],
                  ],
                ),
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnas,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: 0.72,
              ),
              itemCount: c.items.length,
              itemBuilder: (context, i) {
                final item = c.items[i];
                // idsAmados usa IDs crudos (con prefijos) → normalizar.
                final esItemAmado = c.idsAmados.any(
                  (rawId) =>
                      normalizarIdTrack(rawId) ==
                      normalizarIdTrack(item.idReal),
                );
                return TarjetaGrilla(
                  key: ValueKey('${tipo}_${item.idReal}_${item.fuente}'),
                  tipo: tipo,
                  titulo: item.titulo,
                  subtitulo: item.subtitulo,
                  coverUrl: _resolverCaratula(context, c, item),
                  // Mismo textScale que Feed/Búsqueda: tarjetas del mismo
                  // tamaño en toda la app (fuera de setup).
                  escalaTexto: 1.2,
                  esAmado: esItemAmado,
                  insigniaEsquina:
                      tipo != 'artist' ? _insigniaOrigen(context, item) : null,
                  mostrarTerceraAccion:
                      tipo != 'album' && tipo != 'playlist',
                  mostrarAccionDescarga: !(item.origen == OrigenItem.propio),
                  onTap: c.onItemTap != null ? () => c.onItemTap!(item) : null,
                  onLike: () {
                    if (esItemAmado) {
                      c.onQuitarLike(item);
                    } else {
                      c.onLike?.call(item);
                    }
                  },
                  estadoDescarga: _resolverEstadoDescarga(
                    c.estadosDescarga,
                    tipo,
                    item,
                  ),
                  contadorReproducciones:
                      c.contadoresReproduccion[item.idReal] ?? 0,
                  onDescargar:
                      (tipo == 'album' || tipo == 'playlist')
                          ? (c.onDescargaLote != null
                                ? () => c.onDescargaLote!(item)
                                : () => c._abrirDescarga(context, item))
                          : null,
                  onBorrar:
                      (tipo == 'album' || tipo == 'playlist')
                          ? (c.onBorrarLote != null
                                ? () => c.onBorrarLote!(item)
                                : null)
                          : null,
                  onReintentar:
                      (tipo == 'album' || tipo == 'playlist')
                          ? (c.onReintentarLote != null
                                ? () => c.onReintentarLote!(item)
                                : null)
                          : null,
                  onExportar:
                      (tipo == 'playlist' || tipo == 'album') &&
                              c.onExportarPlaylist != null
                          ? () => c.onExportarPlaylist!(item)
                          : null,
                );
              },
            ),
          ],
        ),
      );
    },
  );
}