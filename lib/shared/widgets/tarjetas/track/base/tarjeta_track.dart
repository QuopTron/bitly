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

import '../../../../../app/inyeccion/inyeccion.dart';
import '../../../../../core/modelos/ajustes_acciones_rapidas.dart';
import '../../../../../core/modelos/feed/item_feed.dart';
import '../../../../../estado/cola/cubit_cola.dart';
import '../../../../../estado/descargas/cubit_descargas.dart';
import '../../../../../features/detalle/comun/base/navegador_detalle.dart';
import '../../../../../core/modelos/usuario/perfil/perfil_rendimiento.dart';
import '../../../../../core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import '../../../../../core/modelos/usuario/preferencias/preferencias_estilo.dart';
import '../../../../../estado/reproductor/cubit_reproductor.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../tema/colores_app.dart';
import '../../../../utilidades/interaccion/haptico.dart';
import '../../../../utilidades/portada/paleta/paleta_portada.dart';
import '../../../../utilidades/formato/comun/formato/estilo_helper.dart';
import '../../../../utilidades/plataforma/responsive.dart';
import '../../../../utilidades/plataforma/pantalla/efectos_app.dart';
import '../../../../utilidades/plataforma/pantalla/escala_ui.dart';
import '../../../fondos/ambiente/atenuado_por_nivel.dart';
import '../../portada/imagen_portada.dart';
import '../../../indicadores/descarga/indicador_descarga.dart';
import '../../../../utilidades/formato/apariencia/barras/apariencia_espacios_helper.dart';
import '../../../../utilidades/formato/apariencia/vistas/tinte_vista_helper.dart';

part '../acciones/tarjeta_track_descarga.dart';
part '../acciones/tarjeta_track_deslizar.dart';
part 'tarjeta_track_cuerpo.dart';
part '../acciones/tarjeta_track_acciones.dart';
part 'tarjeta_track_fila.dart';
part '../visual/tarjeta_track_color_wrapper.dart';
part '../visual/tarjeta_track_fondo.dart';

/// Radio de la card de canción, derivado del control de Redondeo de
/// Ajustes → Apariencia → Diseño. Con el valor de fábrica del control (14)
/// da los 18 px de siempre y con 0 queda **cuadrada**: así el redondeo llega
/// a 0 en TODAS las cards, no sólo en las grillas.
double _radioCardTrack(BuildContext context) =>
    AparienciaEspacios.radioCards(context) * 18 / 14;

/// Línea divisoria del modo "unido" (tipo Spotify): aparece sola cuando la
/// separación vertical llega al extremo (0) y no existe en el diseño de
/// fábrica. Se mete a cada lado el radio actual de la card, así la línea cae
/// sobre la parte RECTA de abajo y acompaña las esquinas (y con redondeo 0
/// simplemente cruza de lado a lado). Cuando está apagada no agrega ni un
/// widget de layout.
Widget _conLineaUnida(BuildContext context, Widget child) {
  final op = AparienciaEspacios.opacidadLineaYCancion(context);
  if (op <= 0.001) return child;
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      child,
      Padding(
        padding: EdgeInsets.symmetric(horizontal: _radioCardTrack(context)),
        child: Container(
          key: const ValueKey('linea-separacion'),
          // Hairline MUY sutil: se siente la separación sin que salte a la
          // vista (antes era más gruesa y con la opacidad plena quedaba
          // demasiado blanca).
          height: 0.5,
          color: ColoresApp.borde(esOscuro).withValues(alpha: op * 0.45),
        ),
      ),
    ],
  );
}

