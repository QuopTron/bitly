// ─────────────────────────────────────────────────────────────
// contenido_mi_espacio_grilla_item.dart — PART de contenido_mi_espacio
// .dart: la tarjeta de una celda de la grilla — estado de like
// normalizado, carátula resuelta, insignia de origen, estado de
// descarga del lote y los callbacks de descargar/borrar/reintentar/
// exportar según el tipo de ítem.
// Se conecta con: contenido_mi_espacio.dart (misma library) +
// tarjeta_grilla + estrategia_descarga.
// Parte del flujo: Home → Mi Espacio → grilla por pestaña.
// ─────────────────────────────────────────────────────────────

part of 'contenido_mi_espacio.dart';

/// Tarjeta de una celda de la grilla de Mi Espacio.
Widget _tarjetaDeItem(
  ContenidoMiEspacio c,
  BuildContext context,
  String tipo,
  Item item,
) {
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
}
