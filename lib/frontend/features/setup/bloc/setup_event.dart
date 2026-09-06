import 'package:equatable/equatable.dart';

abstract class SetupEvent extends Equatable {
  const SetupEvent();

  @override
  List<Object?> get props => [];
}

class SelectLanguage extends SetupEvent {
  final String locale;

  const SelectLanguage(this.locale);

  @override
  List<Object?> get props => [locale];
}

class NextSlide extends SetupEvent {
  const NextSlide();
}

class PreviousSlide extends SetupEvent {
  const PreviousSlide();
}

class UsernameChanged extends SetupEvent {
  final String username;

  const UsernameChanged(this.username);

  @override
  List<Object?> get props => [username];
}

class GenerateRandomName extends SetupEvent {
  const GenerateRandomName();
}

class SelectMode extends SetupEvent {
  final String mode;

  const SelectMode(this.mode);

  @override
  List<Object?> get props => [mode];
}

class GoogleSignInStatusChanged extends SetupEvent {
  final bool connected;

  const GoogleSignInStatusChanged(this.connected);

  @override
  List<Object?> get props => [connected];
}

class PremiumCodeChanged extends SetupEvent {
  final String code;

  const PremiumCodeChanged(this.code);

  @override
  List<Object?> get props => [code];
}

class ValidatePremiumCode extends SetupEvent {
  const ValidatePremiumCode();
}

class CompleteSetup extends SetupEvent {
  const CompleteSetup();
}

class CheckExistingData extends SetupEvent {
  const CheckExistingData();
}

class AcceptExistingData extends SetupEvent {
  final bool accept;

  const AcceptExistingData(this.accept);

  @override
  List<Object?> get props => [accept];
}

class VerificationCompleted extends SetupEvent {
  final bool success;
  final String? error;
  const VerificationCompleted({this.success = true, this.error});
}

