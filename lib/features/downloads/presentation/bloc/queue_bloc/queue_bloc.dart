import 'package:flutter_bloc/flutter_bloc.dart';
import 'queue_event.dart';
import 'queue_state.dart';
import '../../../data/repositories/queue_repository.dart';

class QueueBloc extends Bloc<QueueEvent, QueueState> {
  final QueueRepository _repository;

  QueueBloc(this._repository) : super(const QueueState()) {
    on<LoadQueue>(_onLoadQueue);
    on<AddToQueueEvent>(_onAddToQueue);
    on<RemoveFromQueue>(_onRemoveFromQueue);
    on<ClearQueue>(_onClearQueue);
    on<ReorderQueue>(_onReorder);
  }

  Future<void> _onLoadQueue(
      LoadQueue event, Emitter<QueueState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final items = await _repository.getQueue();
      emit(state.copyWith(items: items, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onAddToQueue(
      AddToQueueEvent event, Emitter<QueueState> emit) async {
    try {
      await _repository.addToQueue(event.item);
      final items = await _repository.getQueue();
      emit(state.copyWith(items: items));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onRemoveFromQueue(
      RemoveFromQueue event, Emitter<QueueState> emit) async {
    try {
      await _repository.removeFromQueue(event.itemId);
      final items = await _repository.getQueue();
      emit(state.copyWith(items: items));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onClearQueue(
      ClearQueue event, Emitter<QueueState> emit) async {
    try {
      await _repository.clearQueue();
      emit(state.copyWith(items: []));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onReorder(
      ReorderQueue event, Emitter<QueueState> emit) async {
    try {
      await _repository.reorder(event.oldIndex, event.newIndex);
      final items = await _repository.getQueue();
      emit(state.copyWith(items: items));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
