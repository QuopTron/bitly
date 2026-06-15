import 'package:equatable/equatable.dart';
import '../../../data/models/queue_item_model.dart';

class QueueState extends Equatable {
  final List<QueueItemModel> items;
  final bool isLoading;
  final String? error;

  const QueueState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  QueueState copyWith({
    List<QueueItemModel>? items,
    bool? isLoading,
    String? error,
  }) =>
      QueueState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  @override
  List<Object?> get props => [items, isLoading, error];
}
