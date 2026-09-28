// ─────────────────────────────────────────────────────────────
// hoja_playlist.dart — Hoja inferior para CREAR o EDITAR una
// playlist: nombre, portada (foto del dispositivo o la de su primera
// canción) y sus canciones (agregar desde Me gustan / Descargadas,
// quitar una por una).
//
// Reemplaza al diálogo flotante de "crear playlist" y a la página
// fullscreen que se abría desde el selector: ahora todo pasa por una
// hoja como el resto de los modales de la app.
//
// Acá viven la entrada pública, el widget y su estado; el layout está
// en los parts (_cabecera/_cuerpo/_lista/_canciones/_portada) y la
// lógica en _acciones (cargar, agregar, quitar, portada, guardar).
// Se conecta con: editor_playlist + cubit_playlists + l10n.
// Parte del flujo: Mi Espacio / detalle → playlists (crear y editar).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../app/inyeccion/inyeccion.dart';
import '../../../../../core/cache/reproduccion/detalle/reproduccion_detalle_local.dart';
import '../../../../../core/modelos/detalle/base/detalle_track.dart';
import '../../../../../core/modelos/feed/item_feed.dart';
import '../../../../../core/servicios/playlist/editor/editor_playlist.dart';
import '../../../../../core/servicios/playlist/base/fuentes_playlist.dart';
import '../../../../../estado/cola/cubit_cola.dart';
import '../../../../../estado/playlists/cubit_playlists.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../tema/colores_app.dart';
import '../../../../utilidades/modales/mostrar_modal.dart';
import '../../../../utilidades/plataforma/pantalla/insets_sistema.dart';
import '../../../../utilidades/plataforma/responsive.dart';
import '../../../../utilidades/portada/base/caratula_util.dart';
import '../../../../utilidades/portada/base/portada_playlist.dart';
import '../../../esqueletos/esqueleto_carga.dart';
import '../../../tarjetas/portada/imagen_portada.dart';
import '../../../vidrio/base/fondo_reactivo_portada.dart';

part 'hoja_playlist_acciones.dart';
part 'hoja_playlist_cabecera.dart';
part '../lista/hoja_playlist_canciones.dart';
part 'hoja_playlist_cuerpo.dart';
part '../lista/hoja_playlist_lista.dart';
part '../portada/hoja_playlist_portada.dart';
part '../lista/hoja_playlist_vacio.dart';

/// Abre la hoja de playlist. [playlistId] null = nueva; con id = editar.
///
/// [semilla] es la canción que ya entra cargada (viene del modal "agregar a").
/// [sobreHoja] = true cuando se abre DESDE otro modal, para que su velo tape
/// la hoja de abajo.
Future<String?> mostrarHojaPlaylist(
  BuildContext context, {
  String? playlistId,
  String? nombreInicial,
  String? portadaInicial,
  ItemFeed? semilla,
  bool sobreHoja = false,
}) {
  return mostrarHoja<String>(
    context: context,
    isScrollControlled: true,
    sobreHoja: sobreHoja,
    backgroundColor: Colors.transparent,
    builder:
        (_) => _HojaPlaylist(
          playlistId: playlistId,
          nombreInicial: nombreInicial,
          portadaInicial: portadaInicial,
          semilla: semilla,
        ),
  );
}

class _HojaPlaylist extends StatefulWidget {
  final String? playlistId;
  final String? nombreInicial;
  final String? portadaInicial;
  final ItemFeed? semilla;

  const _HojaPlaylist({
    this.playlistId,
    this.nombreInicial,
    this.portadaInicial,
    this.semilla,
  });

  @override
  State<_HojaPlaylist> createState() => _HojaPlaylistState();
}

class _HojaPlaylistState extends State<_HojaPlaylist> {
  late final TextEditingController _nombre;
  final List<ItemFeed> _canciones = [];
  String? _portada;
  bool _cargando = false;
  bool _guardando = false;

  /// True mientras se leen las likeadas/descargadas de la base.
  bool _fuenteCargando = false;

  bool get esEdicion =>
      widget.playlistId != null && widget.playlistId!.isNotEmpty;

  /// Carátula que colorea el fondo: la portada elegida, la de la primera
  /// canción o la de la canción en reproducción (como el modal "agregar a").
  String? get caratulaFondo {
    final propia = _portada?.trim() ?? '';
    if (propia.isNotEmpty) return propia;
    if (_canciones.isNotEmpty) return _canciones.first.coverUrl;
    try {
      return sl<CubitCola>().state.actual?.coverUrl;
    } catch (e) {
      debugPrint('[HojaPlaylistState] $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.nombreInicial ?? '');
    _portada = widget.portadaInicial;
    if (widget.semilla != null) _canciones.add(widget.semilla!);
    if (esEdicion) _cargarExistente(this);
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  /// Repinta después de mutar campos desde los parts.
  void refrescar() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => _construirHojaPlaylist(this, context);
}
