// ─────────────────────────────────────────────────────────────
// barra_navegacion_flotante_item.dart — PART de
// barra_navegacion_flotante.dart: un ÍTEM del navbar (ícono + punto).
//
// Va aparte para que el archivo del navbar se ocupe del vidrio, el adorno y
// el color, y este solo dibuje cada pestaña. El ítem no sabe de navegación:
// avisa por callback y el navbar decide.
//
// Se conecta con: barra_navegacion_flotante.dart (misma library).
// Parte del flujo: Home → navbar flotante.
// ─────────────────────────────────────────────────────────────

part of 'barra_navegacion_flotante.dart';

/// Una pestaña del navbar: ícono, etiqueta para lectores de pantalla y punto
/// que aparece cuando está elegida.
class _ItemNavBarra extends StatelessWidget {
  final IconData icono;
  final bool seleccionado;
  final Responsive r;
  final Color onBg;

  /// Etiqueta accesible de la pestaña.
  final String etiqueta;

  final VoidCallback onTap;

  const _ItemNavBarra({
    required this.icono,
    required this.seleccionado,
    required this.r,
    required this.onBg,
    required this.etiqueta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(vertical: r.spacingS * 1.1),
      decoration: BoxDecoration(
        color: seleccionado ? onBg.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: seleccionado ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Semantics(
              label: etiqueta,
              child: Icon(
                icono,
                size: r.subtitleSize + 10,
                color: seleccionado ? onBg : onBg.withValues(alpha: 0.35),
              ),
            ),
          ),
          SizedBox(height: r.spacingXS * 0.7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: seleccionado ? 5 : 0,
            height: seleccionado ? 5 : 0,
            decoration: BoxDecoration(
              color: onBg.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    ),
  );
}
