// home_escritorio_tutorial.dart — PART de home_escritorio.dart:
// sincroniza la sección activa del shell de escritorio con el paso
// actual del tutorial interactivo.
//
// En escritorio el IndexedStack mantiene las tres secciones montadas, así
// que el spotlight podría apuntar a un widget de otra sección. Cambiar de
// sección hace que el usuario vea dónde vive cada cosa (mismo criterio que
// en móvil) y que el foco esté en la sección que se está explicando.
//
// Se conecta con: home_escritorio (misma library) y tutorial_controller.
// Parte del flujo: Home escritorio → tutorial interactivo.
part of 'home_escritorio.dart';

extension _SincronizacionTutorialEscritorio on _HomeEscritorioState {
  /// Cambia a la sección que pide el tutorial y devuelve al usuario a la
  /// suya cuando el tutorial termina.
  ///
  /// Se llama desde `build`: el cambio se agenda para después del frame
  /// para no mutar el estado durante el build del árbol.
  void sincronizarPestanaTutorial(TutorialController tutorial) {
    final pedida = tutorial.visible ? tutorial.pestanaActual : null;

    if (pedida == null) {
      final original = _pestanaAntesDelTutorial;
      if (original == null || _pestanaTutorialAplicada != original) return;
      if (_tab == original) {
        _pestanaAntesDelTutorial = null;
        _pestanaTutorialAplicada = null;
      }
      return;
    }

    _pestanaAntesDelTutorial ??= _tab;

    final destino = pedida;
    if (destino == _pestanaTutorialAplicada) return;
    _pestanaTutorialAplicada = destino;
    if (destino == _tab) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cambiarTab(destino);
    });
  }
}
