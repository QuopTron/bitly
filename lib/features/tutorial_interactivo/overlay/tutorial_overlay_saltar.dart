// tutorial_overlay_saltar.dart — PART de tutorial_overlay.dart: la pastilla para
// salir de TODO el tutorial, siempre visible arriba a la derecha.
//
// Va sobre el fondo oscurecido (no sobre la tarjeta), por eso su color no
// depende de la superficie del tema.
//
// Se conecta con: tutorial_overlay (la monta) y l10n (texto ES/EN).
// Parte del flujo: tutorial interactivo (acción global de la capa).
part of 'tutorial_overlay.dart';

/// Salir del tutorial completo: pastilla siempre visible arriba a la derecha,
/// sobre el fondo oscurecido (por eso su texto no depende de la superficie).
class _BotonSaltarTodo extends StatelessWidget {
  final TutorialController controller;

  const _BotonSaltarTodo({required this.controller});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context).tutorialInteractivo;
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: controller.saltarTodo,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                loc.skipAll,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
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
