// ─────────────────────────────────────────────────────────────
// contenido_mi_espacio.dart — Cuerpo de Mi Espacio: según la
// pestaña activa muestra la lista de canciones (TarjetaTrack) o
// la grilla de playlists/álbumes/artistas (TarjetaGrilla), con
// estados de carga/vacío. Delega en los parts: _canciones (lista
// de tracks), _grilla (grillas + botones + insignias), _vacio
// (estados vacíos) y _helpers (estado de descarga, carátulas y
// conversión Item → ItemFeed).
// Se conecta con: tarjeta_track + tarjeta_grilla + cubits (vía
// callbacks del padre) + l10n + responsive.
// Parte del flujo: Home → Mi Espacio (cuerpo de cada pestaña).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/inyeccion.dart';
import '../../core/cache/estado_descarga.dart';
import '../../core/modelos/item_feed.dart';
import '../../core/servicios/huella_item.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_descargas.dart';
import '../../estado/cubit_like.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utilidades/estrategia_descarga.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/hoja_opciones_descarga.dart';
import '../../shared/widgets/modal_agregar_a.dart';
import '../../shared/widgets/modal_info_cancion.dart';
import '../../shared/widgets/tarjeta_grilla.dart';
import '../../shared/widgets/tarjeta_track.dart';
import 'modelos_item.dart';

part 'contenido_mi_espacio_canciones.dart';
part 'contenido_mi_espacio_grilla.dart';
part 'contenido_mi_espacio_helpers.dart';
part 'contenido_mi_espacio_vacio.dart';
part 'contenido_mi_espacio_widgets.dart';

/// Cuerpo de Mi Espacio (lista de canciones o grilla por pestaña).
class ContenidoMiEspacio extends StatelessWidget {
  final bool cargando;
  final List<Item> items;
  final int pestanaSeleccionada;
  final String mensajeVacio;
  final Map<String, EstadoDescarga> estadosDescarga;

  /// IDs de los ítems actualmente amados (keys de EstadoLikes).
  final Set<String> idsAmados;

  /// Huellas de tracks descargados (matching cross-extensión).
  final Set<String> huellasDescargadas;
  final Map<String, int> contadoresReproduccion;
  final void Function(Item item) onQuitarLike;
  final void Function(Item item)? onLike;
  final void Function(Item item)? onItemTap;
  final VoidCallback? onCreatePlaylist;
  final VoidCallback? onCreateDesdeAmados;
  final VoidCallback? onCreateDesdeDescargados;
  final void Function(Item item)? onDescargaLote;
  final void Function(Item item)? onBorrarLote;
  final void Function(Item item)? onReintentarLote;
  final void Function(Item item)? onExportarPlaylist;

  const ContenidoMiEspacio({
    super.key,
    required this.cargando,
    required this.items,
    required this.pestanaSeleccionada,
    required this.mensajeVacio,
    this.estadosDescarga = const {},
    required this.onQuitarLike,
    this.onLike,
    this.onItemTap,
    this.onCreatePlaylist,
    this.onCreateDesdeAmados,
    this.onCreateDesdeDescargados,
    this.onDescargaLote,
    this.onBorrarLote,
    this.onReintentarLote,
    this.onExportarPlaylist,
    this.idsAmados = const {},
    this.huellasDescargadas = const {},
    this.contadoresReproduccion = const {},
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = esOscuro ? Colors.white : Colors.black;

    if (cargando) {
      return Center(
        child: SizedBox(
          width: r.footerSize + 4,
          height: r.footerSize + 4,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: onBg.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    if (pestanaSeleccionada == 1 && items.isEmpty) {
      return _vistaVaciaPlaylists(this, context, r, onBg);
    }
    if (items.isEmpty) {
      return _vistaVacia(this, context, r, onBg);
    }

    if (pestanaSeleccionada == 0) return _vistaCanciones(this, context, r);
    return _vistaGrilla(this, context, r, _tipoGrilla(), onBg);
  }

  String _tipoGrilla() {
    switch (pestanaSeleccionada) {
      case 1:
        return 'playlist';
      case 2:
        return 'album';
      case 3:
        return 'artist';
      default:
        return '';
    }
  }

  /// Abre la hoja de opciones de descarga de un track.
  void _abrirDescarga(BuildContext context, Item item) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    mostrarOpcionesDescarga(
      context,
      _itemFeedPara(this, item),
      esOscuro,
      // Toque manual en Mi Espacio: siempre elegir calidad aunque esté
      // activada la descarga rápida global.
      ignorarDescargaRapida: true,
    );
  }
}