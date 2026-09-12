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
import '../../core/modelos/estilo_visual.dart';
import '../../core/modelos/perfil_rendimiento.dart';
import '../../core/modelos/preferencias_estilo.dart';
import '../../estado/cubit_reproductor.dart';
import '../../l10n/app_localizations.dart';
import '../tema/colores_app.dart';
import '../utilidades/haptico.dart';
import '../utilidades/paleta_portada.dart';
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

  /// Color dominante extraído del cover. Se usa en modo Spotify para
  /// teñir el fondo y velo de la tarjeta con el color del track.
  final Color? colorDominante;

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
    this.colorDominante,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstiloVisual>(
      valueListenable: sl<ValueNotifier<EstiloVisual>>(),
      builder: (context, estilo, _) {
        return ValueListenableBuilder<PreferenciasEstilo>(
          valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
          builder: (context, prefs, _) {
            final r = Responsive(context);
            final loc = AppLocalizations.of(context);
            final esOscuro = Theme.of(context).brightness == Brightness.dark;
            final fg = Colors.white;
            final colorApagado = Colors.white.withValues(alpha: 0.7);
            final fondoFallback = ColoresApp.superficie(esOscuro);
            final colorIconoFallback = ColoresApp.enSuperficieApagado(esOscuro);
            final tamanoIcono = r.footerSize * 1.6 * escalaTexto;
            final ts = escalaTexto;
            final efectosPesados =
                sl<ValueNotifier<PerfilRendimiento>>().value.efectosPesados;

            final spotify =
                estilo == EstiloVisual.spotify && prefs.cardsCancion;

            Widget contenido(Color? colorDominante) => _cuerpoTarjetaTrack(
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
                  colorDominante: colorDominante,
                );

            if (spotify && colorDominante == null && coverUrl != null) {
              return _TarjetaTrackColorWrapper(
                coverUrl: coverUrl!,
                builder: contenido,
              );
            }
            return contenido(spotify ? colorDominante : null);
          },
        );
      },
    );
  }
}

/// Wrapper que extrae el color dominante del cover de forma asíncrona.
/// Solo se usa en modo Spotify cuando no se proporciona colorDominante.
class _TarjetaTrackColorWrapper extends StatefulWidget {
  final String coverUrl;
  final Widget Function(Color? colorDominante) builder;

  const _TarjetaTrackColorWrapper({
    required this.coverUrl,
    required this.builder,
  });

  @override
  State<_TarjetaTrackColorWrapper> createState() =>
      _TarjetaTrackColorWrapperState();
}

class _TarjetaTrackColorWrapperState extends State<_TarjetaTrackColorWrapper> {
  Color? _color;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  @override
  void didUpdateWidget(covariant _TarjetaTrackColorWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
      _extraerColor();
    }
  }

  Future<void> _extraerColor() async {
    try {
      final paleta = await paletaParaPortada(widget.coverUrl);
      if (mounted) {
        setState(() {
          _color = paleta?.dominante;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.builder(_color);
}