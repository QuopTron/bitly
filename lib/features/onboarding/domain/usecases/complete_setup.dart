import '../../data/repositories/onboarding_repository.dart';

class CompleteSetup {
  final OnboardingRepository _repository;

  CompleteSetup(this._repository);

  Future<void> call() {
    return _repository.completeSetup();
  }
}
