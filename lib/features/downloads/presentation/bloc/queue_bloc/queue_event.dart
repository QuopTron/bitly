import 'package:equatable/equatable.dart';
import '../../../data/models/queue_item_model.dart';

abstract class QueueEvent extends Equatable {
  const QueueEvent();

  @override
  List<Object?> get props => [];
}

class LoadQueue extends QueueEvent {
  const LoadQueue();
}

class AddToQueueEvent extends QueueEvent {
  final QueueItemModel item;

  const AddToQueueEvent(this.item);

  @override
  List<Object?> get props => [item];
}

class RemoveFromQueue extends QueueEvent {
  final String itemId;

  const RemoveFromQueue(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

class ClearQueue extends QueueEvent {
  const ClearQueue();
}

class ReorderQueue extends QueueEvent {
  final int oldIndex;
  final int newIndex;

  const ReorderQueue(this.oldIndex, this.newIndex);

  @override
  List<Object?> get props => [oldIndex, newIndex];
}
