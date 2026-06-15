import 'package:flutter_bloc/flutter_bloc.dart';
import 'appearance_event.dart';
import 'appearance_state.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/entities/appearance_settings.dart';

class AppearanceBloc extends Bloc<AppearanceEvent, AppearanceState> {
  final SettingsRepository _repository;

  AppearanceBloc(this._repository) : super(const AppearanceState()) {
    on<LoadAppearance>(_onLoad);
    on<UpdateThemeMode>(_onUpdateThemeMode);
    on<ToggleMaterialYou>(_onToggleMaterialYou);
    on<ToggleGlassEffects>(_onToggleGlassEffects);
    on<SaveAppearance>(_onSave);
  }

  Future<void> _onLoad(
      LoadAppearance event, Emitter<AppearanceState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final appSettings = await _repository.load();
      final current = AppearanceSettings(
        themeMode: appSettings.themeMode,
        useMaterialYou: false,
        useGlassEffects: true,
      );
      emit(state.copyWith(settings: current, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onUpdateThemeMode(
      UpdateThemeMode event, Emitter<AppearanceState> emit) {
    emit(state.copyWith(
      settings: state.settings.copyWith(themeMode: event.mode),
    ));
  }

  void _onToggleMaterialYou(
      ToggleMaterialYou event, Emitter<AppearanceState> emit) {
    emit(state.copyWith(
      settings: state.settings.copyWith(useMaterialYou: event.enabled),
    ));
  }

  void _onToggleGlassEffects(
      ToggleGlassEffects event, Emitter<AppearanceState> emit) {
    emit(state.copyWith(
      settings: state.settings.copyWith(useGlassEffects: event.enabled),
    ));
  }

  Future<void> _onSave(
      SaveAppearance event, Emitter<AppearanceState> emit) async {
    emit(state.copyWith(isSaving: true));
    try {
      final appSettings = await _repository.load();
      final updated = appSettings.copyWith(
        themeMode: state.settings.themeMode,
      );
      await _repository.save(updated);
      emit(state.copyWith(isSaving: false));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: e.toString()));
    }
  }
}
