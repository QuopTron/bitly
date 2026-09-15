// ─────────────────────────────────────────────────────────────
// tarjeta_track.dart — Tarjeta de canción con carátula de fondo
// (scrim oscuro), portada, título/artista, insignia de "listo"
// (stream pre-resuelto) y acciones: like, descarga, compartir,
// info y más. Cuerpo, acciones y gesto de encolar viven en los
// parts tarjeta_track_*.dart.
// Se conecta con: reproductor + cubit_cola + responsive + l10n.
// Parte del flujo: búsqueda, feed, mi espacio (listas de tracks).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../app/inyeccion.dart';
import '../../../../core/modelos/feed/item_feed.dart';
import '../../../../core/modelos/usuario/estilo_visual.dart';
import '../../../../estado/cola/cubit_cola.dart';
import '../../../../core/modelos/usuario/perfil_rendimiento.dart';
import '../../../../core/modelos/usuario/preferencias_estilo.dart';
import '../../../../estado/reproductor/cubit_reproductor.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../tema/colores_app.dart';
import '../../../utilidades/interaccion/haptico.dart';
import '../../../utilidades/portada/paleta_portada.dart';
import '../../../utilidades/plataforma/responsive.dart';
import '../portada/imagen_portada.dart';
import '../../indicadores/indicador_descarga.dart';

part 'tarjeta_track_descarga.dart';
part 'tarjeta_track_deslizar.dart';
part 'tarjeta_track_cuerpo.dart';
part 'tarjeta_track_acciones.dart';
part 'tarjeta_track_fila.dart';
part 'tarjeta_track_color_wrapper.dart';
part 'tarjeta_track_fondo.dart';

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

  /// Id normalizado. Si el player lo marca listo (stream pre-resuelto o
  /// archivo local), se muestra una insignia en la portada.
  final String? readyKey;

  /// Color dominante del cover (modo Spotify) para teñir la tarjeta.
  final Color? colorDominante;

  /// Canción de la tarjeta; no-null habilita deslizar→derecha para encolar.
  final ItemFeed? item;

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
    this.item,
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
                  escalaTexto,
                  efectosPesados,
                  colorDominante: colorDominante,
                );

            if (spotify && colorDominante == null && coverUrl != null) {
              return _conDeslizarCola(
                this,
                context,
                r,
                _TarjetaTrackColorWrapper(
                  coverUrl: coverUrl!,
                  builder: contenido,
                ),
              );
            }
            return _conDeslizarCola(
              this,
              context,
              r,
              contenido(spotify ? colorDominante : null),
            );
          },
        );
      },
    );
  }
}
