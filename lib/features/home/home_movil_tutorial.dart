// home_movil_tutorial.dart — PART de home_movil.dart: sincroniza las
// pestañas del PageView con el paso actual del tutorial interactivo.
//
// El tutorial no se limita a describir: cuando un paso explica algo que
// vive en otra sección (el selector de fuente está en Buscar, los ajustes
// en Mi Espacio), acá se anima el PageView hasta esa sección. Al terminar
// el tutorial el usuario vuelve solo a la pestaña donde estaba, para no
// dejarlo desubicado en la app.
//
// Se conecta con: home_movil (misma library) y tutorial_controller.
// Parte del flujo: Home móvil → tutorial interactivo.
part of 'home_movil.dart';

extension _SincronizacionTutorialMovil on _HomeMovilState {
  /// Lleva el PageView a la pestaña que pide el tutorial (y devuelve al
  /// usuario a la suya cuando el tutorial se cierra).
  ///
  /// Se llama desde `build`, así que el cambio de página se agenda para
  /// después del frame: animar el PageController durante el build
  /// dispara una assertion de Flutter.
  void sincronizarPestanaTutorial(TutorialController tutorial) {
    final pedida = tutorial.visible ? tutorial.pestanaActual : null;

    if (pedida == null) {
      // Tutorial cerrado (o paso sin pestaña): si lo movimos nosotros,
      // se lo devuelve a su pestaña original una sola vez.
      final original = _pestanaAntesDelTutorial;
      if (original == null || _pestanaTutorialAplicada != original) return;
      if (_tab == original) {
        _pestanaAntesDelTutorial = null;
        _pestanaTutorialAplicada = null;
      }
      return;
    }

    // Primer paso que pide pestaña: se recuerda dónde estaba el usuario.
    _pestanaAntesDelTutorial ??= _tab;

    final destino = pedida;
    if (destino == _pestanaTutorialAplicada) return;
    _pestanaTutorialAplicada = destino;
    if (destino == _tab) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pageCtrl.animateToPage(
        destino,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }
}
