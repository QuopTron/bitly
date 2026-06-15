import 'package:equatable/equatable.dart';
import '../../../domain/entities/store_extension.dart';

class StoreState extends Equatable {
  final List<StoreExtension> extensions;
  final List<String> categories;
  final bool isLoading;
  final String? error;
  final int currentPage;

  const StoreState({
    this.extensions = const [],
    this.categories = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 0,
  });

  StoreState copyWith({
    List<StoreExtension>? extensions,
    List<String>? categories,
    bool? isLoading,
    String? error,
    int? currentPage,
  }) =>
      StoreState(
        extensions: extensions ?? this.extensions,
        categories: categories ?? this.categories,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        currentPage: currentPage ?? this.currentPage,
      );

  @override
  List<Object?> get props =>
      [extensions, categories, isLoading, error, currentPage];
}
