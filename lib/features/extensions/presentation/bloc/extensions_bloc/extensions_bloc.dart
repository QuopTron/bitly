import 'package:flutter_bloc/flutter_bloc.dart';
import 'extensions_event.dart';
import 'extensions_state.dart';
import '../../../domain/usecases/get_installed_extensions.dart';
import '../../../domain/usecases/toggle_extension.dart';
import '../../../domain/usecases/install_extension.dart';
import '../../../domain/usecases/remove_extension.dart';

class ExtensionsBloc extends Bloc<ExtensionsEvent, ExtensionsState> {
  final GetInstalledExtensions _getInstalled;
  final ToggleExtension _toggleExtension;
  final InstallExtension _installExtension;
  final RemoveExtension _removeExtension;

  ExtensionsBloc({
    required GetInstalledExtensions getInstalled,
    required ToggleExtension toggleExtension,
    required InstallExtension installExtension,
    required RemoveExtension removeExtension,
  })  : _getInstalled = getInstalled,
        _toggleExtension = toggleExtension,
        _installExtension = installExtension,
        _removeExtension = removeExtension,
        super(const ExtensionsState()) {
    on<LoadExtensions>(_onLoad);
    on<ToggleExtensionEvent>(_onToggle);
    on<InstallExtensionEvent>(_onInstall);
    on<RemoveExtensionEvent>(_onRemove);
  }

  Future<void> _onLoad(
      LoadExtensions event, Emitter<ExtensionsState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final extensions = await _getInstalled.call();
      emit(state.copyWith(extensions: extensions, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onToggle(
      ToggleExtensionEvent event, Emitter<ExtensionsState> emit) async {
    try {
      await _toggleExtension.call(event.id, event.enabled);
      final extensions = await _getInstalled.call();
      emit(state.copyWith(extensions: extensions));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onInstall(
      InstallExtensionEvent event, Emitter<ExtensionsState> emit) async {
    try {
      await _installExtension.call(event.path);
      final extensions = await _getInstalled.call();
      emit(state.copyWith(extensions: extensions));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onRemove(
      RemoveExtensionEvent event, Emitter<ExtensionsState> emit) async {
    try {
      await _removeExtension.call(event.id);
      final extensions = await _getInstalled.call();
      emit(state.copyWith(extensions: extensions));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
