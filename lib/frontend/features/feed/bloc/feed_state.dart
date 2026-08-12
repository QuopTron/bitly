import 'package:equatable/equatable.dart';
import '../../../shared/models/feed_models.dart';

class FeedState extends Equatable {
  final List<FeedSection> sections;
  final Set<String> likedIds;
  final bool loading;
  final String? error;
  final String username;
  final String selectedSource;

  const FeedState({
    this.sections = const [],
    this.likedIds = const {},
    this.loading = false,
    this.error,
    this.username = '',
    this.selectedSource = '',
  });

  FeedState copyWith({
    List<FeedSection>? sections,
    Set<String>? likedIds,
    bool? loading,
    String? error,
    String? username,
    String? selectedSource,
  }) =>
      FeedState(
        sections: sections ?? this.sections,
        likedIds: likedIds ?? this.likedIds,
        loading: loading ?? this.loading,
        error: error,
        username: username ?? this.username,
        selectedSource: selectedSource ?? this.selectedSource,
      );

  @override
  List<Object?> get props => [
        sections,
        likedIds,
        loading,
        error,
        username,
        selectedSource,
      ];
}


