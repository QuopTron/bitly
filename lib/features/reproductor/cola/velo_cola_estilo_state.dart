// ─────────────────────────────────────────────────────────────
// modal_cola_hoja.dart — PART de modal_cola.dart: la hoja completa
// velo_cola_estilo_state.dart — PART de modal_cola.dart: _VeloColaEstiloState (movido desde modal_cola_hoja.dart).
// Se conecta con: modal_cola.dart (misma library).
// ─────────────────────────────────────────────────────────────

part of 'modal_cola.dart';

class _VeloColaEstiloState extends State<_VeloColaEstilo> {
  Color? _acento;
  @override
  void initState() {
    super.initState();
    _extraerColor();
  }
  @override
  void didUpdateWidget(covariant _VeloColaEstilo oldWidget) {
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
                  .withValues(alpha: widget.esOscuro ? 0.74 : 0.55),
            );
          },
        );
      },
    );
  }
}