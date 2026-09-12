// ─────────────────────────────────────────────────────────────
// tarjeta_grilla.dart — Tarjeta de grilla para álbumes, playlists
// y artistas: portada de fondo borrosa (o gradiente preset) con
// scrim, portada nítida centrada (circular para artistas), bloque
// de info siempre visible (acciones + título + subtítulo + contador
// de reproducciones) y badge de esquina opcional. Los helpers de
// descarga viven en el part tarjeta_grilla_descarga.dart.
// Se conecta con: perfil_rendimiento (efectos pesados) +
// imagen_portada + indicador_descarga + colores_app + responsive.
// Parte del flujo: feed, búsqueda, mi espacio (álbumes/playlists).
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/inyeccion.dart';
import '../../core/modelos/estilo_visual.dart';
import '../../core/modelos/perfil_rendimiento.dart';
import '../../core/modelos/preferencias_estilo.dart';
import '../../l10n/app_localizations.dart';
import '../tema/colores_app.dart';
import '../utilidades/haptico.dart';
import '../utilidades/paleta_portada.dart';
import '../utilidades/responsive.dart';
import 'imagen_portada.dart';
import 'indicador_descarga.dart';

part 'tarjeta_grilla_descarga.dart';
part 'tarjeta_grilla_widgets.dart';
part 'tarjeta_grilla_info.dart';
part 'tarjeta_grilla_visual.dart';

/// Tarjeta de grilla (álbum/playlist/artista) reutilizada en varias vistas.
class TarjetaGrilla extends StatelessWidget {
  final String tipo;
  final String titulo;
  final String subtitulo;
  final String? coverUrl;
  final VoidCallback? onTap;
  final bool esAmado;
  final VoidCallback? onLike;
  final EstadoDescarga estadoDescarga;
  final double? progresoDescarga;
  final VoidCallback? onDescargar;
  final VoidCallback? onPausar;
  final VoidCallback? onBorrar;
  final VoidCallback? onReintentar;
  final VoidCallback? onMas;
  final VoidCallback? onExportar;
  final bool mostrarAnimacionBorrar;
  final bool mostrarAcciones;
  final bool accionesHabilitadas;
  final double escalaTexto;

  /// Insignia opcional en la esquina superior izquierda de la portada
  /// (p.ej. indicador de origen para items amados/descargados en Mi Espacio).
  final Widget? insigniaEsquina;

  /// Si mostrar la acción trasera (exportar / más). False en Mi Espacio para
  /// que las tarjetas de álbum/playlist solo expongan like + descarga.
  final bool mostrarTerceraAccion;

  /// Si mostrar la acción de descarga. False cuando un item no se puede
  /// descargar (p.ej. playlist local sin fuente de proveedor).
  final bool mostrarAccionDescarga;
  final int contadorReproducciones;

  /// Color dominante extraído del cover. Se usa en modo Spotify para
  /// teñir el fondo, bordes y sombras de la tarjeta con el color del album.
  final Color? colorDominante;

  const TarjetaGrilla({
    super.key,
    required this.tipo,
    required this.titulo,
    required this.subtitulo,
    this.coverUrl,
    this.onTap,
    this.esAmado = false,
    this.onLike,
    this.estadoDescarga = EstadoDescarga.ninguno,
    this.progresoDescarga,
    this.onDescargar,
    this.onPausar,
    this.onBorrar,
    this.onReintentar,
    this.onMas,
    this.onExportar,
    this.mostrarAnimacionBorrar = false,
    this.mostrarAcciones = true,
    this.accionesHabilitadas = true,
    this.escalaTexto = 1.0,
    this.insigniaEsquina,
    this.mostrarTerceraAccion = true,
    this.mostrarAccionDescarga = true,
    this.contadorReproducciones = 0,
    this.colorDominante,
  });

  IconData get _icono {
    switch (tipo) {
      case 'album':
        return Icons.album;
      case 'playlist':
        return Icons.queue_music;
      case 'artist':
        return Icons.person;
      default:
        return Icons.music_note;
    }
  }

  bool get _esArtista => tipo == 'artist';

  /// Alto garantizado del bloque de info (acciones + título + subtítulo)
  /// para que texto e iconos SIEMPRE se vean sin importar el tamaño.
  double _altoInfo(Responsive r, double ts, bool conAcciones) {
    var h = r.spacingS; // espacio bajo la portada
    if (conAcciones) {
      h += r.footerSize * 1.3 + r.spacingXS;
    }
    h += (r.footerSize + 4) * ts * 2 * 1.18; // título (hasta 2 líneas)
    h += 3 + (r.footerSize + 1) * ts * 1.18; // subtítulo (1 línea)
    return h;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstiloVisual>(
      valueListenable: sl<ValueNotifier<EstiloVisual>>(),
      builder: (context, estilo, _) {
        return ValueListenableBuilder<PreferenciasEstilo>(
          valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
          builder: (context, prefs, _) {
            final r = Responsive(context);
            final theme = Theme.of(context);
            final esOscuro = theme.brightness == Brightness.dark;
            final fondoFallback = ColoresApp.superficie(esOscuro);
            final fg = ColoresApp.enSuperficie(esOscuro);
            final ts = escalaTexto;
            final efectosPesados =
                sl<ValueNotifier<PerfilRendimiento>>().value.efectosPesados;

            final spotify =
                estilo == EstiloVisual.spotify && prefs.cardsGrilla;

            return RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (spotify && colorDominante == null && coverUrl != null) {
                    return _TarjetaGrillaColorWrapper(
                      coverUrl: coverUrl!,
                      builder: (colorDominante) => _cuerpoTarjeta(
                        this,
                        context,
                        constraints,
                        r,
                        esOscuro,
                        fondoFallback,
                        fg,
                        ts,
                        efectosPesados,
                        colorDominante: colorDominante,
                      ),
                    );
                  }
                  return _cuerpoTarjeta(
                    this,
                    context,
                    constraints,
                    r,
                    esOscuro,
                    fondoFallback,
                    fg,
                    ts,
                    efectosPesados,
                    colorDominante: spotify ? colorDominante : null,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Wrapper que extrae el color dominante del cover de forma asíncrona.
/// Solo se usa en modo Spotify cuando no se proporciona colorDominante.
class _TarjetaGrillaColorWrapper extends StatefulWidget {
  final String coverUrl;
  final Widget Function(Color? colorDominante) builder;

  const _TarjetaGrillaColorWrapper({
    required this.coverUrl,
    required this.builder,
  });

  @override
  State<_TarjetaGrillaColorWrapper> createState() =>
      _TarjetaGrillaColorWrapperState();
}

class _TarjetaGrillaColorWrapperState extends State<_TarjetaGrillaColorWrapper> {
  Color? _color;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  @override
  void didUpdateWidget(covariant _TarjetaGrillaColorWrapper oldWidget) {
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