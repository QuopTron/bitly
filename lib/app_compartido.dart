// ─────────────────────────────────────────────────────────────
// app_compartido.dart — PART de app.dart: acciones de la carta "te
// compartieron" (reproducir o encolar) y si hay algo sonando.
//
// Vive en un mixin para que el estado raíz solo conecte las piezas:
// la decisión de "reproducir" o "agregar a la cola" según la cola
// actual se resuelve acá.
//
// Se conecta con: app.dart (misma library).
// Parte del flujo: enlace compartido → carta → reproducción/cola.
// ─────────────────────────────────────────────────────────────

part of 'app.dart';

/// Acciones del overlay de compartidos, conectadas al estado raíz.
mixin ManejadoresCompartidos on State<BitlyApp> {
  /// Router de la app (lo provee el estado).
  GoRouter get routerCompartido;

  /// Enlace compartido abierto, si hay uno.
  DatosDeepLink? get linkCompartidoPendiente;

  /// Cierra la carta.
  void limpiarCompartido();

  /// Reproduce un enlace ya resuelto: lo encola y lleva al home para ver
  /// el miniplayer (delegando en el helper global).
  void reproducirResueltoCompartido(ResultadoEnlace resuelto) {
    if (!mounted) return;
    reproducirEnlaceApp(
      resuelto: resuelto,
      router: routerCompartido,
      limpiarLink: limpiarCompartido,
    );
  }

  /// ¿Hay algo sonando ya? Decide si el botón dice "Reproducir" o
  /// "Agregar a la cola".
  bool get hayReproduccion {
    try {
      return di.sl<CubitCola>().state.tieneActual;
    } catch (_) {
      return false;
    }
  }

  /// Botón "Reproducir" de la carta: resuelve el enlace y reproduce.
  Future<void> reproducirCompartido() async {
    await reproducirCompartidoApp(
      link: linkCompartidoPendiente,
      router: routerCompartido,
      limpiarLink: limpiarCompartido,
      onResuelto: reproducirResueltoCompartido,
    );
  }

  /// Botón "Agregar a la cola": resuelve el enlace y lo encola al final sin
  /// cortar lo que está sonando.
  Future<void> agregarCompartidoALaCola() async {
    await reproducirCompartidoApp(
      link: linkCompartidoPendiente,
      router: routerCompartido,
      limpiarLink: limpiarCompartido,
      onResuelto: reproducirResueltoCompartido,
      modo: ModoCompartido.encolar,
    );
  }
}
