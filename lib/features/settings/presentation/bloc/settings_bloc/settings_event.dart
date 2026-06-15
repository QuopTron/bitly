import 'package:equatable/equatable.dart';
import '../../../domain/entities/app_settings.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettingsEvent extends SettingsEvent {}

class SaveSettingsEvent extends SettingsEvent {
  final AppSettings settings;

  const SaveSettingsEvent(this.settings);

  @override
  List<Object?> get props => [settings];
}

class UpdateSettingsField extends SettingsEvent {
  final String key;
  final dynamic value;

  const UpdateSettingsField(this.key, this.value);

  @override
  List<Object?> get props => [key, value];
}

class ResetSettingsEvent extends SettingsEvent {}
