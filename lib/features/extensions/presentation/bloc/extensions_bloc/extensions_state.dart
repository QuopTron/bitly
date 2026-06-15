import 'package:equatable/equatable.dart';
import '../../../domain/entities/extension.dart';

class ExtensionsState extends Equatable {
  final List<Extension> extensions;
  final bool isLoading;
  final String? error;

  const ExtensionsState({
    this.extensions = const [],
    this.isLoading = false,
    this.error,
  });

  ExtensionsState copyWith({
    List<Extension>? extensions,
    bool? isLoading,
    String? error,
  }) =>
      ExtensionsState(
        extensions: extensions ?? this.extensions,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  @override
  List<Object?> get props => [extensions, isLoading, error];
}
