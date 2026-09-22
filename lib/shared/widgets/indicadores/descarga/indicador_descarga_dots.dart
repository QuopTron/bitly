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

/// Punto que pulsa suavemente mientras la descarga está en progreso.
///
/// En gama baja (y cuando el [MonitorFrames] detecta que el equipo no llega al
/// ritmo) el punto queda FIJO. Por qué: esto es un `AnimationController` en
/// `repeat(reverse: true)` que corre todo el tiempo en que haya una descarga
/// activa, y pinta una sombra desenfocada en cada frame. En una lista con
/// varias descargas a la vez son varias animaciones perpetuas con blur — justo
/// lo que congela una GPU modesta, mientras se navega. Fijo se ve igual de
/// claro.
class _PuntoPulsanteState extends State<_PuntoPulsante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  bool get _pulsoActivo => EfectosApp.desenfoqueActivo;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Si el monitor de frames degrada los efectos (o el usuario activa el modo
    // fluido) a mitad de sesión, el pulso se detiene solo: el listener
    // reacciona a CUALQUIER interruptor de efectos, no solo al del perfil.
    EfectosApp.cambiosEfectos.addListener(_sincronizarPulso);
    _sincronizarPulso();
  }

  void _sincronizarPulso() {
    if (!mounted) return;
    if (_pulsoActivo) {
      if (!_ctrl.isAnimating) _ctrl.repeat(reverse: true);
    } else if (_ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    EfectosApp.cambiosEfectos.removeListener(_sincronizarPulso);
    _ctrl.dispose();
    super.dispose();
  }

  /// Punto con su glow, para una fase `t` del pulso (0 = reposo).
  Widget _punto(double t, bool conGlow) {
    final escala = 0.85 + t * 0.15; // 0.85 → 1.0
    return Container(
      width: widget.tamano * escala,
      height: widget.tamano * escala,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        // El halo es un blur por frame: sin efectos no se pinta.
        boxShadow:
            conGlow
                ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.15 + t * 0.25),
                    blurRadius: widget.tamano * 2,
                    spreadRadius: widget.tamano * 0.5,
                  ),
                ]
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: EfectosApp.cambiosEfectos,
      builder:
          (context, _) =>
              EfectosApp.desenfoqueActivo
                  ? AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) => _punto(_ctrl.value, true),
                  )
                  : _punto(0, false),
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
