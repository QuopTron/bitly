import 'package:flutter_bloc/flutter_bloc.dart';
import 'settings_event.dart';
import 'settings_state.dart';
import '../../../domain/usecases/load_settings.dart';
import '../../../domain/usecases/save_settings.dart';
import '../../../domain/usecases/reset_settings.dart';
import '../../../domain/entities/app_settings.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final LoadSettings _loadSettings;
  final SaveSettings _saveSettings;
  final ResetSettings _resetSettings;

  SettingsBloc({
    required LoadSettings loadSettings,
    required SaveSettings saveSettings,
    required ResetSettings resetSettings,
  })  : _loadSettings = loadSettings,
        _saveSettings = saveSettings,
        _resetSettings = resetSettings,
        super(const SettingsState()) {
    on<LoadSettingsEvent>(_onLoad);
    on<SaveSettingsEvent>(_onSave);
    on<UpdateSettingsField>(_onUpdateField);
    on<ResetSettingsEvent>(_onReset);
  }

  Future<void> _onLoad(
      LoadSettingsEvent event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final settings = await _loadSettings.call();
      emit(state.copyWith(settings: settings, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onSave(
      SaveSettingsEvent event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isSaving: true, error: null));
    try {
      await _saveSettings.call(event.settings);
      emit(state.copyWith(settings: event.settings, isSaving: false, isDirty: false));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: e.toString()));
    }
  }

  void _onUpdateField(
      UpdateSettingsField event, Emitter<SettingsState> emit) {
    final updated = _applyField(state.settings, event.key, event.value);
    emit(state.copyWith(settings: updated, isDirty: true));
  }

  Future<void> _onReset(
      ResetSettingsEvent event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await _resetSettings.call();
      emit(state.copyWith(
        settings: const AppSettings(),
        isLoading: false,
        isDirty: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  AppSettings _applyField(AppSettings s, String key, dynamic value) {
    switch (key) {
      case 'username':
        return s.copyWith(username: value as String?);
      case 'language':
        return s.copyWith(language: value as String);
      case 'themeMode':
        return s.copyWith(themeMode: value as String);
      case 'loggingEnabled':
        return s.copyWith(loggingEnabled: value as bool);
      case 'downloadDirectory':
        return s.copyWith(downloadDirectory: value as String?);
      case 'maxConcurrentDownloads':
        return s.copyWith(maxConcurrentDownloads: value as int);
      case 'enableScrobbling':
        return s.copyWith(enableScrobbling: value as bool);
      case 'autoFetchLyrics':
        return s.copyWith(autoFetchLyrics: value as bool);
      default:
        return s;
    }
  }
}
