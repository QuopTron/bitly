import 'package:equatable/equatable.dart';

abstract class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadHistory extends HistoryEvent {
  const LoadHistory();
}

class ClearHistory extends HistoryEvent {
  const ClearHistory();
}

class RetryDownloadEvent extends HistoryEvent {
  final String downloadId;

  const RetryDownloadEvent(this.downloadId);

  @override
  List<Object?> get props => [downloadId];
}

class DeleteFromHistory extends HistoryEvent {
  final String downloadId;

  const DeleteFromHistory(this.downloadId);

  @override
  List<Object?> get props => [downloadId];
}
