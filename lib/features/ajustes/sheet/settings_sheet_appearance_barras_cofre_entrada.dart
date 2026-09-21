// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_cofre_entrada.dart — PART de
// settings_sheet_new.dart: la ENTRADA escalonada de una paleta del cofre.
//
// Cada paleta aparece, sube unos píxeles y crece, un poco después que la
// anterior: es lo que hace que abrir el cofre se sienta como abrir un cofre
// y no como un salto seco.
//
// Se conecta con: _cofre_panel (la grilla, que le pasa el control de la
// animación y el índice) + _cofre_tile (lo que entra).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Envuelve a una paleta para que entre escalonada.
class _PaletaConEntrada extends StatelessWidget {
  /// Control de la animación del panel (0 → 1 al abrir).
  final Animation<double> entrada;

  /// Posición en la grilla: define su retraso.
  final int indice;

  /// Lo que entra (la tarjeta de la paleta).
  final Widget child;

  const _PaletaConEntrada({
    required this.entrada,
    required this.indice,
    required this.child,
  });

  /// Cada cuánto arranca la siguiente (y cuánto dura cada una).
  static const _paso = 0.05;
  static const _duracion = 0.45;

  @override
  Widget build(BuildContext context) {
    final inicio = (indice * _paso).clamp(0.0, 0.55);
    final anim = CurvedAnimation(
      parent: entrada,
      curve: Interval(
        inicio,
        (inicio + _duracion).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return AnimatedBuilder(
      animation: anim,
      builder:
          (context, hijo) => Opacity(
            opacity: anim.value,
            child: Transform.translate(
              offset: Offset(0, (1 - anim.value) * 14),
              child: Transform.scale(
                scale: 0.86 + 0.14 * anim.value,
                child: hijo,
              ),
            ),
          ),
      child: child,
    );
  }
}
