// ─────────────────────────────────────────────────────────────
// indicador_descarga_dots.dart — PART de indicador_descarga.dart:
// los dos puntos animados del indicador — el punto pulsante (glow
// + escala oscilando 1.2s, para descargas sin % conocido) y el arco
// de progreso circular (anillo con valor 0..1). Cada uno con su
// propio controlador de animación.
// Se conecta con: indicador_descarga.dart (misma library).
// Parte del flujo: búsqueda, feed, detalle, mi espacio (badges).
// ─────────────────────────────────────────────────────────────

part of 'indicador_descarga.dart';

/// Punto que pulsa suavemente mientras la descarga está en progreso.
class _PuntoPulsante extends StatefulWidget {
  final double tamano;
  final Color color;

  const _PuntoPulsante({required this.tamano, required this.color});

  @override
  State<_PuntoPulsante> createState() => _PuntoPulsanteState();
}

class _PuntoPulsanteState extends State<_PuntoPulsante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final glowAlpha = 0.15 + t * 0.25; // 0.15 → 0.4
        final escala = 0.85 + t * 0.15; // 0.85 → 1.0
        return Container(
          width: widget.tamano * escala,
          height: widget.tamano * escala,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glowAlpha),
                blurRadius: widget.tamano * 2,
                spreadRadius: widget.tamano * 0.5,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Arco de progreso circular pequeño para descargas con % conocido.
class _PuntoProgreso extends StatelessWidget {
  final double tamano;
  final Color color;
  final double progreso;

  const _PuntoProgreso({
    required this.tamano,
    required this.color,
    required this.progreso,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progreso,
            strokeWidth: 2,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }
}