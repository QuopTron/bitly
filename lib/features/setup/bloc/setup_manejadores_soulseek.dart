// ─────────────────────────────────────────────────────────────
// setup_manejadores_soulseek.dart — PART de setup_manejadores.dart:
// mixin con el alta de la cuenta de Soulseek durante el setup —
// lanza la creación con el nombre elegido y decide, según el
// resultado, si se puede avanzar de paso o hay que corregir el
// nombre (ya tomado o inválido).
// Se conecta con: setup_bloc.dart (aplica el mixin) + servicio_soulseek.
// Parte del flujo: setup (alta silenciosa en Soulseek).
// ─────────────────────────────────────────────────────────────

part of 'setup_manejadores.dart';

/// Alta de la cuenta de Soulseek con el nombre elegido por el usuario.
mixin ManejadoresSoulseekSetup on Bloc<EventoSetup, EstadoSetup> {
  /// Cliente de Soulseek (inyectable: los tests usan uno falso).
  ServicioSoulseek get servicioSoulseek;

  /// Marca que el alta empezó y la lanza sin esperarla.
  void onIniciarSyncSoulseek$(
    IniciarSyncSoulseek event,
    Emitter<EstadoSetup> emit,
  ) {
    emit(state.copiarCon(syncSoulseek: SyncSoulseek.creando));
    unawaited(_crearCuentaSoulseek(event.usuario));
  }

  /// Crea/conecta la cuenta con el nombre que el usuario escribió.
  ///
  /// El resultado vuelve como EVENTO (y no como `emit` directo) para que el
  /// trabajo asíncrono no dependa de que este handler siga vivo.
  Future<void> _crearCuentaSoulseek(String usuario) async {
    try {
      final nombre = usuario.trim();
      if (nombre.isEmpty) {
        // Sin nombre no se inventa uno: se le pide al usuario.
        if (isClosed) return;
        add(const SoulseekSyncCompletada(
          ok: false,
          mensaje: 'escribí un nombre de usuario',
          motivo: 'nombre_invalido',
        ));
        return;
      }
      final resultado = await servicioSoulseek.crearOConectar(nombre);
      if (isClosed) return;
      add(SoulseekSyncCompletada(
        ok: resultado.ok,
        mensaje: resultado.mensaje,
        motivo: resultado.ok ? '' : resultado.motivoClave,
      ));
    } catch (e) {
      if (isClosed) return;
      // Falla del puente/red: no es algo que el usuario deba corregir.
      add(SoulseekSyncCompletada(ok: false, mensaje: 'Error: $e'));
    }
  }

  void onSoulseekSyncCompletada$(
    SoulseekSyncCompletada event,
    Emitter<EstadoSetup> emit,
  ) {
    emit(state.copiarCon(
      syncSoulseek: event.ok ? SyncSoulseek.listo : SyncSoulseek.fallo,
      mensajeSoulseek: event.mensaje,
      motivoSoulseek: event.motivo,
      // Solo se avanza si no queda nada que el usuario deba corregir.
      paso: (event.ok || !event.problemaDeNombre)
          ? PasoSetup.googleSignIn
          : state.paso,
    ));
  }
}
