// ─────────────────────────────────────────────────────────────
// texto_marquesina_estado.dart — PART de texto_marquesina.dart:
// estado del desplazamiento (mide, arranca y detiene la animación).
//
// Se conecta con: texto_marquesina.dart (misma library).
// Parte del flujo: reproductor (letras sincronizadas).
// ─────────────────────────────────────────────────────────────

part of 'texto_marquesina.dart';

class _TextoMarquesinaState extends State<TextoMarquesina>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));

  bool _animando = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Compara lo que se ve contra el hueco disponible y arranca o detiene la
  /// animación. Se llama desde el build, así que el arranque real se difiere
  /// al siguiente frame.
  void _sincronizar({required bool desborda, required double recorrido}) {
    final debe = widget.activo && desborda;
    if (!debe) {
      if (_animando) {
        _animando = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ctrl.stop();
        });
      }
      if (_ctrl.value != 0) _ctrl.value = 0;
      return;
    }
    if (_animando) return;
    _animando = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_animando) return;
      final ms = (recorrido / widget.velocidad * 1000).round() +
          widget.pausa.inMilliseconds * 2;
      _ctrl.duration = Duration(milliseconds: ms.clamp(1200, 20000));
      _ctrl.repeat(reverse: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final efectivo = DefaultTextStyle.of(context).style.merge(widget.estilo);
    return LayoutBuilder(
      builder: (context, caja) {
        final anchoCaja = caja.maxWidth.isFinite ? caja.maxWidth : 0.0;
        final anchoTexto =
            _medir(context, TextSpan(style: efectivo, children: [widget.span]));
        final desborda = anchoCaja > 0 && anchoTexto > anchoCaja + 2;
        final recorrido =
            (anchoTexto + widget.margenFinal - anchoCaja).clamp(0.0, 12000.0);
        _sincronizar(desborda: desborda, recorrido: recorrido);

        if (!desborda) {
          return ClipRect(
            child: Align(
              alignment: Alignment.center,
              child: Text.rich(
                widget.span,
                style: efectivo,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          );
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, hijo) => Transform.translate(
              offset: Offset(
                -recorrido * Curves.easeInOutSine.transform(_ctrl.value),
                0,
              ),
              child: hijo,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(right: widget.margenFinal),
                child: Text.rich(
                  widget.span,
                  style: efectivo,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Ancho real del texto en UNA línea, con el estilo y la escala vigentes.
  double _medir(BuildContext context, InlineSpan span) {
    final painter = TextPainter(
      text: span,
      textDirection: Directionality.of(context),
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final ancho = painter.width;
    painter.dispose();
    return ancho;
  }
}
