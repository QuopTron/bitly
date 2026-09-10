// ─────────────────────────────────────────────────────────────
// tarjeta_track.dart — Tarjeta de canción con carátula de fondo
// (scrim oscuro), portada en miniatura, título/artista, insignia
// de "listo" (stream pre-resuelto) y cluster de acciones: like,
// descarga (según estado), compartir, info y más. El cuerpo vive
// en tarjeta_track_cuerpo.dart, la insignia + acciones en
// tarjeta_track_acciones.dart y los helpers de descarga en
// tarjeta_track_descarga.dart.
// Se conecta con: reproductor (tracksListos) + imagen_portada +
// indicador_descarga + colores_app + responsive + l10n + haptico.
// Parte del flujo: búsqueda, feed, mi espacio (listas de tracks).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../app/inyeccion.dart';
import '../../core/modelos/perfil_rendimiento.dart';
import '../../estado/cubit_reproductor.dart';
import '../../l10n/app_localizations.dart';
import '../tema/colores_app.dart';
import '../utilidades/haptico.dart';
import '../utilidades/responsive.dart';
import 'imagen_portada.dart';
import 'indicador_descarga.dart';

part 'tarjeta_track_descarga.dart';
part 'tarjeta_track_cuerpo.dart';
part 'tarjeta_track_acciones.dart';
part 'tarjeta_track_fila.dart';

/// Tarjeta de canción reutilizada en todas las listas de tracks.
class TarjetaTrack extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String? coverUrl;
  final VoidCallback? onTap;
  final bool esAmado;
  final VoidCallback? onLike;
  final EstadoDescarga estadoDescarga;
  final VoidCallback? onDescargar;
  final VoidCallback? onPausar;
  final VoidCallback? onBorrar;
  final VoidCallback? onInfo;
  final VoidCallback? onMas;
  final VoidCallback? onCompartir;
  final VoidCallback? onEditarEtiquetas;
  final bool mostrarAnimacionBorrar;
  final bool mostrarAcciones;
  final bool accionesHabilitadas;
  final double escalaTexto;

  /// Id normalizado del track. Cuando el player lo marca como listo para
  /// reproducir al instante (stream pre-resuelto o archivo local), se muestra
  /// una insignia pequeña en la portada: arranca sin espera.
  final String? readyKey;

  const TarjetaTrack({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.coverUrl,
    this.onTap,
    this.esAmado = false,
    this.onLike,
    this.estadoDescarga = EstadoDescarga.ninguno,
    this.onDescargar,
    this.onPausar,
    this.onBorrar,
    this.onInfo,
    this.onMas,
    this.onCompartir,
    this.onEditarEtiquetas,
    this.mostrarAnimacionBorrar = false,
    this.mostrarAcciones = true,
    this.accionesHabilitadas = true,
    this.escalaTexto = 1.0,
    this.readyKey,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    // El título, subtítulo y los iconos van sobre la portada + velo oscuro,
    // que es oscuro en AMBOS temas — así que el blanco siempre es legible.
    final fg = Colors.white;
    final colorApagado = Colors.white.withValues(alpha: 0.7);
    final fondoFallback = ColoresApp.superficie(esOscuro);
    // El icono placeholder vive DENTRO del box de portada, que conserva la
    // superficie del tema detrás → su color sigue siendo theme-aware.
    final colorIconoFallback = ColoresApp.enSuperficieApagado(esOscuro);
    final tamanoIcono = r.footerSize * 1.6 * escalaTexto;
    final ts = escalaTexto;
    final efectosPesados =
        sl<ValueNotifier<PerfilRendimiento>>().value.efectosPesados;

    return _cuerpoTarjetaTrack(
      this,
      context,
      r,
      loc,
      esOscuro,
      fg,
      colorApagado,
      fondoFallback,
      colorIconoFallback,
      tamanoIcono,
      ts,
      efectosPesados,
    );
  }
}