// ─────────────────────────────────────────────────────────────
// miniplayer_progreso.dart — PART de miniplayer.dart: barra de
// progreso animada con pulso de glow cuando reproduce y soporte de
// arrastre/tap para buscar. Dibuja con el pintor
// miniplayer_pintor.dart y reporta el nuevo progreso al soltar.
// Se conecta con: miniplayer.dart (misma library) +
// miniplayer_pintor.dart.
// Parte del flujo: reproducción (progreso del miniplayer).
// ─────────────────────────────────────────────────────────────

part of 'miniplayer.dart';

/// Fila inferior autónoma: escucha SOLO la posición/duración del reproductor
/// (BlocBuilder con buildWhen de posición) para repintar únicamente la barrita
/// en cada tick de mpv (~25/s) sin reconstruir el resto del miniplayer.
/// Envuelta en RepaintBoundary para aislar su repintado.
class _FilaProgresoAutonoma extends StatelessWidget {
  final _MiniplayerState st;
  final Responsive r;
  final Color fg;

  const _FilaProgresoAutonoma({
    required this.st,
    required this.r,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CubitReproductor, EstadoAudioReproductor>(
      buildWhen: (prev, curr) =>
          prev.posicion != curr.posicion ||
          prev.duracion != curr.duracion ||
          prev.estadoReproduccion != curr.estadoReproduccion,
      builder: (context, player) {
        final totalMs = player.duracion.inMilliseconds;
        final progreso = totalMs > 0
            ? (player.posicion.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0;
        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(top: 0),
            child: Row(
              children: [
                Text(
                  _formatearDuracionMini(player.posicion),
                  style: TextStyle(
                    fontSize: r.footerSize - 3,
                    color: fg.withValues(alpha: 0.4),
                  ),
                ),
                Expanded(
                  child: _BarraProgresoAnimada(
                    progreso: progreso,
                    reproduciendo: player.estaReproduciendo,
                    color: fg,
                    alSoltar: (v) => st.context
                        .read<CubitReproductor>()
                        .buscarAProgreso(v),
                  ),
                ),
                Text(
                  _formatearDuracionMini(player.duracion),
                  style: TextStyle(
                    fontSize: r.footerSize - 3,
                    color: fg.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Barra de progreso animada con glow pulsante.
class _BarraProgresoAnimada extends StatefulWidget {
  final double progreso;
  final bool reproduciendo;
  final Color color;
  final ValueChanged<double>? alSoltar;

  const _BarraProgresoAnimada({
    required this.progreso,
    required this.reproduciendo,
    required this.color,
    this.alSoltar,
  });

  @override
  State<_BarraProgresoAnimada> createState() => _BarraProgresoAnimadaState();
}

class _BarraProgresoAnimadaState extends State<_BarraProgresoAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulsoCtrl;
  late final Animation<double> _pulsoAnim;
  bool _arrastrando = false;
  double _progresoArrastre = 0;

  @override
  void initState() {
    super.initState();
    _pulsoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulsoAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulsoCtrl, curve: Curves.easeInOut),
    );
    if (widget.reproduciendo) _pulsoCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_BarraProgresoAnimada oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reproduciendo && !_pulsoCtrl.isAnimating) {
      _pulsoCtrl.repeat(reverse: true);
    } else if (!widget.reproduciendo && _pulsoCtrl.isAnimating) {
      _pulsoCtrl.stop();
      _pulsoCtrl.value = 0.6;
    }
  }

  @override
  void dispose() {
    _pulsoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mostrado = _arrastrando ? _progresoArrastre : widget.progreso;
    final fg = widget.color;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        const altoTrack = 3.0;
        const radioPulgar = 5.0;

        return GestureDetector(
          onHorizontalDragStart: (details) {
            _arrastrando = true;
            final x = details.localPosition.dx.clamp(0.0, ancho);
            setState(() => _progresoArrastre = x / ancho);
          },
          onHorizontalDragUpdate: (details) {
            final x = details.localPosition.dx.clamp(0.0, ancho);
            setState(() => _progresoArrastre = x / ancho);
          },
          onHorizontalDragEnd: (details) {
            _arrastrando = false;
            widget.alSoltar?.call(_progresoArrastre);
          },
          onTapDown: (details) {
            _arrastrando = true;
            final x = details.localPosition.dx.clamp(0.0, ancho);
            setState(() => _progresoArrastre = x / ancho);
          },
          onTapUp: (details) {
            _arrastrando = false;
            widget.alSoltar?.call(_progresoArrastre);
          },
          child: AnimatedBuilder(
            animation: _pulsoAnim,
            builder: (context, _) {
              final pulgarX = mostrado * ancho;
              final radioGlow =
                  widget.reproduciendo ? 6.0 + (_pulsoAnim.value * 6.0) : 0.0;
              final escalaPulgar =
                  widget.reproduciendo ? 0.8 + (_pulsoAnim.value * 0.4) : 1.0;

              return CustomPaint(
                size: Size(ancho, radioPulgar * 2 + 4),
                painter: _PintorBarraProgreso(
                  progreso: mostrado,
                  pulgarX: pulgarX,
                  radioPulgar: radioPulgar * escalaPulgar,
                  radioGlow: radioGlow,
                  altoTrack: altoTrack,
                  colorActivo: fg.withValues(alpha: 0.7),
                  colorInactivo: fg.withValues(alpha: 0.1),
                  colorPulgar: fg.withValues(alpha: 0.9),
                  colorGlow: fg,
                ),
              );
            },
          ),
        );
      },
    );
  }
}