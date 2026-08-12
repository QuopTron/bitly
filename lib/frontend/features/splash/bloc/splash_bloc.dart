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
    try {
      final ok = await _backend.healthCheck();
      if (ok) {
        emit(const SplashState(status: SplashStatus.connected));
      } else {
        emit(const SplashState(
          status: SplashStatus.error,
          error: 'Backend no responde',
        ));
      }
    } catch (e) {
      emit(SplashState(
        status: SplashStatus.error,
        error: 'Error de conexión: $e',
      ));
    }
  }
}


