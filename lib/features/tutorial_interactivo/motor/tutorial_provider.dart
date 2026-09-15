// ─────────────────────────────────────────────────────────────
// tutorial_provider.dart — InheritedNotifier que expone el
// TutorialController a cualquier widget del árbol (lo leen la home de
// escritorio, la de móvil y el perfil de Mi Espacio).
// Se conecta con: tutorial_controller + ensamblador_home (que lo
// provee y lo re-exporta).
// Parte del flujo: tutorial interactivo post-setup.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'tutorial_controller.dart';

/// InheritedProvider para que el TutorialController sea accesible
/// desde cualquier parte del árbol de widgets.
class TutorialProvider extends InheritedNotifier<TutorialController> {
  const TutorialProvider({
    super.key,
    required TutorialController controller,
    required super.child,
  }) : super(notifier: controller);

  static TutorialController of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TutorialProvider>()!
        .notifier!;
  }

  /// Igual que [of] pero devuelve null si no hay provider arriba: útil para
  /// widgets que también se usan sueltos (tests, previews).
  static TutorialController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TutorialProvider>()
        ?.notifier;
  }
}
