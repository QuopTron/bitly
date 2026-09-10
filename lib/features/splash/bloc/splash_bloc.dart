// ─────────────────────────────────────────────────────────────
// splash_bloc.dart — Bloc del splash: chequea la salud del backend
// Go (healthCheck) con reintento automático con backoff (3 intentos)
// porque el arranque en frío del runtime Go + motores JS de
// extensiones puede tardar decenas de segundos en dispositivos
// lentos. Emite conectado/error para que la página navegue.
// Se conecta con: backend_go (healthCheck) + splash_estado/evento.
// Parte del flujo: splash (chequeo del backend al arrancar).
// ─────────────────────────────────────────────────────────────

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/backend_go/contrato_backend.dart';
import 'splash_estado.dart';
import 'splash_evento.dart';

/// Bloc de arranque: verifica que el backend Go responde.
class SplashBloc extends Bloc<EventoSplash, EstadoSplash> {
  final BackendService _backend;

  SplashBloc(this._backend) : super(const EstadoSplash()) {
    on<ChequearBackend>(_onChequearBackend);
  }

  Future<void> _onChequearBackend(
    ChequearBackend event,
    Emitter<EstadoSplash> emit,
  ) async {
    emit(const EstadoSplash(status: EstatusSplash.cargando));
    // El init en frío de Go (runtime + todos los motores JS de extensiones)
    // puede tardar decenas de segundos en dispositivos lentos, y un primer
    // intento transitorio a veces falla mientras el emulador/celular aún
    // despierta. El "Reintentar" manual siempre funciona porque ya está
    // caliente, así que se reintenta con backoff antes de mostrar el error.
    const intentos = 3;
    for (var intento = 1; intento <= intentos; intento++) {
      try {
        // Cubre todo el pipeline de healthCheck: initGoBackend espera hasta
        // 120s del lado nativo (runtime Go + motores), y luego el sistema de
        // extensiones + load tienen presupuestos propios de 30s. 200s
        // garantiza que el primer intento complete un arranque en frío lento.
        final ok = await _backend
            .healthCheck()
            .timeout(const Duration(seconds: 200));
        if (ok) {
          emit(const EstadoSplash(status: EstatusSplash.conectado));
          return;
        }
      } catch (_) {
        // Fallo transitorio de init — continúa al siguiente intento.
      }
      if (intento < intentos) {
        await Future<void>.delayed(Duration(milliseconds: 500 * intento));
      }
    }
    emit(const EstadoSplash(
      status: EstatusSplash.error,
      error: 'Backend no responde',
    ));
  }
}