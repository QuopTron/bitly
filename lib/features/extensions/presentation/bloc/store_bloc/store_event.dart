import 'package:equatable/equatable.dart';

abstract class StoreEvent extends Equatable {
  const StoreEvent();

  @override
  List<Object?> get props => [];
}

class LoadStoreExtensions extends StoreEvent {
  final int page;
  final String? category;

  const LoadStoreExtensions({this.page = 0, this.category});

  @override
  List<Object?> get props => [page, category];
}

class SearchStore extends StoreEvent {
  final String query;

  const SearchStore(this.query);

  @override
  List<Object?> get props => [query];
}

class InstallFromStore extends StoreEvent {
  final String storeId;

  const InstallFromStore(this.storeId);

  @override
  List<Object?> get props => [storeId];
}

class LoadCategories extends StoreEvent {}
