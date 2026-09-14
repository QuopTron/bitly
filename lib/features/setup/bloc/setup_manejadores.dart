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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/inyeccion.dart' as inj;
import '../../../core/backend_go/nucleo/contrato_backend.dart';
import '../../../core/cache/almacenes/cache_ajustes.dart';
import '../../../core/cache/almacenes/cache_premium.dart';
import '../../../core/servicios/proveedores/servicio_soulseek.dart';
import '../../../shared/utilidades/formato/nombres_aleatorios.dart';
import 'setup_estado.dart';
import 'setup_evento.dart';

part 'setup_persistencia.dart';
part 'setup_manejadores_avanzado.dart';

/// Manejadores del flujo de setup aplicados sobre el Bloc.
mixin ManejadoresSetup on Bloc<EventoSetup, EstadoSetup> {
  ValueNotifier<Locale> get notifierIdioma;

  /// Cliente de Soulseek (inyectable: los tests usan uno falso).
  ServicioSoulseek get servicioSoulseek;

  void onSeleccionarIdioma$(SeleccionarIdioma event, Emitter<EstadoSetup> emit) {
    notifierIdioma.value = Locale(event.locale);
    emit(state.copiarCon(idiomaSeleccionado: event.locale));
  }

  Future<void> onSiguientePaso$(SiguientePaso event, Emitter<EstadoSetup> emit) async {
    switch (state.paso) {
      case PasoSetup.idioma:
        emit(state.copiarCon(paso: PasoSetup.usuario));
      case PasoSetup.usuario:
        // El alta de Soulseek se intenta ANTES de avanzar. Si el nombre ya
        // está tomado en la red (o no es válido), el usuario tiene que elegir
        // otro ACÁ: si lo dejáramos pasar, terminaría el setup con una cuenta
        // que no existe y sin saber por qué. El avance lo dispara el
        // resultado, no este evento.
        // Un fallo que el usuario no puede resolver (sin internet, servidor
        // lleno) sí avanza: la bienvenida no depende de Soulseek.
        if (state.syncSoulseek == SyncSoulseek.creando) return; // ya corriendo
        add(IniciarSyncSoulseek(state.usuario));
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

  // ── Soulseek: alta de la cuenta con el nombre elegido ──

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