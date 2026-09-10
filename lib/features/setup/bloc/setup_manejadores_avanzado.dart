// ─────────────────────────────────────────────────────────────
// setup_manejadores_avanzado.dart — PART de setup_manejadores.dart:
// mixin con los manejadores ASYNC del setup: validación del código
// premium contra Go (validatePremiumCode), completado del setup,
// chequeo de datos existentes para el prompt de reingreso (detecta
// también un token OAuth guardado para marcar Google como conectado)
// y la verificación exitosa de fuentes. Comparte _persistirSetup
// con el mixin base vía part.
// Se conecta con: setup_bloc.dart (aplica el mixin) + backend_go +
// cache (ajustes/premium) + inyeccion.
// Parte del flujo: setup (validación, reingreso, verificación).
// ─────────────────────────────────────────────────────────────

part of 'setup_manejadores.dart';

/// Manejadores asíncronos del setup aplicados sobre el Bloc.
/// Requiere el mixin base (ManejadoresSetup) por su getter notifierIdioma.
mixin ManejadoresSetupAvanzado on ManejadoresSetup {
  Future<void> onValidarCodigoPremium$(
    ValidarCodigoPremium event,
    Emitter<EstadoSetup> emit,
  ) async {
    if (state.codigoPremium.trim().isEmpty) return;
    emit(state.copiarCon(validandoCodigo: true, codigoValido: false, errorCodigo: null));
    final error = await inj.sl<BackendService>()
        .validatePremiumCode(state.codigoPremium.trim());
    if (error == null) {
      emit(state.copiarCon(validandoCodigo: false, codigoValido: true, errorCodigo: null));
    } else {
      emit(state.copiarCon(validandoCodigo: false, codigoValido: false, errorCodigo: error));
    }
  }

  Future<void> onCompletarSetup$(
    CompletarSetup event,
    Emitter<EstadoSetup> emit,
  ) async {
    if (state.modoSeleccionado == null || state.usuario.trim().isEmpty) return;
    if (state.modoSeleccionado == 'premium' && !state.codigoValido) return;
    emit(state.copiarCon(guardando: true, paso: PasoSetup.gracias));
    await _persistirSetup(state);
    emit(state.copiarCon(guardando: false));
  }

  Future<void> onChequearDatosExistentes$(
    ChequearDatosExistentes event,
    Emitter<EstadoSetup> emit,
  ) async {
    try {
      final data = await inj.sl<CacheAjustes>().cargarDatosSetup();
      // Un token OAuth de Google guardado (de una sesión previa) significa
      // que el usuario ya conectó: se refleja en el slide y se salta el login.
      final tokenGuardado = (await inj.sl<CacheAjustes>()
                  .getAjuste('ytmusic-spotiflac_oauthAccessToken') ??
              '')
          .trim();
      final googleConectado = tokenGuardado.isNotEmpty;
      if (data != null && data.setupCompletado) {
        notifierIdioma.value = Locale(data.locale);
        emit(state.copiarCon(
          paso: PasoSetup.promptReingreso,
          tieneDatosExistentes: true,
          googleConectado: googleConectado,
          idiomaExistente: data.locale,
          modoExistente: data.mode,
          usuarioExistente: data.username,
          trialExistenteExpirado: data.trialExpirado,
          trialExistenteIniciadoEn: data.trialIniciadoEn,
          trialExistenteExpiraEn: data.trialExpiraEn,
        ));
      } else {
        emit(state.copiarCon(
          paso: PasoSetup.idioma,
          tieneDatosExistentes: false,
          googleConectado: googleConectado,
        ));
      }
    } catch (_) {
      emit(state.copiarCon(paso: PasoSetup.idioma, tieneDatosExistentes: false));
    }
  }

  void onAceptarDatosExistentes$(
    AceptarDatosExistentes event,
    Emitter<EstadoSetup> emit,
  ) {
    if (event.aceptar) {
      if (state.idiomaExistente != null) {
        notifierIdioma.value = Locale(state.idiomaExistente!);
      }
      emit(state.copiarCon(
        continuarConExistentes: true,
        paso: PasoSetup.gracias,
      ));
    } else {
      emit(state.copiarCon(
        continuarConExistentes: false,
        idiomaSeleccionado: state.idiomaExistente ?? state.idiomaSeleccionado,
        usuario: state.usuarioExistente ?? '',
        paso: PasoSetup.idioma,
      ));
    }
  }

  Future<void> onVerificacionCompletada$(
    VerificacionCompletada event,
    Emitter<EstadoSetup> emit,
  ) async {
    if (!event.exito) return;
    emit(state.copiarCon(guardando: true));
    // Guarda el setup con el código premium (si aplica) y continúa a los
    // tutoriales (feed/search) que ya cargan con las fuentes verificadas.
    await _persistirSetup(state);
    emit(state.copiarCon(guardando: false, paso: PasoSetup.carpetaAlmacenamiento));
  }
}