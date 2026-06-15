import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'scan_event.dart';
import 'scan_state.dart';
import '../../../domain/usecases/scan_library.dart';

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final ScanLibrary _scanLibrary;
  Timer? _pollTimer;

  ScanBloc()
      : _scanLibrary = GetIt.instance<ScanLibrary>(),
        super(const ScanState()) {
    on<StartScan>(_onStartScan);
    on<CancelScan>(_onCancelScan);
    on<UpdateProgress>(_onUpdateProgress);
    on<CheckStatus>(_onCheckStatus);
  }

  Future<void> _onStartScan(StartScan event, Emitter<ScanState> emit) async {
    emit(state.copyWith(isScanning: true, error: null));
    try {
      await _scanLibrary.call(event.path);
      _startPolling(emit);
    } catch (e) {
      emit(state.copyWith(isScanning: false, error: e.toString()));
    }
  }

  Future<void> _onCancelScan(CancelScan event, Emitter<ScanState> emit) async {
    _pollTimer?.cancel();
    await _scanLibrary.cancel();
    emit(state.copyWith(isScanning: false));
  }

  void _onUpdateProgress(UpdateProgress event, Emitter<ScanState> emit) {
    emit(state.copyWith(
      progress: event.progress,
      isScanning: event.progress.isScanning,
    ));
    if (!event.progress.isScanning) {
      _pollTimer?.cancel();
    }
  }

  Future<void> _onCheckStatus(CheckStatus event, Emitter<ScanState> emit) async {
    try {
      final progress = await _scanLibrary.getProgress();
      add(UpdateProgress(progress));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _startPolling(Emitter<ScanState> emit) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(CheckStatus());
    });
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
