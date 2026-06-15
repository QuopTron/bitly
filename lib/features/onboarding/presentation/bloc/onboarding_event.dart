import 'package:equatable/equatable.dart';

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

class NextStep extends OnboardingEvent {
  const NextStep();
}

class PreviousStep extends OnboardingEvent {
  const PreviousStep();
}

class GoToStep extends OnboardingEvent {
  final int step;
  const GoToStep(this.step);

  @override
  List<Object?> get props => [step];
}

class CompleteSetup extends OnboardingEvent {
  const CompleteSetup();
}

class ValidatePremiumCode extends OnboardingEvent {
  final String code;
  const ValidatePremiumCode(this.code);

  @override
  List<Object?> get props => [code];
}

class SaveUsername extends OnboardingEvent {
  final String username;
  const SaveUsername(this.username);

  @override
  List<Object?> get props => [username];
}

class SkipTutorial extends OnboardingEvent {
  const SkipTutorial();
}

class StartApp extends OnboardingEvent {
  const StartApp();
}
