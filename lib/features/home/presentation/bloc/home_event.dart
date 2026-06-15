import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadHome extends HomeEvent {
  const LoadHome();
}

class RefreshHome extends HomeEvent {
  const RefreshHome();
}

class NavigateToFeature extends HomeEvent {
  final String feature;
  const NavigateToFeature(this.feature);

  @override
  List<Object?> get props => [feature];
}
