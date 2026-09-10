// ─────────────────────────────────────────────────────────────
// setup_manejadores.dart — Mixin de manejadores del bloc de setup:
// lógica de navegación de pasos (siguiente/anterior), selección de
// idioma/usuario/modo, validación del código premium (validatePremiumCode
// de Go), completado del setup (CacheAjustes.completarSetup +
// CachePremium.activarPremium) y el chequeo de datos existentes para
// el prompt de "¿Continuar con tu cuenta?".
// Se conecta con: setup_bloc.dart (aplica el mixin) + backend_go +
// cache (ajustes/premium) + inyeccion.
// Parte del flujo: setup (flujo de bienvenida).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/inyeccion.dart' as inj;
import '../../../core/backend_go/contrato_backend.dart';
import '../../../core/cache/cache_ajustes.dart';
import '../../../core/cache/cache_premium.dart';
import '../../../shared/utilidades/nombres_aleatorios.dart';
import 'setup_estado.dart';
import 'setup_evento.dart';

part 'setup_persistencia.dart';
part 'setup_manejadores_avanzado.dart';

/// Manejadores del flujo de setup aplicados sobre el Bloc.
mixin ManejadoresSetup on Bloc<EventoSetup, EstadoSetup> {
  ValueNotifier<Locale> get notifierIdioma;

  void onSeleccionarIdioma$(SeleccionarIdioma event, Emitter<EstadoSetup> emit) {
    notifierIdioma.value = Locale(event.locale);
    emit(state.copiarCon(idiomaSeleccionado: event.locale));
  }

  Future<void> onSiguientePaso$(SiguientePaso event, Emitter<EstadoSetup> emit) async {
    switch (state.paso) {
      case PasoSetup.idioma:
        emit(state.copiarCon(paso: PasoSetup.usuario));
      case PasoSetup.usuario:
        emit(state.copiarCon(paso: PasoSetup.googleSignIn));
      case PasoSetup.googleSignIn:
        emit(state.copiarCon(paso: PasoSetup.modo));
      case PasoSetup.modo:
        // El paso de verificación de fuentes firma las sesiones de las
        // extensiones (Deezer, Qobuz, TIDAL...). Se muestra en el setup en
        // AMBAS plataformas: cada proveedor que lo necesite abre su sandbox
        // in-app; el usuario puede continuar/omitir al terminar.
        emit(state.copiarCon(paso: PasoSetup.verificacion));
      case PasoSetup.verificacion:
        // VerificacionCompletada (desde el slide) persiste el setup al salir.
        emit(state.copiarCon(paso: PasoSetup.carpetaAlmacenamiento));
      case PasoSetup.carpetaAlmacenamiento:
        emit(state.copiarCon(paso: PasoSetup.notificaciones));
      case PasoSetup.notificaciones:
        emit(state.copiarCon(paso: PasoSetup.gracias));
      default:
    }
  }

  void onPasoAnterior$(PasoAnterior event, Emitter<EstadoSetup> emit) {
    switch (state.paso) {
      case PasoSetup.gracias:
        emit(state.copiarCon(paso: PasoSetup.notificaciones));
      case PasoSetup.notificaciones:
        emit(state.copiarCon(paso: PasoSetup.carpetaAlmacenamiento));
      case PasoSetup.carpetaAlmacenamiento:
        emit(state.copiarCon(paso: PasoSetup.verificacion));
      case PasoSetup.verificacion:
        emit(state.copiarCon(paso: PasoSetup.modo));
      case PasoSetup.modo:
        emit(state.copiarCon(paso: PasoSetup.googleSignIn));
      case PasoSetup.googleSignIn:
        emit(state.copiarCon(paso: PasoSetup.usuario));
      case PasoSetup.usuario:
        emit(state.copiarCon(paso: PasoSetup.idioma));
      default:
    }
  }

  void onEstadoGoogleCambiado$(
    EstadoGoogleCambiado event,
    Emitter<EstadoSetup> emit,
  ) {
    emit(state.copiarCon(googleConectado: event.conectado));
  }

  void onUsuarioCambiado$(UsuarioCambiado event, Emitter<EstadoSetup> emit) {
    emit(state.copiarCon(usuario: event.usuario));
  }

  void onGenerarNombreAleatorio$(
    GenerarNombreAleatorio event,
    Emitter<EstadoSetup> emit,
  ) {
    final nombre = nombresAleatorios[
        DateTime.now().millisecondsSinceEpoch % nombresAleatorios.length];
    emit(state.copiarCon(usuario: nombre));
  }

  void onSeleccionarModo$(SeleccionarModo event, Emitter<EstadoSetup> emit) {
    emit(state.copiarCon(
      modoSeleccionado: event.modo,
      codigoValido: false,
      errorCodigo: null,
      codigoPremium: '',
    ));
  }

  void onCodigoPremiumCambiado$(
    CodigoPremiumCambiado event,
    Emitter<EstadoSetup> emit,
  ) {
    emit(state.copiarCon(
      codigoPremium: event.codigo,
      codigoValido: false,
      errorCodigo: null,
    ));
  }

}