import 'package:flutter_bloc/flutter_bloc.dart';
import 'store_event.dart';
import 'store_state.dart';
import '../../../domain/usecases/browse_store.dart';

class StoreBloc extends Bloc<StoreEvent, StoreState> {
  final BrowseStore _browseStore;

  StoreBloc({required BrowseStore browseStore})
      : _browseStore = browseStore,
        super(const StoreState()) {
    on<LoadStoreExtensions>(_onLoad);
    on<SearchStore>(_onSearch);
    on<InstallFromStore>(_onInstall);
    on<LoadCategories>(_onLoadCategories);
  }

  Future<void> _onLoad(
      LoadStoreExtensions event, Emitter<StoreState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final extensions = await _browseStore.call(
        page: event.page,
        category: event.category,
      );
      emit(state.copyWith(
        extensions: extensions,
        isLoading: false,
        currentPage: event.page,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onSearch(
      SearchStore event, Emitter<StoreState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final extensions = await _browseStore.search(event.query);
      emit(state.copyWith(extensions: extensions, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onInstall(
      InstallFromStore event, Emitter<StoreState> emit) async {
    try {
      await _browseStore.downloadAndInstall(event.storeId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onLoadCategories(
      LoadCategories event, Emitter<StoreState> emit) async {
    try {
      final categories = await _browseStore.getCategories();
      emit(state.copyWith(categories: categories));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
