// ─────────────────────────────────────────────────────────────
// busqueda_globales.dart — PART de busqueda_bloc.dart: globales del
// bloc de búsqueda — el logger, el set de fuentes cuyas BÚSQUEDAS
// exigen sesión firmada (qobuz/tidal/amazon; deezer y pandora buscan
// anónimo) y el enum con el resultado de intentar verificarlas.
// Se conecta con: busqueda_bloc.dart (misma library) +
// servicio_verificacion (registry de fuentes).
// Parte del flujo: búsqueda (sesiones firmadas).
// ─────────────────────────────────────────────────────────────

part of 'busqueda_bloc.dart';

final _log = Logger();

/// Fuentes cuyas BÚSQUEDAS requieren sesión firmada (el registry de
/// ServicioVerificacion es la fuente de verdad): qobuz-web da 403 y amazon
/// devuelve 0 sin verificar; tidal-web también pide sesión. Deezer/pandora
/// buscan anónimo — vacío ahí es rate-limit o "sin resultados", nunca un
/// problema de sesión.
final _fuentesVerificarAlVacio = <String>{
  ...ServicioVerificacion.fuentesSesionFirmada,
}..removeAll(const {'deezer', 'pandora'});

/// Resultado de intentar verificar una fuente con sesión firmada.
enum _ResultadoVerificacion { verificada, noNecesaria, fallida }
