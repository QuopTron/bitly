import 'package:equatable/equatable.dart';
import '../../../domain/entities/app_settings.dart';

class SettingsState extends Equatable {
  final AppSettings settings;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final bool isDirty;

  const SettingsState({
    this.settings = const AppSettings(),
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.isDirty = false,
  });

  SettingsState copyWith({
    AppSettings? settings,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool? isDirty,
  }) =>
      SettingsState(
        settings: settings ?? this.settings,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: error,
        isDirty: isDirty ?? this.isDirty,
      );

  @override
  List<Object?> get props => [settings, isLoading, isSaving, error, isDirty];
}
