// ─────────────────────────────────────────────────────────────
// home_escritorio_miniplayer.dart — PART de home_escritorio.dart:
// el miniplayer en su variante de escritorio (tarjeta flotante con
// sombra y esquinas redondeadas), que se oculta entero cuando no hay
// track actual.
// Se conecta con: home_escritorio.dart (misma library) +
// cubit_cola + miniplayer.
// Parte del flujo: Home (variante escritorio).
// ─────────────────────────────────────────────────────────────

part of 'home_escritorio.dart';

/// Miniplayer en su variante de escritorio: tarjeta flotante con sombra y
/// esquinas redondeadas (en móvil queda como barra pegada al borde). Se
/// oculta entero cuando no hay track actual (el miniplayer interno devuelve
/// un SizedBox.shrink, pero la tarjeta no debe dejar una sombra vacía).
class _MiniplayerEscritorio extends StatelessWidget {
  final Widget miniPlayer;

  const _MiniplayerEscritorio({required this.miniPlayer});

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<CubitCola, EstadoCola>(
      buildWhen: (prev, curr) =>
          prev.tieneActual != curr.tieneActual ||
          prev.actual?.id != curr.actual?.id,
      builder: (context, cola) {
        if (!cola.tieneActual) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: esOscuro ? 0.45 : 0.14),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: miniPlayer,
            ),
          ),
        );
      },
    );
  }
}
