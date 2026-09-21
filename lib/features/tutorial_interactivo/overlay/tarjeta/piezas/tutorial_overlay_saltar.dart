// tutorial_overlay_saltar.dart — PART de tutorial_overlay.dart: la pastilla para
// salir de TODO el tutorial, siempre visible arriba a la derecha.
//
// Va sobre el fondo oscurecido (no sobre la tarjeta), por eso su color no
// depende de la superficie del tema.
//
// Se conecta con: tutorial_overlay (la monta) y l10n (texto ES/EN).
// Parte del flujo: tutorial interactivo (acción global de la capa).
part of '../../tutorial_overlay.dart';

/// Salir del tutorial completo: pastilla siempre visible arriba a la derecha,
/// sobre el fondo oscurecido (por eso su texto no depende de la superficie).
class _BotonSaltarTodo extends StatelessWidget {
  final TutorialController controller;

  const _BotonSaltarTodo({required this.controller});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context).tutorialInteractivo;
    // La pastilla mide por aparato: en la tele se toca con el puntero, así que
    // crece entera (radio, aire, ícono y texto).
    final r = Responsive(context);
    final esp = EspecificacionesPlataforma.de(context);
    final radius = BorderRadius.circular(esp.radioBoton);
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: controller.saltarTodo,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.spacingL,
            vertical: r.spacingS,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.close_rounded,
                size: esp.iconoBoton,
                color: Colors.white,
              ),
              SizedBox(width: r.spacingS),
              Text(
                loc.skipAll,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.sobre(12.5, 18),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
