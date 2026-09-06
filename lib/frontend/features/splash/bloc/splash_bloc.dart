import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/rpc/backend_service.dart';
import 'splash_event.dart';
import 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  final BackendService _backend;

  SplashBloc(this._backend) : super(const SplashState()) {
    on<CheckBackend>(_onCheckBackend);
  }

  Future<void> _onCheckBackend(
    CheckBackend event,
    Emitter<SplashState> emit,
  ) async {
    emit(const SplashState(status: SplashStatus.loading));
    // Cold-start Go init (loading the runtime + all extension JS engines) can
    // take tens of seconds on slow devices, and a transient first attempt
    // occasionally fails while the emulator/phone is still waking up. The
    // manual "Reintentar" always succeeds because everything is warm by then,
    // so auto-retry with backoff instead of showing the error immediately.
    const attempts = 3;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        // Must cover the full healthCheck pipeline: initGoBackend waits up to
        // 120s native-side (Go runtime + all extension engines), then extension
        // system + load have their own 30s budgets each. 200s guarantees the
        // first attempt can complete a slow cold start instead of timing out
        // and forcing the user to hit "Reintentar".
        final ok = await _backend
            .healthCheck()
            .timeout(const Duration(seconds: 200));
        if (ok) {
          emit(const SplashState(status: SplashStatus.connected));
          return;
        }
      } catch (_) {
        // transient init failure — fall through to the next attempt
      }
      if (attempt < attempts) {
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    emit(const SplashState(
      status: SplashStatus.error,
      error: 'Backend no responde',
    ));
  }
}