class TarjetaTrack extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String? coverUrl;
  final VoidCallback? onTap;
  final bool esAmado;
  final VoidCallback? onLike;
  final EstadoDescarga estadoDescarga;

  /// Reintento en sitio ya consumido y cuántos hay en total (0 = intento
  /// original). Con intento > 0 la tarjeta marca la descarga como "en
  /// reintento" para que el usuario entienda por qué vuelve a empezar.
  final int intentoDescarga;
  final int totalIntentosDescarga;

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

  /// Canción de la tarjeta; no-null habilita los gestos rápidos (Ajustes →
  /// Apariencia → Acciones rápidas), que de fábrica son deslizar a la
  /// derecha para encolar.
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
    this.intentoDescarga = 0,
    this.totalIntentosDescarga = 0,
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
    // Escucha TAMBIÉN la apariencia: algunas vistas (p. ej. Mi Espacio) no se
    // reconstruyen con el cambio global, así que la card repinta sola el
    // margen y la línea al mover el control (antes había que salir y volver).
    return ValueListenableBuilder<PreferenciasApariencia>(
      valueListenable: sl<ValueNotifier<PreferenciasApariencia>>(),
      builder:
          (context, _, _) => ValueListenableBuilder<PreferenciasEstilo>(
            valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
            builder: (context, prefs, _) {
              final r = Responsive(context);
              final loc = AppLocalizations.of(context);
              final esOscuro = Theme.of(context).brightness == Brightness.dark;
              final fondoFallback = ColoresApp.superficie(esOscuro);
              final colorIconoFallback = ColoresApp.enSuperficieApagado(
                esOscuro,
              );
              // El tamaño de los iconos suma la escala elegida en Ajustes →
              // Apariencia (`EscalaUi`), que es global: así el control mueve
              // TODAS las tarjetas a la vez y en vivo. La tarjeta ya escucha las
              // preferencias de apariencia, así que repinta al mover el control.
              final tamanoIcono =
                  r.footerSize * 1.6 * escalaTexto * EscalaUi.factorIconosCards;
              // Las sombras con blur son el resto caro que queda en gama baja
              // (un `MaskFilter.blur` por tarjeta y por frame). Se consulta
              // TAMBIÉN `EfectosApp`, que es el interruptor que mueve el monitor
              // de frames midiendo el equipo real: sin esto el monitor apagaba
              // los desenfoques pero cada tarjeta seguía pagando su sombra, y
              // el perfil estático (núcleos + RAM) clasifica como "hay margen"
              // a equipos con GPU floja, como un Unisoc con PowerVR.
              final efectosPesados =
                  sl<ValueNotifier<PerfilRendimiento>>().value.efectosPesados &&
                  EfectosApp.desenfoqueActivo;
              // Intensidad del color en las cards (0 = card del tema). Si ESTA
              // vista tiene una paleta del cofre puesta (Ajustes → Apariencia →
              // Vistas), manda ella y tiene un piso: elegir una paleta con el
              // estilo con cover apagado igual tiene que verse.
              final nivel = TinteVista.nivelDeCards(
                context,
                prefs.cardsCancion,
              );
              // El color que puso la vista, si puso alguno.
              final acentoVista = TinteVista.acentoDe(context);
              // El acento final: la paleta de la vista MANDA sobre el cover (si
              // el cover pudiera pisarla, elegirla no serviría de nada).
              final acento = TinteVista.acentoDeCards(context, colorDominante);

              // Las letras se calculan CON el color del cover ya resuelto: con
              // una carátula clara al 100% la card queda clara y el blanco de
              // fábrica desaparecía sobre ella.
              //
              // El fondo que se le pasa NO es la superficie del tema sino la
              // base real de la card (`baseBajoCover`, el velo oscuro que
              // existe en los dos temas): con la superficie, en tema claro el
              // cálculo daba un fondo claro que no existe y el texto pasaba a
              // negro sobre ese velo, donde no se ve.
              Widget contenido(Color? colorDominante) {
                final fg = EstiloHelper.textoDeTinte(
                  colorDominante,
                  ColoresApp.baseBajoCover(esOscuro),
                  nivel,
                  fgTema: Colors.white,
                );
                final colorApagado = fg.withValues(alpha: 0.7);
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
                  escalaTexto,
                  efectosPesados,
                  // El color entra como capa de tinte con la opacidad de la
                  // intensidad: la carátula nunca se borra.
                  colorDominante: EstiloHelper.acentoDeTinte(
                    colorDominante,
                    nivel,
                  ),
                  nivel: nivel,
                );
              }

              final Widget tarjeta;
              // `colorPorTarjetaActivo`: en equipos que no llegan al ritmo, el
              // monitor de frames apaga la extracción de la paleta por tarjeta
              // (es lo que escala con la cantidad de items en pantalla).
              // Con paleta de vista NO se extrae el dominante del cover: ya
              // sabemos el color, así que se evita esa decodificación en todas
              // las cards de la pantalla.
              if (nivel > 0 &&
                  colorDominante == null &&
                  acentoVista == null &&
                  coverUrl != null &&
                  EfectosApp.colorPorTarjetaActivo) {
                tarjeta = _conGestosRapidos(
                  this,
                  context,
                  r,
                  _TarjetaTrackColorWrapper(
                    coverUrl: coverUrl!,
                    builder: contenido,
                  ),
                );
              } else {
                tarjeta = _conGestosRapidos(this, context, r, contenido(acento));
              }
              return _conLineaUnida(context, tarjeta);
            },
          ),
    );
  }
}
