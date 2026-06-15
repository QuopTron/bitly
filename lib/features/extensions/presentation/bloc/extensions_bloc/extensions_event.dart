import 'package:equatable/equatable.dart';

abstract class ExtensionsEvent extends Equatable {
  const ExtensionsEvent();

  @override
  List<Object?> get props => [];
}

class LoadExtensions extends ExtensionsEvent {}

class ToggleExtensionEvent extends ExtensionsEvent {
  final String id;
  final bool enabled;

  const ToggleExtensionEvent(this.id, this.enabled);

  @override
  List<Object?> get props => [id, enabled];
}

class InstallExtensionEvent extends ExtensionsEvent {
  final String path;

  const InstallExtensionEvent(this.path);

  @override
  List<Object?> get props => [path];
}

class RemoveExtensionEvent extends ExtensionsEvent {
  final String id;

  const RemoveExtensionEvent(this.id);

  @override
  List<Object?> get props => [id];
}
