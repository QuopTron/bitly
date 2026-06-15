import 'package:get_it/get_it.dart';
import 'data/repositories/onboarding_repository.dart';
import 'domain/usecases/complete_setup.dart';
import 'domain/usecases/validate_premium_code.dart';
import 'presentation/bloc/onboarding_bloc.dart';

class OnboardingModule {
  static void register() {
    final sl = GetIt.instance;

    sl.registerLazySingleton<OnboardingRepository>(
      () => OnboardingRepository(),
    );

    sl.registerLazySingleton<CompleteSetup>(
      () => CompleteSetup(sl<OnboardingRepository>()),
    );

    sl.registerLazySingleton<ValidatePremiumCode>(
      () => ValidatePremiumCode(sl<OnboardingRepository>()),
    );

    sl.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(sl<OnboardingRepository>()),
    );
  }
}
