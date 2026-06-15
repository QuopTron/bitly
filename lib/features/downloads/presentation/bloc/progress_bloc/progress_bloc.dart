import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'progress_event.dart';
import 'progress_state.dart';
import '../../../data/datasources/download_remote_source.dart';
import '../../../data/datasources/download_local_source.dart';
import '../../../data/models/download_progress_model.dart';

class ProgressBloc extends Bloc<ProgressEvent, ProgressState> {
  final DownloadRemoteSource _remoteSource;
  final DownloadLocalSource _localSource;
  Timer? _pollTimer;

  ProgressBloc(this._remoteSource, this._localSource)
      : super(const ProgressState()) {
    on<UpdateProgress>(_onUpdateProgress);
    on<StartMonitoring>(_onStartMonitoring);
    on<StopMonitoring>(_onStopMonitoring);
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }

  Future<void> _onUpdateProgress(
      UpdateProgress event, Emitter<ProgressState> emit) async {
    final updated = Map<String, DownloadProgressModel>.from(
        state.progress);
    updated[event.progress.itemId] = event.progress;
    await _localSource.saveProgress(event.progress);
    emit(state.copyWith(progress: updated));
  }

  Future<void> _onStartMonitoring(
      StartMonitoring event, Emitter<ProgressState> emit) async {
    final active = List<String>.from(state.activeDownloads);
    if (!active.contains(event.itemId)) {
      active.add(event.itemId);
    }
    emit(state.copyWith(activeDownloads: active));
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => _pollProgress(emit));
  }

  Future<void> _onStopMonitoring(
      StopMonitoring event, Emitter<ProgressState> emit) async {
    _pollTimer?.cancel();
    emit(state.copyWith(activeDownloads: []));
  }

  Future<void> _pollProgress(Emitter<ProgressState> emit) async {
    for (final id in state.activeDownloads) {
      try {
        final pct = await _remoteSource.getDownloadProgress(id);
        final progress = DownloadProgressModel.fromJson({
          'item_id': id,
          'bytes_downloaded': 0,
          'total_bytes': 0,
          'percentage': (pct * 100).toInt(),
          'speed': 0,
          'eta': 0,
        });
        add(UpdateProgress(progress));
      } catch (_) {}
    }
  }
}
