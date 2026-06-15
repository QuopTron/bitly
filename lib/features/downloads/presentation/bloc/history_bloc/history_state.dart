import 'package:equatable/equatable.dart';
import '../../../data/models/download_item_model.dart';

class HistoryState extends Equatable {
  final List<DownloadItemModel> items;
  final bool isLoading;
  final String? error;

  const HistoryState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  HistoryState copyWith({
    List<DownloadItemModel>? items,
    bool? isLoading,
    String? error,
  }) =>
      HistoryState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  @override
  List<Object?> get props => [items, isLoading, error];
}
