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
    // La tarjeta flotante mide por aparato: radio de tarjeta del aparato y
    // márgenes que crecen en pantallas grandes (y en la tele).
    final r = Responsive(context);
    final radius = BorderRadius.circular(
      EspecificacionesPlataforma.de(context).radioTarjeta,
    );
    return BlocBuilder<CubitCola, EstadoCola>(
      buildWhen:
          (prev, curr) =>
              prev.tieneActual != curr.tieneActual ||
              prev.actual?.id != curr.actual?.id,
      builder: (context, cola) {
        if (!cola.tieneActual) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.fromLTRB(
            r.sobre(18, 30),
            r.spacingXS,
            r.sobre(18, 30),
            r.sobre(14, 24),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: esOscuro ? 0.45 : 0.14),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(borderRadius: radius, child: miniPlayer),
          ),
        );
      },
    );
  }
}
