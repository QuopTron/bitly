// ─────────────────────────────────────────────────────────────
// miniplayer_animacion.dart — PART de miniplayer.dart: anima un
// fade + slide-up del miniplayer cuando cambia el id del track
// (nueva canción). Re-ejecuta la animación en didUpdateWidget.
// Se conecta con: miniplayer.dart (misma library).
// Parte del flujo: reproducción (transición de track).
// ─────────────────────────────────────────────────────────────

part of 'miniplayer.dart';

/// Fade + slide-up cuando el id del track cambia (nueva canción).
class _WidgetAnimadoTrack extends StatefulWidget {
  final String trackId;
  final Widget child;

  const _WidgetAnimadoTrack({
    super.key,
    required this.trackId,
    required this.child,
  });

  @override
  State<_WidgetAnimadoTrack> createState() => _WidgetAnimadoTrackState();
}

class _WidgetAnimadoTrackState extends State<_WidgetAnimadoTrack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_WidgetAnimadoTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) {
      _ctrl
        ..reset()
        ..forward();
    }
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
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: Transform.translate(offset: _slideAnim.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}