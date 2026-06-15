import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/home_repository.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeRepository _repository;

  HomeBloc({HomeRepository? repository})
      : _repository = repository ?? HomeRepository(),
        super(const HomeState()) {
    on<LoadHome>(_onLoadHome);
    on<RefreshHome>(_onRefreshHome);
  }

  Future<void> _onLoadHome(LoadHome event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final sections = await _repository.getHomeSections();
      emit(state.copyWith(sections: sections, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Error al cargar la página principal',
      ));
    }
  }

  Future<void> _onRefreshHome(
    RefreshHome event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final sections = await _repository.getHomeSections();
      emit(state.copyWith(sections: sections, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }
}
