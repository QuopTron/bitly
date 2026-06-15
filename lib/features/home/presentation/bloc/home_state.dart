import 'package:equatable/equatable.dart';
import '../../domain/entities/home_section.dart';

class HomeState extends Equatable {
  final List<HomeSection> sections;
  final bool isLoading;
  final String? error;

  const HomeState({
    this.sections = const [],
    this.isLoading = false,
    this.error,
  });

  HomeState copyWith({
    List<HomeSection>? sections,
    bool? isLoading,
    String? error,
  }) {
    return HomeState(
      sections: sections ?? this.sections,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [sections, isLoading, error];
}
