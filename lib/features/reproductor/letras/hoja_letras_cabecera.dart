// ─────────────────────────────────────────────────────────────
// hoja_letras_cabecera.dart — PART de hoja_letras.dart: cabecera del modal karaoke (título, artista y botón de cerrar) y el velo que reacciona al estilo visual.
// Se conecta con: hoja_letras.dart (misma library) + paleta_portada + estilo_helper.
// Parte del flujo: Reproductor → letras (cabecera y velo).
// ─────────────────────────────────────────────────────────────

part of 'hoja_letras.dart';

Widget _cabeceraHoja(
  _HojaLetrasState st,
  BuildContext context,
  Responsive r,
  bool esOscuro,
) {
  final fg = esOscuro ? Colors.white : Colors.black;
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingL),
    child: Row(
      children: [
        Icon(Icons.lyrics_rounded, size: r.subtitleSize + 2, color: fg),
        SizedBox(width: r.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                st.widget.track.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: r.subtitleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                st.widget.track.artists ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.5),
                  fontSize: r.footerSize,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: fg),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

/// Velo that reacts to visual style for blur/dominant color.
class _VeloLetrasEstilo extends StatefulWidget {
  final bool esOscuro;
  final String? caratula;
  const _VeloLetrasEstilo({required this.esOscuro, required this.caratula});
  @override
  State<_VeloLetrasEstilo> createState() => _VeloLetrasEstiloState();
}

class _VeloLetrasEstiloState extends State<_VeloLetrasEstilo> {
  Color? _acento;
  @override
  void initState() {
    super.initState();
    _extraerColor();
  }
  @override
  void didUpdateWidget(covariant _VeloLetrasEstilo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caratula != widget.caratula) _extraerColor();
  }
  Future<void> _extraerColor() async {
    if (widget.caratula == null || widget.caratula!.isEmpty) return;
    try {
      final paleta = await paletaParaPortada(widget.caratula);
      if (mounted) setState(() => _acento = paleta?.dominante);
    } catch (e) { debugPrint("[Feature] $e"); }
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
            if (spotify && _acento != null) {
              final defaultBg = widget.esOscuro
                  ? const Color(0xFF141414)
                  : const Color(0xFFF6F6F6);
              final colorFinal = Color.lerp(
                defaultBg,
                _acento!,
                widget.esOscuro ? 0.35 : 0.25,
              )!;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                color: colorFinal,
              );
            }
            return Container(
              color: (widget.esOscuro ? Colors.black : Colors.white)
                  .withValues(alpha: widget.esOscuro ? 0.68 : 0.5),
            );
          },
        );
      },
    );
  }
}
