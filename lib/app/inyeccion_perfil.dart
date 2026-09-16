// ─────────────────────────────────────────────────────────────
// inyeccion_perfil.dart — PART de inyeccion.dart: lectura del perfil
// de rendimiento (gama del equipo) y su empuje al backend Go.
//
// Se conecta con: inyeccion.dart (misma library).
// Parte del flujo: arranque (adaptación al equipo).
// ─────────────────────────────────────────────────────────────

part of 'inyeccion.dart';

/// Carga el perfil de rendimiento guardado al notificador global.
/// IMPORTANTE: solo llamar DESPUÉS de que el backend Go esté inicializado
/// (healthCheck) — el push del perfil es un RPC y antes del init puede
/// bloquear el bridge nativo y colgar el splash.
Future<void> cargarPerfilRendimiento() async {
  final cache = sl<CacheAjustes>();
  // Sin elección guardada, `getNivelRendimiento` DETECTA la gama del equipo:
  // un celular de gama baja (Helio G, 4 núcleos / ≤3,3 GB) entra en "bajo" y
  // arranca sin desenfoques ni precarga, que es lo que lo congelaba.
  final nivel = await cache.getNivelRendimiento();
  final perfil = PerfilRendimiento.paraNivel(nivel);
  sl<ValueNotifier<PerfilRendimiento>>().value = perfil;
  // Interruptor global del coste visual: lo leen contenedor_vidrio, los
  // desenfoques de hojas/reproductor y el fondo ambiente. Se aplica ANTES de
  // montar la UI, así el primer frame ya nace liviano.
  EfectosApp.aplicar(
    efectosPesados: perfil.efectosPesados,
    sigmaMax: perfil.sigmaDesenfoque,
  );
}

/// Empuja el perfil de rendimiento cargado al backend Go. Llamar después
/// del healthCheck (runtime Go arriba) para que el RPC devuelva al instante
/// en vez de encolarse detrás del init nativo.
Future<void> empujarPerfilRendimientoABackend() async {
  final perfil = sl<ValueNotifier<PerfilRendimiento>>().value;
  try {
    (sl<BackendService>()).syncBackendConfig(
      mode: perfil.nivel.clave,
      streamCacheMaxMb: perfil.cacheStreamingMaxMb,
      downloadConcurrency: perfil.concurrenciaDescargas,
      streamChunkSize: perfil.tamanoChunkStreaming,
    );
  } catch (e) { debugPrint("[App] $e"); }
}
