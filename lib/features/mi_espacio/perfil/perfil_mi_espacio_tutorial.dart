// perfil_mi_espacio_tutorial.dart — PART de perfil_mi_espacio.dart: hace
// que los pasos del tutorial que viven en AJUSTES abran la hoja solos.
//
// El tutorial explica cada pestaña de ajustes (Apariencia, Descargas,
// Rendimiento, Más). Para eso la hoja tiene que estar abierta y el overlay
// (que vive en el Overlay raíz) por encima; acá se maneja esa coreografía:
//
//   1. el paso pide ajustes  -> se abre la hoja CON el tutorial adentro
//   2. se vuelve a traer la capa del tutorial al frente (la hoja se apila
//      arriba de lo que ya existía)
//   3. se cierra la hoja cuando el paso deja de ser de ajustes
//
// El flag `hojaAjustesAbierta` se apaga solo si el usuario la cierra a mano,
// así nunca se cierra una pantalla que no abrimos nosotros.
//
// Se conecta con: perfil_mi_espacio (misma library) + settings_sheet_new +
// tutorial_controller.
// Parte del flujo: tutorial interactivo → explicación de Ajustes.
part of 'perfil_mi_espacio.dart';

extension _AjustesDelTutorial on _PerfilMiEspacioState {
  /// Sigue al tutorial: abre la hoja de ajustes cuando un paso la necesita y
  /// la cierra cuando el tutorial sigue con otra cosa.
  void sincronizarAjustesTutorial(BuildContext context) {
    if (!mounted) return;
    final ctrl = TutorialProvider.maybeOf(context);
    if (!identical(ctrl, tutorial)) {
      tutorial?.removeListener(alCambiarTutorial);
      tutorial = ctrl?..addListener(alCambiarTutorial);
    }

    final quiere = tutorial?.enAjustesActual ?? false;
    if (quiere && !hojaAjustesAbierta) {
      hojaAjustesAbierta = true;
      abrirAjustesDelTutorial(context);
    } else if (!quiere && hojaAjustesAbierta) {
      hojaAjustesAbierta = false;
      // Solo se cierra si sigue abierta: maybePop() actúa sobre la ruta de
      // arriba de todo, y si el usuario ya la cerró cerraría la Home.
      Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  /// Abre la hoja de ajustes en modo tutorial y deja la capa del tutorial
  /// por encima para poder señalar lo que hay adentro.
  void abrirAjustesDelTutorial(BuildContext context) {
    final w = widget;
    final abierta = showSettingsSheet(
      context,
      username: w.username,
      isDark: Theme.of(context).brightness == Brightness.dark,
      onThemeChanged: w.onTemaCambiado ?? (_) {},
      onLanguageChanged: w.onIdiomaCambiado ?? () {},
      likedCount: '${w.cancionesAmadas}',
      downloadedCount: '${w.descargadosCount}',
      tutorial: tutorial,
    );
    tutorial?.traerCapaAlFrente();
    // Cuando la hoja se cierre (por el tutorial o por el usuario), se
    // destraba el flag para poder reabrirla si el tutorial vuelve atrás.
    abierta.whenComplete(() {
      if (mounted) hojaAjustesAbierta = false;
    });
  }
}
