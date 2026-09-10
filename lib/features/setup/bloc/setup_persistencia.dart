// ─────────────────────────────────────────────────────────────
// setup_persistencia.dart — PART de setup_manejadores.dart: lógica
// de persistencia del setup — guarda idioma/modo/usuario/código en
// CacheAjustes.completarSetup (preservando los timestamps del trial
// existente para no extenderlo reiniciando el setup) y activa el
// premium en CachePremium si hay código válido. Compartida por los
// manejadores onCompletarSetup y onVerificacionCompletada.
// Se conecta con: setup_manejadores.dart (misma library) + cache
// (ajustes/premium) + inyeccion.
// Parte del flujo: setup (completado / verificación exitosa).
// ─────────────────────────────────────────────────────────────

part of 'setup_manejadores.dart';

/// Guarda el setup (preservando el trial existente) y activa premium.
Future<void> _persistirSetup(EstadoSetup state) async {
  final codigo = state.codigoValido ? state.codigoPremium.trim() : null;
  await inj.sl<CacheAjustes>().completarSetup(
    locale: state.idiomaSeleccionado,
    mode: state.modoSeleccionado ?? 'free',
    username: state.usuario.trim(),
    codigoPremium: codigo,
    trialIniciadoEnExistente: state.trialExistenteIniciadoEn,
    trialExpiraEnExistente: state.trialExistenteExpiraEn,
  );
  if (codigo != null) {
    await inj.sl<CachePremium>().activarPremium(codigo);
  }
}