// ─────────────────────────────────────────────────────────────
// resultados_busqueda_tarjetas.dart — PART de
// resultados_busqueda.dart: tarjetas de track de los resultados —
// TarjetaTrack con like, descarga según estado, compartir, info y
// más. Expone `_tarjetaTrack` (una card, para listas lazy) y
// `_listaTracks` (map completo, para listas mixtas con cabeceras).
// El estado de descarga sale por clave de fuente o huella/ISRC.
// Se conecta con: resultados_busqueda.dart (misma library) +
// tarjeta_track + huella_item + cubits (vía callbacks del padre).
// Parte del flujo: búsqueda (resultados → tarjetas).
// ─────────────────────────────────────────────────────────────

part of 'resultados_busqueda.dart';

/// Estado de descarga de un track: usa el estado exacto por fuente si
/// existe, sino la huella source-agnostic (el mismo track descargado en
/// otra extensión se ve descargado aquí) o el match canónico por ISRC.
EstadoDescarga _estadoDescargaTrack(
  CuerpoResultadosBusqueda cuerpo,
  String huella,
  String id,
  String? isrc,
) {
  final s = cuerpo.estadosDescarga[id];
  if (s != null && s != EstadoDescarga.ninguno) return s;
  if (cuerpo.huellasDescargadas.contains(huella)) {
    return EstadoDescarga.completado;
  }
  if (isrc != null &&
      isrc.trim().isNotEmpty &&
      cuerpo.huellasDescargadas.contains(huellaIsrc(isrc))) {
    return EstadoDescarga.completado;
  }
  return EstadoDescarga.ninguno;
}

/// Todas las tarjetas de track como widgets — para listas mixtas
/// (cabeceras + cards) que no pueden usar un builder perezoso.
List<Widget> _listaTracks(
  CuerpoResultadosBusqueda cuerpo,
  BuildContext context,
  List<ItemFeed> items,
) {
  return items
      .map((item) => _tarjetaTrack(cuerpo, context, items, item))
      .toList();
}

/// Construye UNA tarjeta de track de resultados (item de lista lazy).
Widget _tarjetaTrack(
  CuerpoResultadosBusqueda cuerpo,
  BuildContext context,
  List<ItemFeed> items,
  ItemFeed item,
) {
  final huella = huellaItem(item);
  final id = '${item.type}_${normalizarIdTrack(item.id)}_${item.source}';
  void play() => sl<CubitCola>().reproducirConContexto(items, item);
  final caratulaResuelta = context.read<CubitLikes>().caratulaLocalPara(item);
  return TarjetaTrack(
    item: item,
    titulo: item.name,
    subtitulo: item.artists ?? '',
    coverUrl: caratulaResuelta,
    escalaTexto: 1.2,
    readyKey: normalizarIdTrack(item.id),
    esAmado: cuerpo.idsAmados.contains(huella),
    onLike: () => cuerpo.onAlternarLike(id, item),
    estadoDescarga: _estadoDescargaTrack(cuerpo, huella, id, item.isrc),
    onDescargar: () => cuerpo.onIniciarDescarga(item),
    onBorrar: cuerpo.onBorrarTrack != null
        ? () => cuerpo.onBorrarTrack!(item)
        : null,
    onInfo: () => cuerpo.onMostrarInfo(context, item),
    onMas: () => cuerpo.onMostrarMas(context, item),
    onTap: play,
    onCompartir: () => ServicioCompartir.instance.compartir(item),
  );
}
