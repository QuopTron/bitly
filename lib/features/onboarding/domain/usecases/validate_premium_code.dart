import '../../data/repositories/onboarding_repository.dart';

class ValidatePremiumCode {
  final OnboardingRepository _repository;

  ValidatePremiumCode(this._repository);

  Future<bool> call(String code) {
    return _repository.validatePremiumCode(code);
  }
}
