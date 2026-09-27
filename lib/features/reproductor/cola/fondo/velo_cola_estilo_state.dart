// ─────────────────────────────────────────────────────────────
// modal_cola_hoja.dart — PART de modal_cola.dart: la hoja completa
// velo_cola_estilo_state.dart — PART de modal_cola.dart: _VeloColaEstiloState (movido desde modal_cola_hoja.dart).
// Se conecta con: modal_cola.dart (misma library).
// ─────────────────────────────────────────────────────────────

part of '../base/hoja/modal_cola.dart';

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
      // `acentoTinte` = el color que de verdad domina en el arte (un cover sin
      // color se tiñe con su propio neutro, sin inventarle un tono).
      if (mounted) setState(() => _acento = paleta?.acentoTinte);
    } catch (e) {
      debugPrint("[Feature] $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PreferenciasEstilo>(
      valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
      builder: (context, prefs, _) {
        // Base de siempre (el velo del tema) y encima el color del cover,
        // que entra de a poco con la intensidad. Con 0 queda idéntico al
        // velo de siempre y con 1 igual que el tinte a full. La intensidad se
        // aplica 1:1: cada punto porcentual mueve lo mismo de punta a punta.
        final nivel = prefs.fondosModals;
        final defaultBg =
            widget.esOscuro ? const Color(0xFF141414) : const Color(0xFFF6F6F6);
        // El color del cover con presencia (estilo_helper): mezclado apagado,
        // sobre su propia carátula no se notaba el cambio. Y acomodado a las
        // letras del tema, que son las de la cola: ninguna portada deja la
        // lista ilegible.
        final colorFinal = EstiloHelper.fondoDeCover(
          _acento ?? defaultBg,
          defaultBg,
          widget.esOscuro ? Colors.white : Colors.black,
          mezcla: widget.esOscuro ? 0.50 : 0.38,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: (widget.esOscuro ? Colors.black : Colors.white).withValues(
                alpha: widget.esOscuro ? 0.74 : 0.55,
              ),
            ),
            if (_acento != null)
              AtenuadoPorNivel(
                opacidad: nivel,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  color: colorFinal,
                ),
              ),
          ],
        );
      },
    );
  }
}
