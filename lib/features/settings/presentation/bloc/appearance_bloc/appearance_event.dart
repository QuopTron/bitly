import 'package:equatable/equatable.dart';

abstract class AppearanceEvent extends Equatable {
  const AppearanceEvent();

  @override
  List<Object?> get props => [];
}

class LoadAppearance extends AppearanceEvent {}

class UpdateThemeMode extends AppearanceEvent {
  final String mode;
  const UpdateThemeMode(this.mode);

  @override
  List<Object?> get props => [mode];
}

class ToggleMaterialYou extends AppearanceEvent {
  final bool enabled;
  const ToggleMaterialYou(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ToggleGlassEffects extends AppearanceEvent {
  final bool enabled;
  const ToggleGlassEffects(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class SaveAppearance extends AppearanceEvent {}
