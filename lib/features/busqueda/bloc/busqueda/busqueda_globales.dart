// ─────────────────────────────────────────────────────────────
// busqueda_globales.dart — PART de busqueda_bloc.dart: globales del
// bloc de búsqueda — el logger, el set de fuentes cuyas BÚSQUEDAS
// exigen sesión firmada (qobuz/tidal/amazon; deezer y pandora buscan
// anónimo) y el enum con el resultado de intentar verificarlas.
// Se conecta con: busqueda_bloc.dart (misma library) +
// servicio_verificacion (registry de fuentes).
// Parte del flujo: búsqueda (sesiones firmadas).
// ─────────────────────────────────────────────────────────────

part of '../base/busqueda_bloc.dart';

final _log = Logger();

/// Fuentes cuyas BÚSQUEDAS exigen sesión firmada del gateway, según el registry
/// de ServicioVerificacion (la fuente de verdad). Deezer/pandora buscan
/// anónimo: ahí un vacío es rate-limit o "sin resultados", nunca de sesión.
///
/// HOY ESTÁ VACÍO a propósito (ver el doc de ServicioVerificacion.
/// fuentesSesionFirmada): ninguna fuente depende del gateway, así que el camino
/// de verificación queda como plomería lista para reactivarse, no como una
/// compensación activa. Por eso una búsqueda vacía ya NO se reintenta a ciegas:
/// cuando esta lista tenía entradas, el reintento tapaba el warm-up de la sesión
/// firmada; sin entradas solo duplicaba el trabajo de todos los proveedores.
final _fuentesVerificarAlVacio = <String>{
  ...ServicioVerificacion.fuentesSesionFirmada,
}..removeAll(const {'deezer', 'pandora'});

/// Resultado de intentar verificar una fuente con sesión firmada.
enum _ResultadoVerificacion { verificada, noNecesaria, fallida }
