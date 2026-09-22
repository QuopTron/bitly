// ─────────────────────────────────────────────────────────────
// fila_track_detalle.dart — Fila de canción de los detalles (álbum,
// playlist y artista) con resolución DIFERIDA.
//
// Por qué existe: los detalles armaban la lista COMPLETA de canciones al
// abrir la pantalla y, dentro de ese mismo bucle, resolvían por cada track su
// carátula local (like + descarga), si está amado y su estado de descarga. En
// un álbum o una playlist de 100+ canciones eso es trabajo O(N) que el usuario
// paga entero aunque solo vaya a ver 8 filas — y es justo lo que se siente
// como "la app tarda en abrir" en equipos modestos.
//
// Acá esas tres resoluciones ocurren en el `build()` de la fila, es decir solo
// cuando la fila realmente se monta (visible). El bucle del detalle queda
// construyendo objetos livianos, sin tocar mapas ni disco.
//
// Se conecta con: TarjetaTrack + CubitLikes/CubitDescargas/CubitCola + los tres
// detalles. Parte del flujo: Detalle (lista de canciones).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../app/inyeccion/inyeccion.dart';
import '../../../../core/modelos/feed/item_feed.dart';
import '../../../../core/servicios/compartir/base/servicio_compartir.dart';
import '../../../../estado/cola/cubit_cola.dart';
import '../../../../estado/descargas/cubit_descargas.dart';
import '../../../../estado/like/base/cubit_like.dart';
import '../../../../shared/utilidades/descarga/estrategia_descarga.dart';
import '../../../../shared/utilidades/formato/apariencia/barras/apariencia_espacios_helper.dart';
import '../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../shared/widgets/modales/descarga/base/hoja_opciones_descarga.dart';
import '../../../../shared/widgets/tarjetas/track/base/tarjeta_track.dart';

/// Fila de canción dentro de un detalle.
///
/// [contexto] es la lista completa con la que se reproduce al tocar (para que
/// la cola quede con los hermanos de la misma sección) y [caratulaRespaldo] es
/// la portada del contenedor (álbum/playlist) cuando el track no trae una.
class FilaTrackDetalle extends StatelessWidget {
  final ItemFeed item;

  /// Lista que se carga en la cola al reproducir esta fila.
  final List<ItemFeed> contexto;

  /// Texto secundario de la fila.
  final String subtitulo;

  /// Fuente usada para la clave de descarga ('' = la del propio track).
  final String src;

  /// Portada de respaldo si el track no tiene carátula propia.
  final String? caratulaRespaldo;

  /// Fuerza el corazón encendido (sección "descargadas" del artista).
  final bool forzarAmado;

  const FilaTrackDetalle({
    super.key,
    required this.item,
    required this.contexto,
    required this.subtitulo,
    this.src = '',
    this.caratulaRespaldo,
    this.forzarAmado = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    // Resolución diferida: aquí, no en el bucle del detalle.
    final likes = sl<CubitLikes>();
    final descargas = sl<CubitDescargas>();
    final fuente = src.isNotEmpty ? src : (item.source ?? '');
    final clave = 'track_${normalizarIdTrack(item.id)}_$fuente';
    final caratula = likes.caratulaLocalPara(item) ?? caratulaRespaldo;
    final esAmado = forzarAmado || likes.estaAmado(item);
    final estado = descargas.estadoDescargaPara(clave).estado;

    return Padding(
      // El eje Y de Ajustes → Diseño escala el hueco entre canciones.
      padding: EdgeInsets.symmetric(
        vertical: r.spacingXS * 0.5 * AparienciaEspacios.espacioY(context),
      ),
      child: TarjetaTrack(
        item: item,
        titulo: item.name,
        subtitulo: subtitulo,
        coverUrl: caratula,
        esAmado: esAmado,
        readyKey: normalizarIdTrack(item.id),
        escalaTexto: 1.2,
        onLike: () => likes.alternarLike(item),
        estadoDescarga: estado,
        onDescargar: () => mostrarOpcionesDescarga(context, item, esOscuro),
        onBorrar: () => descargas.borrarDescargaTrack(item.id, fuente),
        onTap: () => sl<CubitCola>().reproducirConContexto(contexto, item),
        onCompartir: () => ServicioCompartir.instance.compartir(item),
      ),
    );
  }
}
