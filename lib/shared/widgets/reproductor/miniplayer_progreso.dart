// ─────────────────────────────────────────────────────────────
// miniplayer_progreso.dart — PART de miniplayer.dart: la fila
// inferior con los tiempos y la barra de progreso. Escucha solo la
// posición/duración del reproductor para no repintar el resto del
// miniplayer. La barra en sí vive en miniplayer_barra.dart.
// Se conecta con: miniplayer.dart (misma library) +
// miniplayer_barra.dart.
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
                    alSoltar: (v) =>
                        st.context.read<CubitReproductor>().buscarAProgreso(v),
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
