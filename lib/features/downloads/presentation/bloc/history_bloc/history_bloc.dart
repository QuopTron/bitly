import 'package:flutter_bloc/flutter_bloc.dart';
import 'history_event.dart';
import 'history_state.dart';
import '../../../data/repositories/download_repository.dart';

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final DownloadRepository _repository;

  HistoryBloc(this._repository) : super(const HistoryState()) {
    on<LoadHistory>(_onLoadHistory);
    on<ClearHistory>(_onClearHistory);
    on<RetryDownloadEvent>(_onRetryDownload);
    on<DeleteFromHistory>(_onDeleteFromHistory);
  }

  Future<void> _onLoadHistory(
      LoadHistory event, Emitter<HistoryState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final items = await _repository.getHistory();
      emit(state.copyWith(items: items, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onClearHistory(
      ClearHistory event, Emitter<HistoryState> emit) async {
    try {
      await _repository.clearHistory();
      emit(state.copyWith(items: []));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onRetryDownload(
      RetryDownloadEvent event, Emitter<HistoryState> emit) async {
    try {
      // Re-download logic would go here
      emit(state.copyWith(error: 'Retry not yet implemented'));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleteFromHistory(
      DeleteFromHistory event, Emitter<HistoryState> emit) async {
    try {
      final items = await _repository.getHistory();
      items.removeWhere((e) => e.id == event.downloadId);
      await _repository.clearHistory();
      for (final item in items) {
        await _repository.addToQueue(item);
      }
      emit(state.copyWith(items: []));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
