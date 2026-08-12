import 'package:equatable/equatable.dart';

abstract class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

class LoadFeed extends FeedEvent {
  const LoadFeed();
}

class DownloadItem extends FeedEvent {
  final String itemId;

  const DownloadItem(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

class FeedSourceChanged extends FeedEvent {
  final String source;

  const FeedSourceChanged(this.source);

  @override
  List<Object?> get props => [source];
}

