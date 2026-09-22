// ─────────────────────────────────────────────────────────────
// settings_sheet_background.dart — Fondo con tinte de la canción actual del sheet de Ajustes: pinta el color
// dominante del cover detrás del contenido y lo anima al cambiar de track.
//
// Se conecta con: settings_sheet_new.dart (misma library) + paleta del cover.
// Parte del flujo: Ajustes → fondo del sheet.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

class _SongTintedBackground extends StatefulWidget {
  final EstadoCola queue;
  final bool isDark;
  final Color defaultBg;
  final Widget child;

  const _SongTintedBackground({
    super.key,
    required this.queue,
    required this.isDark,
    required this.defaultBg,
    required this.child,
  });

  @override
  State<_SongTintedBackground> createState() => _SongTintedBackgroundState();
}

class _SongTintedBackgroundState extends State<_SongTintedBackground> {
  Color _bg = const Color(0xFF000000);
  String? _cover;
  bool _hasTrack = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _SongTintedBackground old) {
    super.didUpdateWidget(old);
    if (old.queue != widget.queue) _refresh();
  }

  Future<void> _refresh() async {
    final track = widget.queue.actual;
    final hasTrack = track != null;
    String? cover;
    if (hasTrack) {
      try {
        cover = sl<CubitLikes>().caratulaLocalPara(track) ?? track.coverUrl;
      } catch (e) {
        debugPrint('[SongTintedBackgroundState] $e');
        cover = track.coverUrl;
      }
    }
    final bg =
        hasTrack
            ? (await _dominantFor(cover)) ?? widget.defaultBg
            : widget.defaultBg;
    if (!mounted) return;
    setState(() {
      _bg = bg;
      _cover = cover;
      _hasTrack = hasTrack;
    });
  }

  Future<Color?> _dominantFor(String? cover) async {
    if (cover == null || cover.isEmpty) return null;
    final palette = await paletaParaPortada(cover);
    if (palette == null) return null;
    // El color del cover con presencia (estilo_helper): mezclado apagado el
    // fondo del sheet quedaba casi igual que su propia carátula.
    return EstiloHelper.colorDeCover(
      palette.dominante,
      widget.defaultBg,
      mezcla: widget.isDark ? 0.50 : 0.42,
    );
  }

  @override
  Widget build(BuildContext context) {
    // El fondo ESCUCHA el estilo con cover: sin esto, mover el control en
    // Ajustes no repintaba nada hasta que el sheet se reconstruía por otro
    // motivo (y el usuario sentía que el slider no hacía nada).
    return ValueListenableBuilder<PreferenciasEstilo>(
      valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
      builder: (context, prefs, _) {
        // El redondeo de arriba de la hoja sale del aparato: en la tele la
        // hoja es más grande y se redondea más.
        final esp = EspecificacionesPlataforma.de(context);
        // La portada borrosa se apaga a medida que sube la intensidad de
        // "fondos de modales": con 1 queda sólo el color del cover (_bg).
        // Se aplica 1:1: cada punto porcentual mueve lo mismo.
        // En MODO FLUIDO la portada a pantalla completa no se pinta: se va
        // directo al color (el mismo estado del control al 100%).
        final nivel =
            EfectosApp.fotoPantallaCompletaActiva ? prefs.fondosModals : 1.0;
        // Sigma de fábrica del modal; con el control sube (la portada se va
        // desenfocando mientras se disuelve en el color del cover).
        final sigmaBase =
            sl<ValueNotifier<PerfilRendimiento>>().value.sigmaDesenfoque;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(esp.radioHoja),
            ),
            color: _bg,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (_hasTrack && _cover != null && _cover!.isNotEmpty)
                Positioned.fill(
                  child: AtenuadoPorNivel(
                    opacidad: 1 - nivel,
                    child: DesenfoqueHijo(
                      sigma: EstiloHelper.sigmaPorNivel(sigmaBase, nivel),
                      tope: EstiloHelper.topeSigma(sigmaBase),
                      child: Transform.scale(
                        scale: 1.3,
                        child: imagenDesdeUrl(
                          _cover!,
                          ajuste: BoxFit.cover,
                          ancho: 512,
                          alto: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
              // Velo de legibilidad del contenido sobre la carátula: se
              // aclara con la intensidad, y al final el tinte ya es _bg.
              Positioned.fill(
                child: ColoredBox(
                  color: _bg.withValues(
                    alpha: EstiloHelper.mezclar(
                      widget.isDark ? 0.72 : 0.55,
                      widget.isDark ? 0.45 : 0.35,
                      nivel,
                    ),
                  ),
                ),
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

/// Opens the new tabbed settings sheet.
