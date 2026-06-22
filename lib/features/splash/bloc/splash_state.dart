import 'package:equatable/equatable.dart';

enum SplashStatus { loading, connected, error }

class SplashState extends Equatable {
  final SplashStatus status;
  final String? error;

  const SplashState({this.status = SplashStatus.loading, this.error});

  SplashState copyWith({SplashStatus? status, String? error}) =>
      SplashState(status: status ?? this.status, error: error);

  @override
  List<Object?> get props => [status, error];
}
