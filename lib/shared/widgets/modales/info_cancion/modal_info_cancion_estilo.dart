// ─────────────────────────────────────────────────────────────
// modal_info_cancion_estilo.dart — PART de modal_info_cancion.dart:
// wrapper que reacciona al estilo visual (blur/color dominante) del
// modal de info de canción. La hoja en sí vive en info_cancion_hoja.dart.
// Se conecta con: modal_info_cancion.dart (misma library) +
// info_cancion_hoja + estilo_helper + paleta_portada.
// Parte del flujo: Reproductor → info de canción (estilo visual).
// ─────────────────────────────────────────────────────────────

part of 'modal_info_cancion.dart';

/// Widget wrapper that reacts to visual style for blur/dominant color.
class _InfoCancionEstilo extends StatefulWidget {
  final bool esOscuro;
  final Color bg;
  final Color onBg;
  final bool hayTrack;
  final Color fondoModal;
  final Responsive r;
  final AppLocalizations loc;
  final ItemFeed item;
  final String duracion;

  const _InfoCancionEstilo({
    required this.esOscuro,
    required this.bg,
    required this.onBg,
    required this.hayTrack,
    required this.fondoModal,
    required this.r,
    required this.loc,
    required this.item,
    required this.duracion,
  });

  @override
  State<_InfoCancionEstilo> createState() => _InfoCancionEstiloState();
}

class _InfoCancionEstiloState extends State<_InfoCancionEstilo> {
  Color? _acento;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  Future<void> _extraerColor() async {
    final url = widget.item.coverUrl;
    if (url == null || url.isEmpty) return;
    try {
      final paleta = await paletaParaPortada(url);
      if (mounted) setState(() => _acento = paleta?.dominante);
    } catch (e) {
      debugPrint('[InfoCancion] color dominante: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstiloVisual>(
      valueListenable: sl<ValueNotifier<EstiloVisual>>(),
      builder: (context, estilo, _) {
        return ValueListenableBuilder<PreferenciasEstilo>(
          valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
          builder: (context, prefs, _) {
            final spotify =
                estilo == EstiloVisual.spotify && prefs.fondosModals;
            Widget hoja = _construirHojaInfoCancion(
              context: context,
              r: widget.r,
              onBg: widget.onBg,
              loc: widget.loc,
              item: widget.item,
              duracion: widget.duracion,
              fondoModal: widget.fondoModal,
            );

            if (spotify && widget.hayTrack && _acento != null) {
              final defaultBg = widget.esOscuro
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF5F5F5);
              final colorFinal = Color.lerp(
                defaultBg,
                _acento!,
                widget.esOscuro ? 0.45 : 0.30,
              )!;
              hoja = ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  color: colorFinal,
                  child: hoja,
                ),
              );
            } else if (widget.hayTrack) {
              hoja = ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: DesenfoqueAdaptativo(sigma: 24, child: hoja),
              );
            }
            return hoja;
          },
        );
      },
    );
  }
}
